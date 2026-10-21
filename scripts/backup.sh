#!/usr/bin/env bash
# Nightly backup of homelab service data to an external drive.
#
# Env overrides:
#   BACKUP_DIR      destination (default /mnt/backup, must be a mount point)
#   KEEP_DAYS       retention in days (default 14)
#   STOP_CONTAINERS 1 = briefly stop containers for a consistent SQLite copy
#                   (default 1; set 0 for a live copy, e.g. when testing)
#   ALLOW_UNMOUNTED 1 = skip the mount-point check (testing only)
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/mnt/backup}"
KEEP_DAYS="${KEEP_DAYS:-14}"
STOP_CONTAINERS="${STOP_CONTAINERS:-1}"
ALLOW_UNMOUNTED="${ALLOW_UNMOUNTED:-0}"

# service name -> data path (container names match directory names)
declare -A SOURCES=(
  [gitea]="$HOME/gitea/data"
  [komga]="$HOME/komga"
  [jellyfin]="$HOME/jellyfin/config"
  [uptime-kuma]="$HOME/uptime-kuma/data"
  [navidrome]="$HOME/navidrome"
)

if [ "$ALLOW_UNMOUNTED" != 1 ] && ! mountpoint -q "$BACKUP_DIR"; then
  echo "refusing to run: $BACKUP_DIR is not a mounted drive" >&2
  exit 1
fi

stamp="$(date +%Y-%m-%d_%H%M%S)"
dest="$BACKUP_DIR/$stamp"
mkdir -p "$dest"

stopped=()
restart() { for c in "${stopped[@]}"; do docker start "$c" >/dev/null || true; done; }
trap restart EXIT

for name in "${!SOURCES[@]}"; do
  src="${SOURCES[$name]}"
  [ -d "$src" ] || { echo "skip $name: $src missing"; continue; }
  if [ "$STOP_CONTAINERS" = 1 ] && docker ps -q -f "name=^${name}$" | grep -q .; then
    docker stop "$name" >/dev/null
    stopped+=("$name")
  fi
  if [ "$name" = gitea ]; then
    # data/ssh (host keys) is root-owned; read it as root via Gitea's own image
    img="$(docker inspect -f '{{.Config.Image}}' gitea)"
    docker run --rm --entrypoint tar -v "$src":/src:ro "$img" -czf - -C /src . > "$dest/$name.tar.gz"
  else
    tar -C "$(dirname "$src")" -czf "$dest/$name.tar.gz" "$(basename "$src")"
  fi
  echo "backed up $name"
done

restart
stopped=()

# also keep the compose files/repos that define the stack
tar -C "$HOME" -czf "$dest/homelab-infra.tar.gz" homelab-infra 2>/dev/null || true

# drop backups older than KEEP_DAYS
find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +"$KEEP_DAYS" -exec rm -rf {} +

du -sh "$dest"
