# Rastarant VPS deploy

One-command first-time setup, plus a one-command re-deploy for future code changes.

## VPS prerequisites

Supported (the script will auto-detect and install accordingly):

| OS | Status |
|---|---|
| Ubuntu 22.04 / 24.04 LTS | ✅ Recommended |
| Debian 12 | ✅ |
| AlmaLinux 9 / Rocky 9 | ✅ |
| AlmaLinux 8 / Rocky 8 | ✅ |
| CentOS 7 / RHEL 7 | ❌ Refused — EOL OS, Python 3.6 too old. Ask your VPS provider for a reinstall. |

If you're on CentOS 7 (default on some BDIX VPS plans including GotMyHost), the script will detect it and stop with instructions. Send your provider this message to fix it:

> Please reinstall my VPS with **Ubuntu 22.04 LTS** (preferred) or AlmaLinux 9. I'll lose all current data; that's fine.

Then on your laptop, clear the old SSH fingerprint + secrets and re-run:

```bash
ssh-keygen -R 103.191.240.34
rm -f deploy/.deploy-secrets
bash deploy/bootstrap_vps.sh
```

Other requirements:
- SSH root access (port 22 by default — override with `VPS_PORT=...` if different).
- Public IP that you've already pinged.

## First-time deploy

From the **repo root** on your laptop:

```bash
bash deploy/bootstrap_vps.sh
```

What happens:

1. Generates an SSH key at `~/.ssh/id_ed25519` if you don't have one, then `ssh-copy-id`s it to the VPS. This is the **only** time you'll be asked for the root password.
2. Generates a strong Postgres password and `SECRET_KEY`, stores them in `deploy/.deploy-secrets` (gitignored, chmod 600).
3. rsyncs the code to `/var/www/rastarant` on the VPS.
4. On the VPS: installs `python3-venv`, `postgresql`, `nginx`, builds a Python venv, creates the DB + user, writes `.env`, installs the `rastarant` systemd unit, installs an nginx vhost on port 80, and starts everything.
5. Curls `http://103.191.240.34/health` from your laptop to confirm.

If the external `/health` check fails the script will tell you the most likely cause (usually the VPS firewall — see *Troubleshooting* below).

## Re-deploy after code changes

```bash
bash deploy/redeploy.sh
```

This only rsyncs the new code, runs `pip install -r requirements.txt`, and restarts the systemd service. It does **not** touch the `.env`, the DB, nginx, or the systemd unit. Safe to run as often as you like.

## Where things live on the VPS

```
/var/www/rastarant/                       # full repo (minus build artifacts)
/var/www/rastarant/backend/.venv/         # Python venv
/var/www/rastarant/backend/.env           # secrets — chmod 600 root:root
/var/www/rastarant/backend/uploads/       # menu images, hero media, outlet videos
/etc/systemd/system/rastarant.service     # uvicorn under systemd
/etc/nginx/sites-enabled/rastarant        # reverse proxy on :80 -> uvicorn :8000
```

## Useful commands on the VPS (`ssh root@103.191.240.34`)

```bash
systemctl status rastarant            # is the backend up?
journalctl -u rastarant -f            # tail live logs
systemctl restart rastarant           # restart after manual .env edit
nano /var/www/rastarant/backend/.env  # edit env vars
nginx -T                              # dump effective nginx config
psql -U rastarant_user -d rastarant -h 127.0.0.1   # opens psql shell
```

## Override the target VPS

Want to deploy to a different VPS without editing the script? Set env vars:

```bash
VPS_HOST=1.2.3.4 VPS_USER=ubuntu bash deploy/bootstrap_vps.sh
```

## Troubleshooting

- **`Connection refused` from your laptop** — the VPS firewall is blocking port 80. SSH in and run, depending on distro:
  ```bash
  # Ubuntu / Debian
  ufw allow 22/tcp && ufw allow 80/tcp && ufw --force enable

  # AlmaLinux / Rocky / RHEL (uses firewalld)
  firewall-cmd --permanent --add-service=ssh --add-service=http && firewall-cmd --reload
  ```
- **`502 Bad Gateway`** — uvicorn isn't running. Check `systemctl status rastarant` then `journalctl -u rastarant -n 100`.
- **`ssh-copy-id` keeps asking for the password** — your VPS sshd may have `PasswordAuthentication no`. SSH in once via the GotMyHost web console, edit `/etc/ssh/sshd_config`, set `PasswordAuthentication yes` (only temporarily), `systemctl restart ssh`, then re-run the script.
- **Need to start clean** — on the VPS run:
  ```bash
  systemctl stop rastarant && systemctl disable rastarant
  rm -rf /var/www/rastarant /etc/systemd/system/rastarant.service /etc/nginx/sites-enabled/rastarant
  sudo -u postgres psql -c "DROP DATABASE rastarant; DROP ROLE rastarant_user;"
  ```
  Then on your laptop, delete `deploy/.deploy-secrets` and re-run `bootstrap_vps.sh`.

## Security checklist

- [ ] The root password GotMyHost emailed you is in this chat history — rotate it on the VPS: `ssh root@103.191.240.34 'passwd'`.
- [ ] After `bootstrap_vps.sh` succeeds and key auth works, disable SSH password auth: set `PasswordAuthentication no` in `/etc/ssh/sshd_config`, then `systemctl restart ssh`.
- [ ] Set up a firewall: `ufw allow 22/tcp && ufw allow 80/tcp && ufw --force enable`.
- [ ] Plan a TLS cert (Certbot + a domain name pointing at 103.191.240.34) so the admin app can talk over HTTPS instead of HTTP.
- [ ] `deploy/.deploy-secrets` lives on your laptop only — back it up safely. If you lose it, you can read the values out of `/var/www/rastarant/backend/.env` on the VPS.
