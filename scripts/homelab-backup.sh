#!/bin/bash
set -euo pipefail

export RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-/srv/restic-local}"
export RESTIC_PASSWORD_FILE=/root/restic/pass

CONTAINERS="gitea komga navidrome uptime-kuma jellyfin"

# minecraft stays up: pause world writes and flush to disk instead of stopping it
mc_running() { [ "$(docker inspect -f '{{.State.Running}}' minecraft 2>/dev/null)" = "true" ]; }

cleanup() {
  docker start $CONTAINERS
  if mc_running; then docker exec minecraft rcon-cli save-on || true; fi
}

# stop services briefly so databases are copied in a consistent state
docker stop $CONTAINERS
trap cleanup EXIT

if mc_running; then
  docker exec minecraft rcon-cli save-off
  docker exec minecraft rcon-cli save-all flush
  sleep 5
fi

restic backup \
  /home/delsoro/gitea \
  /home/delsoro/gitea-runner \
  /home/delsoro/komga \
  /home/delsoro/navidrome \
  /home/delsoro/uptime-kuma \
  /home/delsoro/jellyfin \
  /home/delsoro/minecraft \
  --exclude /home/delsoro/jellyfin/cache \
  --exclude /home/delsoro/minecraft/data/logs \
  --exclude node_modules \
  --tag homelab

restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
