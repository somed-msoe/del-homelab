# Homelab Project

## 1. Hardware

- **Device**: Lenovo IdeaPad 3 15IML05
- **Specs**: Intel i3, 8GB RAM, 237GB storage
- **Peripherals needed**: 65W/45W charger (20V, 4.0mm x 1.7mm barrel tip),
  USB-A to Gigabit Ethernet adapter, Cat6 ethernet cable
- **Issues fixed**:
  - Trackpad not detected — fixed by manually installing the chipset (I/O)
    driver from Lenovo's site (Windows Update/Lenovo Vantage missed it)
  - Wifi adapter unreliable (worked once, then dead for a year) — bypassed
    entirely by using wired ethernet instead, since this runs headless anyway

## 2. Operating System

- **OS**: Ubuntu Server 24.04 LTS (chose Server over Desktop — no GUI needed,
  lower resource use; chose LTS for 5 years of security support)
- **Hostname**: del-homelab
- **Username**: delsoro
- Installed via bootable USB (balenaEtcher, after Rufus failed to detect
  the drive)
- Enabled OpenSSH during install for remote management
- Disk setup: entire disk, LVM enabled, no LUKS encryption (not needed for
  a homelab box, and encryption adds friction on headless reboots)
- Disabled lid-close suspend (`/etc/systemd/logind.conf` —
  `HandleLidSwitch=ignore` etc.) so it can run closed, out of the way

## 3. Networking

- Connects via wired ethernet (USB adapter), not wifi
- **Local IP**: assigned via DHCP, only reachable on home network
- **Tailscale IP**: 100.x.x.x, works from anywhere once Tailscale is
  installed and logged in on both ends — this is the real "remote access"
- **SSH**:
  - Key-based auth set up (ed25519 keypair) so no password needed per login
  - Public key copied to server's `~/.ssh/authorized_keys`
  - Still keeps password login as fallback
- **Tailscale**: handles the VPN tunnel automatically; no port forwarding,
  no manual router config, encrypted by default
- (Planned: manual WireGuard setup later, as a separate learning exercise)

## 4. Core Platform — Docker

- Installed via Docker's official apt repository (not the Ubuntu default
  package, which lags behind)
- Added my user to the `docker` group so commands don't need `sudo`
- Core idea: containers share the host OS kernel, much lighter than full
  VMs — chose this over Proxmox given only 8GB RAM on this box
- **Restart policy**: all containers use `restart: unless-stopped`, so they
  come back on their own after a reboot. Reboot test passed: rebooted the
  server and every container recovered unattended. The `deploy.yml`
  pipeline sets the policy on the app container too.

## 5. Services

Quick reference (host ports, reachable at `http://<tailscale-ip>:<port>`):

| Service       | Port  | Purpose                          |
|---------------|-------|----------------------------------|
| Gitea         | 3000  | Git server (SSH on 222)          |
| homelab-app   | 3001  | My Node.js dashboard             |
| Uptime Kuma   | 3002  | Service monitoring               |
| Grafana       | 3003  | Metrics dashboards               |
| Homepage      | 80    | Landing page (runs on k3s)       |
| Navidrome     | 4533  | Music (planned, not installed)   |
| Jellyfin      | 8096  | Media server                     |
| Komga         | 25600 | Comics/manga server              |
| Minecraft     | 25565 | Modded game server (Fabric)      |

### Gitea (self-hosted Git server)
- **What it does**: private GitHub — hosts my own repos
- **Why**: foundation for the CI/CD pipeline; don't want to depend on
  GitHub Actions minutes/limits for my own automation
- **Port**: 3000 (web UI), 222 (git SSH, separate from server's own port 22
  to avoid conflicts)
