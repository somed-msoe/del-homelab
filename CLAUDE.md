# homelab-infra
Config for a single Ubuntu 26.04 server (`del-homelab`): Docker stacks, k3s,
restic backups, monitoring. See docs/notes.md for the full write-up.

- Edit here, never on the server. Deploy: on the server `git pull`, then
  `cd ansible && ansible-playbook -i inventory.ini site.yml` (add
  `--check --diff` first). `k3s.yml` is separate.
- Compose files are copied by Ansible, so a stack changes only when its file
  changes. Secrets (`.env`, `data/`) are gitignored.
- The backup script runs from `/usr/local/bin`, installed by Ansible.
  Local repo `/srv/restic-local`, USB copy `/mnt/usb-backup/restic`.
- Keep `docs/notes.md` current: tick phases, add problems to the log.
- Shell scripts use LF line endings (`.gitattributes`).
