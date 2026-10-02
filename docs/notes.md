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

## 5. Services

### Gitea (self-hosted Git server)
- **What it does**: private GitHub — hosts my own repos
- **Why**: foundation for the CI/CD pipeline; don't want to depend on
  GitHub Actions minutes/limits for my own automation
- **Port**: 3000 (web UI), 222 (git SSH, separate from server's own port 22
  to avoid conflicts)
- **Data location**: `~/gitea/data` on the server (bind-mounted volume)
- **Access**: `http://<tailscale-ip>:3000`

## 6. Motivation

To understand how the infrastructure actually works, not because
self-hosting is more practical. I want hands-on experience with real
sysadmin/DevOps work for my own growth.

## 7. Problems hit & fixes (running log)

## 8. Roadmap

- [x] Phase 1: Core infra (Ubuntu, Docker, SSH, Tailscale)
- [x] Phase 2: Gitea
- [x] Phase 3: CI runner (Drone CI or similar)
- [ ] Phase 4: Auto-deploy on successful build
- [ ] Phase 5: Jellyfin (media server)
- [ ] Phase 5b: Navidrome (music server)
- [ ] Phase 6: Monitoring (Grafana + Prometheus / Uptime Kuma)
- [ ] Phase 7: Ansible (Infrastructure as Code)
- [ ] Phase 8: k3s (lightweight Kubernetes)
- [ ] Side quest: manual WireGuard setup