- **Data location**: `~/gitea/data` on the server (bind-mounted volume)
- **Access**: `http://<tailscale-ip>:3000`
- **Git over SSH**: port 222, user `git` (Gitea's fixed SSH user).
  Each machine gets its own key, added under Settings → SSH/GPG Keys
  and revocable individually. On the server, `~/.ssh/config` has a
  `gitea` alias pointing at 127.0.0.1:222 with the dedicated key, so
  remotes look like `gitea:delsoro/homelab-infra.git`. No passwords
  or tokens stored on the server.

### homelab-app (Node.js dashboard)
- **What it does**: small dashboard with a visit counter and a
  "last deployed" timestamp; exists to exercise the CI/CD pipeline
- **Port**: 3001
- **Health check**: `/health` returns `{ status: 'ok' }`
- **Deploy**: pushing to Gitea triggers the workflow in `deploy.yml`,
  which builds and redeploys the container

### Jellyfin (media server)
- **What it does**: streams my movies and shows to browsers and devices
- **Port**: 8096
- **Data location**: `~/jellyfin/config` and `~/jellyfin/cache`
  (bind mounts). TODO: add the media library path.
- **Runs as**: UID 1000, so bind-mount folders must be owned by 1000
  (see problems log)
- **Playback tip**: use external `.srt` subtitles; embedded PGS
  subtitles force a CPU transcode

### Komga (comics/manga server)
- **What it does**: serves my comic/manga library
- **Port**: 25600
- **Clients**: KMReader (works), Tachiyomi Komga extension (needs the
  account email as the username)
- **Data location**: TODO: add the config and library paths

### Minecraft (private multiplayer server)
- **What it does**: modded server for a private group, reached over
  Tailscale at `<tailscale-ip>:25565`
- **Image**: `itzg/minecraft-server`; compose file is
  `docker-compose/minecraft/docker-compose.yml`, runs from `~/minecraft`
- **Mods**: `TYPE` defaults to Fabric. Drop jars in `~/minecraft/data/mods`
  or list Modrinth slugs in `MC_MODRINTH_PROJECTS`. Change loader/version/RAM
  via `~/minecraft/.env` (`MC_TYPE`, `MC_VERSION`, `MC_MEMORY`), then
  `docker compose up -d`. Clients need the same loader and mods
- **Players**: allowlist enforced. `docker exec minecraft rcon-cli whitelist add <name>`,
  `op <name>`, `whitelist list`
- **Backups**: included in the nightly restic run without stopping the
  server (`save-off`, `save-all flush`, backup, `save-on`). Logs excluded
- **Monitoring**: Kuma TCP monitor on `host.docker.internal:25565`;
  the container also has a `mc-health` healthcheck
- **Access**: only over Tailscale, no router port forward

## 6. Monitoring

### Uptime Kuma (service checks)
- **What it does**: checks my services every 60s and keeps a history
  of uptime, so outages show up as gaps with timestamps
- **Port**: 3002 on the host (container uses 3001, which homelab-app
  already occupies)
- **Data**: `~/uptime-kuma/data` (SQLite)
- **Compose file**: `docker-compose/uptime-kuma/docker-compose.yml` in
  `homelab-infra`
- **Monitors**: Gitea, homelab-app (/health), Jellyfin, Komga, Navidrome,
  Grafana, all via `host.docker.internal` (the compose file maps it with
  `extra_hosts`)
- **Nightly blip**: Komga shows down for ~1 min around 22:00 local
  (03:00 UTC). That is the backup stopping the containers, not a fault.
  Set Retries to 2-3 or add a daily maintenance window before enabling
  alerts, or it will notify every night
- **Limit**: runs on the same machine, so it can't alert when the whole
  box goes down. The dead-man's switch below covers that.

### Dead-man's switch (healthchecks.io)
- **What it does**: server pings healthchecks.io every 5 min via cron;
  if pings stop, I get an email
- **Settings**: check name `del-homelab`, period 5 min, grace 10 min
  (so reboots and the nightly backup don't cause false alerts)
- **Setup**: my user's crontab (not root's) runs a `curl` every 5 min
  with `-m 10 --retry 3`
- **Secret**: ping URL stored in `~/.healthcheck-url` (chmod 600),
  never in git
- **Covers**: laptop off, asleep, crashed, network lost, cron stopped
- **Doesn't cover**: which of those it was (check Tailscale last-seen)
  or whether services work (Uptime Kuma does that)
- **Alert test**: 2026-10-30, sent `/fail` by hand at 08:23:47 UTC. The
  "DOWN" email arrived about 10 seconds later. The next cron ping marked
  it up at 08:25:02 UTC (downtime 1m15s) and the "UP" email arrived.
  Email delivery and recovery work. Not yet tested: stopping the cron job
  and waiting out the grace period (5 min period + 10 min grace)
- **Check name**: emails show it as "My First Check" (the default),
  not `del-homelab`; rename it in the dashboard if more checks get added

### Prometheus + Grafana (metrics)
- **What it does**: Prometheus scrapes numbers every 30s and keeps 30
  days of history; Grafana draws them. Kuma answers "is it up?",
  this answers "why, and what's the trend?"
- **Stack** (`docker-compose/monitoring/`, runs from `~/monitoring`):
  Prometheus, node-exporter (host CPU/RAM/disk/network), cAdvisor
  (per-container CPU/RAM), Grafana
- **Port**: Grafana on 3003. Prometheus is not published (9090 is
  taken by another service); Grafana reaches it over the Docker network
- **Login**: user `admin`, password in `~/monitoring/.env` (chmod 600,
  not in git; `.env.example` shows the format)
- **Dashboards**: imported from grafana.com, 1860 (Node Exporter Full)
  and 14282 (cAdvisor). Now provisioned from
  `docker-compose/monitoring/grafana/dashboards/*.json` (read-only in the
  UI, loaded at Grafana start). The Prometheus datasource uid is pinned in
  its provisioning file because the cAdvisor JSON refers to it directly.
  To change a dashboard: edit in the UI, export via the API (`GET
  /api/dashboards/uid/<uid>`, keep `.dashboard`, set `id` to null),
  overwrite the JSON, commit, run the playbook, `docker restart grafana`
- **Data**: Docker named volumes (`prometheus-data`, `grafana-data`),
  not covered by `backup.sh`. Metrics are rebuildable
- **Limit**: same as Kuma, runs on the box it watches

## 7. Backups

### Nightly restic backup
- **What it does**: 03:00 UTC, root's cron runs
  `/usr/local/bin/homelab-backup.sh`. It stops gitea, komga, navidrome,
  uptime-kuma and jellyfin (so SQLite files are consistent), runs
  `restic backup` on their folders, restarts them, then prunes
  (7 daily, 4 weekly, 6 monthly)
- **Script**: `scripts/homelab-backup.sh` in `homelab-infra`; Ansible
  installs it. The cron entry itself is in root's crontab, not managed
  by Ansible
- **Repository**: `/srv/restic-local` (`RESTIC_REPOSITORY` overrides it),
  password file `/root/restic/pass`
- **Covers**: gitea, gitea-runner, komga, navidrome, uptime-kuma,
  jellyfin config (not its cache), minecraft world and mods. Log: `/var/log/homelab-backup.log`
- **Doesn't cover**: Prometheus/Grafana volumes (metrics are rebuildable),
  the media library itself
- **Weak spots**: the repo is on the same disk as the data, so a disk
  failure loses both. The restic password only exists on that disk
- **Check**: `sudo restic -r /srv/restic-local --password-file
  /root/restic/pass snapshots` showed one snapshot per night
- **USB copy**: after the local backup, the script runs `restic copy`
  into `/mnt/usb-backup/restic` (8GB ext4 drive, label `homelab-bak`,
  fstab `nofail`, same password file) and prunes it with the same
  retention. Skipped with a warning if the drive isn't mounted. Repo was
  46M when set up
- **Deploying**: Ansible copies the script to `/usr/local/bin`; the
  server's `~/homelab-infra` checkout must be pulled first or it
  installs the old version
- TODO: copy the restic password somewhere off the server
- **Restore test**: 2026-10-30, `restic restore latest --target /tmp/x`
  from the USB repo restored all 1202 files/dirs (162 MiB, incl.
  minecraft). Run it as root; a plain `ls` on the target is denied

## 8. Kubernetes (k3s)

- **What**: k3s v1.36.5+k3s1 (pinned) running next to Docker. Docker
  services are untouched; this is for learning
- **Install**: `ansible/k3s.yml` (run with `-K`). The kubeconfig is
  world-readable (`/etc/rancher/k3s/k3s.yaml`) and `.bashrc` exports
  `KUBECONFIG`, so `kubectl` works without sudo
- **Ingress**: built-in Traefik on host ports 80/443
- **Manifests**: `k8s/<app>/` in `homelab-infra`, applied with
  `kubectl apply -k`. The server's checkout is the source:
  `cd ~/homelab-infra && git pull && kubectl apply -k k8s/homepage`
- **Footprint**: about 600-800 MB RAM on top of Docker

### Homepage
- **What it does**: one page linking to every service with live up/down
  status and host CPU/RAM/disk. Open `http://del-homelab`
- **Config**: ConfigMap in `k8s/homepage/configmap.yaml`. Config is read
  at pod start, so after changing it: `kubectl apply -k k8s/homepage &&
  kubectl -n homepage rollout restart deploy/homepage`
- **Allowed hosts**: `HOMEPAGE_ALLOWED_HOSTS` lists the pod IP (needed for
  probes), the Tailscale IP, `del-homelab` and the LAN IP. Any other
  address gets a 400
- **Links**: use the Tailscale IP, which pods and my PC can both reach

## 9. Motivation

To understand how the infrastructure actually works, not because
self-hosting is more practical. I want hands-on experience with real
sysadmin/DevOps work for my own growth.

## 10. Problems hit & fixes (running log)
- **Jellyfin crash-looping on first start** — container showed `Restarting (139)`
  and logs said `Access to the path '/config/log' is denied`. Cause: the
  `config`/`cache` bind-mount folders didn't exist yet, so Docker created
  them as root, and the container runs as UID 1000 and couldn't write to
  them. Fix: `sudo chown -R 1000:1000 config cache`, then restart. Lesson:
  for containers running as a non-root user, create bind-mount folders
  yourself first (`mkdir -p config cache`).

- **Jellyfin playback stuttering / CPU at ~370%** — a 4K HEVC movie
  froze after seeking. `docker stats jellyfin` showed the CPU pinned,
  and Playback Info showed it was transcoding even though the browser
  could decode the video itself. The reasons listed were the subtitle
  codec and the audio channel count, not the video. The embedded
  subtitle tracks were PGS (image-based), which browsers can't render,
  so Jellyfin burned them into the video and re-encoded the whole film
  on the CPU (~0.39x real time). Fix: use an external text subtitle
  (.srt) named to match the video (`Movie (Year).en.srt`) so the
  browser draws it as an overlay with no re-encode. Backup option:
  Intel Quick Sync hardware transcoding. Lesson: check Playback Info
  for the transcode *reason* before assuming the video is the problem.

- **Pipeline silently not deploying** — pushed a `deploy.yml` change but
  the container never updated. The Actions run showed 0s with a YAML parse
  error (`mapping values are not allowed in this context`), so Gitea
  rejected the workflow before running any steps. Fix: correct the
  indentation in the `run: |` block (spaces, not tabs). Lesson: a
  0-second failed run means a workflow syntax error, so check the run's
  error message first, not the server.

- **Unexplained outages and containers not coming back** — the server
  went down a few times with no clear cause, and some containers stayed
  stopped afterward. Fix: set `restart: unless-stopped` on every
  container (and in `deploy.yml` for the app), then rebooted to prove
  it. Lesson: test recovery by actually rebooting, not by assuming.

- **Uptime Kuma port collision** — Kuma's default port 3001 is already
  used by homelab-app. Fix: map it to 3002 on the host (`3002:3001`).
  Lesson: check `docker ps` for used ports before picking one.

- **Komga 401 in the Tachiyomi extension** — the connection worked but
  the login was rejected. Cause: Komga usernames are email addresses,
  so the extension needs the exact account email, not a nickname.
  Lesson: a 401 means the server is reachable and the credentials are
  the problem. Test with `curl -u` on the server to separate a bad
  login from an app problem.

- **SSH paste garbling commands** — pasted multi-line commands got
  mangled. Fix: `echo "set enable-bracketed-paste off" >> ~/.inputrc`,
  then open a new SSH session.

- **cAdvisor dashboard empty, no container names** — Prometheus had
  cgroup data but no `name` label, so the dashboard had nothing to show.
  cAdvisor logs said `failed to identify the read-write layer ID`.
  Cause: Docker uses the containerd image store
  (`docker info` shows `io.containerd.snapshotter.v1`), which cAdvisor
  v0.52.1 can't map to containers. Fix: upgrade cAdvisor to v0.55.1.
  Lesson: when a dashboard is blank, query Prometheus directly to see
  which labels actually exist before blaming the dashboard.

- **`host.docker.internal` timed out in my browser** — that name only
  exists inside containers (via `extra_hosts`). From my PC use the
  Tailscale IP; use `host.docker.internal` only in Kuma monitors.

- **Ansible `become` timing out on Ubuntu 26.04** — `Timed out waiting
  for become success or become password prompt`, even with `-K`. Cause:
  this Ubuntu ships `sudo-rs` as `sudo`, which doesn't print the prompt
  Ansible waits for. The classic sudo is still installed as `sudo.ws`.
  Fix: `ansible_become_exe=/usr/bin/sudo.ws` in the inventory. Lesson:
  `sudo --version` is worth checking when automation can't get root.

- **Homepage crash-looping on k3s** — pod restarted, tiles showed ERROR
  and `API Error`. Previous logs (`kubectl logs --previous`) said
  `EROFS: read-only file system, copyfile ... custom.css`. Cause:
  Homepage v2 writes default files into its config dir and a ConfigMap
  mount is read-only. Fix: init container copies the ConfigMap into an
  `emptyDir` mounted at `/app/config`. Lesson: when a pod restarts, read
  the *previous* container's logs, the current ones are just the restart.

- **Komga down every night at 22:00** — Kuma showed a 1-minute outage
  daily. Cause: the 03:00 UTC restic backup stops the containers. I had
  assumed no nightly backup existed because my user's crontab was empty;
  it lives in root's crontab. Lesson: check root's crontab and
  `journalctl` around the time before guessing, and check what already
  exists before building a duplicate.

## 11. Roadmap

- [x] Phase 1: Core infra (Ubuntu, Docker, SSH, Tailscale)
- [x] Phase 2: Gitea
- [x] Phase 3: CI runner
- [x] Phase 4: Auto-deploy on successful build
- [x] Phase 5a: Jellyfin (media server)
- [x] Phase 5b: Navidrome (music server)
- [x] Phase 6a: Monitoring (Uptime Kuma + healthchecks.io)
- [x] Phase 6b: Grafana + Prometheus
- [x] Phase 7: Ansible (Infrastructure as Code) — `site.yml` and
      `k3s.yml` run end to end on the server (2026-10-30); second run
      of `site.yml` gave `changed=0`. Run from `~/homelab-infra/ansible`
      after `git pull`: `ansible-playbook -i inventory.ini site.yml -K`
      (add `--check --diff` for a dry run). A mistyped `BECOME` password
      shows as "Duplicate become password prompt", not a wrong-password
      message
- [ ] Phase 8: k3s (lightweight Kubernetes) — installed, Homepage runs
      on it; next: move something real, learn kubectl
- [ ] Side quest: manual WireGuard setup
- [ ] Backups: nightly restic + USB copy work and restore is tested
      (2026-10-30); still need the restic password stored off the server
