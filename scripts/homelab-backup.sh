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

# bring services back before the slower prune and USB copy
cleanup
trap - EXIT

restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune

# off-disk copy; skipped if the USB drive isn't mounted
USB_REPO=/mnt/usb-backup/restic
if mountpoint -q /mnt/usb-backup; then
  restic -r "$USB_REPO" copy \
    --from-repo "$RESTIC_REPOSITORY" --from-password-file "$RESTIC_PASSWORD_FILE"
  restic -r "$USB_REPO" forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
else
  echo "WARNING: /mnt/usb-backup not mounted, skipped USB copy" >&2
fi
