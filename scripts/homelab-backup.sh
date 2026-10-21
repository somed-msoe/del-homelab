#!/bin/bash
set -euo pipefail

export RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-/srv/restic-local}"
export RESTIC_PASSWORD_FILE=/root/restic/pass

CONTAINERS="gitea komga navidrome uptime-kuma jellyfin"

# stop services briefly so databases are copied in a consistent state
docker stop $CONTAINERS
trap 'docker start $CONTAINERS' EXIT

restic backup \
  /home/delsoro/gitea \
  /home/delsoro/gitea-runner \
  /home/delsoro/komga \
  /home/delsoro/navidrome \
  /home/delsoro/uptime-kuma \
  /home/delsoro/jellyfin \
  --exclude /home/delsoro/jellyfin/cache \
  --exclude node_modules \
  --tag homelab

restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
