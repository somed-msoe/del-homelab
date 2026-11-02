# del-homelab

Infrastructure as code for a single Ubuntu Server homelab. Docker Compose
stacks, a k3s cluster, Ansible, monitoring and encrypted backups, all kept in
Git and applied with one playbook.

## What it runs

- **Services (Docker Compose):** Gitea with a CI runner, Jellyfin, Navidrome,
  Komga, Minecraft, Uptime Kuma
- **Monitoring:** Prometheus, cAdvisor and node-exporter feeding provisioned
  Grafana dashboards, plus Uptime Kuma checks and a healthchecks.io
  dead-man's switch
- **Kubernetes:** k3s with Traefik ingress, running a Homepage dashboard from
  Kustomize manifests
- **Backups:** nightly restic backups to a local repo and an offsite USB copy,
  with a tested restore
- **Access:** private only, over Tailscale

## Layout

| Path | Contents |
| --- | --- |
| `ansible/` | `site.yml` (base config, stacks, homelab-mcp) and `k3s.yml` |
| `docker-compose/` | One folder per Docker stack |
| `k8s/` | Kustomize manifests for k3s apps |
| `scripts/` | Backup script and login banner |
| `docs/notes.md` | Full write-up: setup, decisions, and a log of problems and fixes |

## Deploying

On the server, pull the repo and run the playbook. Compose files are copied by
Ansible, so a stack is only recreated when its file changes.

```
git pull
cd ansible
ansible-playbook -i inventory.ini site.yml --check --diff   # dry run
ansible-playbook -i inventory.ini site.yml
```

`k3s.yml` is run separately.

## Secrets

Secrets such as `.env` files and runtime `data/` are not in Git. Where a stack
needs one, the repo ships an `.env.example`. Hostnames and IPs in this public
copy are replaced with placeholders such as `<tailscale-ip>`.

## Related

`homelab-mcp`, a separate Python MCP server that lets AI clients inspect the
homelab. This repo deploys it; its source lives in its own repo.
