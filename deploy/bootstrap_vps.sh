#!/usr/bin/env bash
# One-command first-time deploy for the Rastarant backend to a fresh VPS.
#
#   Usage:  bash deploy/bootstrap_vps.sh
#
# What it does (idempotent — safe to re-run):
#   1. Ensures you have an SSH key locally, copies it to the VPS (one password prompt).
#   2. Generates strong DB password + SECRET_KEY, saved to deploy/.deploy-secrets (gitignored).
#   3. rsyncs the backend code to /var/www/rastarant on the VPS.
#   4. On the VPS: installs python, postgres, nginx; creates DB; writes .env, systemd unit, nginx vhost;
#      starts the service and reloads nginx.
#   5. Curls http://<vps>/health to confirm.

set -euo pipefail

# ── Config (edit these two if your VPS changes) ────────────────────────────────
VPS_HOST="${VPS_HOST:-160.187.130.80}"
VPS_USER="${VPS_USER:-root}"
VPS_PORT="${VPS_PORT:-22}"
REMOTE_DIR="/var/www/rastarant"
SERVICE_NAME="rastarant"

# ── Paths ──────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SECRETS_FILE="${SCRIPT_DIR}/.deploy-secrets"

# ── Pretty output ──────────────────────────────────────────────────────────────
say()  { printf "\033[1;36m▶ %s\033[0m\n"   "$*"; }
warn() { printf "\033[1;33m! %s\033[0m\n"   "$*"; }
die()  { printf "\033[1;31m✗ %s\033[0m\n"   "$*" >&2; exit 1; }
ok()   { printf "\033[1;32m✓ %s\033[0m\n"   "$*"; }

# ── Sanity: required local tools ───────────────────────────────────────────────
for tool in ssh ssh-copy-id ssh-keygen rsync curl openssl; do
  command -v "$tool" >/dev/null 2>&1 || die "Missing local tool: $tool"
done

# ── Step 1: SSH key ────────────────────────────────────────────────────────────
KEY_PATH="${HOME}/.ssh/id_ed25519"
if [[ ! -f "${KEY_PATH}" ]]; then
  say "No SSH key found — generating one at ${KEY_PATH}"
  ssh-keygen -t ed25519 -N "" -C "rastarant-deploy" -f "${KEY_PATH}"
else
  ok "SSH key already exists at ${KEY_PATH}"
fi

say "Copying SSH public key to ${VPS_USER}@${VPS_HOST} (you'll be asked for the VPS password ONCE)"
ssh-copy-id -i "${KEY_PATH}.pub" -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" || \
  warn "ssh-copy-id reported a problem — if the key is already installed, that's fine."

# Verify keyless login works now.
ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -p "${VPS_PORT}" \
    "${VPS_USER}@${VPS_HOST}" "echo keyless-ok" >/dev/null 2>&1 \
  || die "Key-based SSH still failing. Check your VPS sshd_config allows PubkeyAuth, or re-run the script."
ok "Keyless SSH working — won't need the password again."

# ── Step 2: Load or generate secrets ───────────────────────────────────────────
if [[ -f "${SECRETS_FILE}" ]]; then
  ok "Using existing secrets in ${SECRETS_FILE}"
  # shellcheck disable=SC1090
  source "${SECRETS_FILE}"
else
  say "Generating strong DB password + SECRET_KEY (saved to ${SECRETS_FILE}, gitignored)"
  DB_PASS="$(openssl rand -base64 30 | tr -dc 'A-Za-z0-9' | head -c 32)"
  SECRET_KEY="$(openssl rand -base64 48 | tr -d '\n')"
  umask 077
  cat >"${SECRETS_FILE}" <<EOF
# Generated $(date -u '+%Y-%m-%dT%H:%M:%SZ') by deploy/bootstrap_vps.sh
# Keep this file secret. It is gitignored.
DB_PASS='${DB_PASS}'
SECRET_KEY='${SECRET_KEY}'
EOF
  chmod 600 "${SECRETS_FILE}"
  ok "Secrets written"
fi

# ── Step 3: rsync repo to the VPS ──────────────────────────────────────────────
say "Syncing backend code to ${VPS_USER}@${VPS_HOST}:${REMOTE_DIR}"
# Wipe any stale venv from a prior failed run so rsync --delete doesn't choke
# on files held open by an old process, and so the fresh venv is built clean.
ssh -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" \
    "mkdir -p ${REMOTE_DIR} && rm -rf ${REMOTE_DIR}/backend/venv ${REMOTE_DIR}/backend/.venv"

rsync -az --delete \
  -e "ssh -p ${VPS_PORT}" \
  --exclude='.git/' \
  --exclude='.dart_tool/' \
  --exclude='build/' \
  --exclude='node_modules/' \
  --exclude='__pycache__/' \
  --exclude='.venv/' \
  --exclude='venv/' \
  --exclude='deploy/.deploy-secrets' \
  --exclude='Restuarent_POS_Admin_APP/' \
  --exclude='admin_app/' \
  --exclude='customer_menu/frontend/node_modules/' \
  --exclude='customer_menu/frontend/dist/' \
  --exclude='backend/In_App_Update_Apk_File/' \
  --exclude='*.apk' \
  --exclude='*.aab' \
  --exclude='*.keystore' \
  "${REPO_ROOT}/" "${VPS_USER}@${VPS_HOST}:${REMOTE_DIR}/"
ok "Code synced"

# ── Step 4: Remote bootstrap ───────────────────────────────────────────────────
GOOGLE_CLIENT_IDS_VALUE="17506890816-phe8hk3uo1ia5tjvaqqt06s7inu43v29.apps.googleusercontent.com,17506890816-bnmtl46m2u9mebmc1mnb37tm18sdvsit.apps.googleusercontent.com,17506890816-g9fjpo7dsv9a4nib0ar9rg0sjfcc9d42.apps.googleusercontent.com"

say "Running remote bootstrap on the VPS (this takes 2–3 minutes the first time)"
ssh -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" \
    "REMOTE_DIR='${REMOTE_DIR}' \
     SERVICE_NAME='${SERVICE_NAME}' \
     BASE_URL='https://quickbytes.buzz' \
     DB_PASS='${DB_PASS}' \
     SECRET_KEY='${SECRET_KEY}' \
     GOOGLE_CLIENT_IDS='${GOOGLE_CLIENT_IDS_VALUE}' \
     bash -s" <<'REMOTE_EOF'
set -euo pipefail

DEBIAN_FRONTEND=noninteractive

step() { printf "\n\033[1;34m[remote] %s\033[0m\n" "$*"; }
die()  { printf "\n\033[1;31m[remote] ✗ %s\033[0m\n" "$*" >&2; exit 1; }

# ── Detect distro family ──────────────────────────────────────────────────────
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
else
  die "Cannot read /etc/os-release — unsupported OS."
fi

case "${ID:-} ${ID_LIKE:-}" in
  *debian*|*ubuntu*) FAMILY=debian ;;
  *rhel*|*fedora*|*centos*|*almalinux*|*rocky*) FAMILY=rhel ;;
  *) die "Unsupported distro: ID=${ID:-?}  ID_LIKE=${ID_LIKE:-?}. Reinstall the VPS with Ubuntu 22.04 LTS or AlmaLinux 9." ;;
esac
step "Detected ${FAMILY} family (${PRETTY_NAME:-unknown})"

# CentOS/RHEL 7 ships Python 3.6 which is too old for this backend.
if [[ "${FAMILY}" == "rhel" ]] && [[ "${VERSION_ID%%.*}" == "7" ]]; then
  die "${PRETTY_NAME} is end-of-life and only ships Python 3.6 — the backend needs Python 3.10+. Ask GotMyHost to reinstall with Ubuntu 22.04 LTS or AlmaLinux 9."
fi

# ── Install system packages ───────────────────────────────────────────────────
step "Installing system packages"
if [[ "${FAMILY}" == "debian" ]]; then
  apt-get update -y >/dev/null
  apt-get install -y --no-install-recommends \
    python3 python3-venv python3-pip \
    postgresql postgresql-contrib \
    nginx \
    curl ca-certificates gnupg lsb-release \
    build-essential libpq-dev libgl1 \
    >/dev/null
else
  # RHEL family — prefer dnf, fall back to yum.
  PKG=dnf
  command -v dnf >/dev/null 2>&1 || PKG=yum
  ${PKG} install -y epel-release >/dev/null 2>&1 || true
  ${PKG} install -y \
    python3 python3-pip \
    postgresql-server postgresql-contrib \
    nginx \
    curl ca-certificates gnupg2 \
    gcc gcc-c++ make libpq-devel mesa-libGL \
    >/dev/null

  # Initialise the Postgres data directory if it's empty (RHEL doesn't do this on install)
  if [[ ! -d /var/lib/pgsql/data/base ]]; then
    if command -v postgresql-setup >/dev/null 2>&1; then
      postgresql-setup --initdb >/dev/null 2>&1 || postgresql-setup initdb >/dev/null
    fi
  fi

  # On RHEL, default pg_hba.conf uses "ident" auth — switch local TCP to md5 so our app's password works.
  HBA=/var/lib/pgsql/data/pg_hba.conf
  if [[ -f "${HBA}" ]]; then
    sed -i -E 's|^(host\s+all\s+all\s+127\.0\.0\.1/32\s+).*|\1md5|' "${HBA}"
    sed -i -E 's|^(host\s+all\s+all\s+::1/128\s+).*|\1md5|' "${HBA}"
  fi
fi

systemctl enable --now postgresql >/dev/null
systemctl enable --now nginx >/dev/null

# ── Postgres role + database ──────────────────────────────────────────────────
step "Configuring Postgres role + database"
sudo -u postgres psql <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='rastarant_user') THEN
    CREATE ROLE rastarant_user LOGIN PASSWORD '${DB_PASS}';
  ELSE
    ALTER ROLE rastarant_user WITH PASSWORD '${DB_PASS}';
  END IF;
END
\$\$;

SELECT 'CREATE DATABASE rastarant OWNER rastarant_user'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname='rastarant')\\gexec

GRANT ALL PRIVILEGES ON DATABASE rastarant TO rastarant_user;
SQL

# On RHEL we just rewrote pg_hba.conf — reload Postgres to pick it up.
if [[ "${FAMILY}" == "rhel" ]]; then
  systemctl reload postgresql >/dev/null || systemctl restart postgresql >/dev/null
fi

# ── Python venv + deps ────────────────────────────────────────────────────────
step "Installing Python dependencies into venv"
cd "${REMOTE_DIR}/backend"
if [[ ! -d .venv ]]; then
  python3 -m venv .venv
fi
./.venv/bin/pip install --upgrade pip >/dev/null
./.venv/bin/pip install -r requirements.txt >/dev/null

# Ensure uploads dirs exist
mkdir -p "${REMOTE_DIR}/backend/uploads/menu_images" \
         "${REMOTE_DIR}/backend/uploads/menu_placeholders" \
         "${REMOTE_DIR}/backend/uploads/hero_media" \
         "${REMOTE_DIR}/backend/uploads/outlet_images" \
         "${REMOTE_DIR}/backend/uploads/outlet_videos"

# ── Write .env (idempotent — overwrites with current values) ──────────────────
step "Writing /backend/.env"
cat > "${REMOTE_DIR}/backend/.env" <<ENV
DATABASE_URL=postgresql+asyncpg://rastarant_user:${DB_PASS}@127.0.0.1:5432/rastarant
SECRET_KEY=${SECRET_KEY}
IMAGES_DIR=${REMOTE_DIR}/backend/uploads/menu_images
BASE_URL=${BASE_URL}
GOOGLE_CLIENT_IDS=${GOOGLE_CLIENT_IDS}

# ngrok is not used in VPS deploy — leave empty.
NGROK_AUTHTOKEN=
NGROK_STATIC_DOMAIN=
ENV
chmod 600 "${REMOTE_DIR}/backend/.env"

# ── systemd unit ──────────────────────────────────────────────────────────────
step "Installing systemd unit /etc/systemd/system/${SERVICE_NAME}.service"
cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<UNIT
[Unit]
Description=Rastarant FastAPI backend
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=${REMOTE_DIR}/backend
EnvironmentFile=${REMOTE_DIR}/backend/.env
ExecStart=${REMOTE_DIR}/backend/.venv/bin/uvicorn main:app --host 127.0.0.1 --port 8000 --workers 2
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}" >/dev/null
systemctl restart "${SERVICE_NAME}"

# ── nginx vhost ───────────────────────────────────────────────────────────────
step "Installing nginx vhost"
# Debian: sites-available + sites-enabled. RHEL: conf.d/. We pick the right path.
if [[ -d /etc/nginx/sites-available ]]; then
  NGX_PATH="/etc/nginx/sites-available/${SERVICE_NAME}"
  NGX_ENABLED="/etc/nginx/sites-enabled/${SERVICE_NAME}"
else
  NGX_PATH="/etc/nginx/conf.d/${SERVICE_NAME}.conf"
  NGX_ENABLED=""
fi

cat > "${NGX_PATH}" <<'NGX'
server {
    listen 80 default_server;
    server_name _;

    # Allow hero video uploads up to 50 MB.
    client_max_body_size 50M;
    proxy_read_timeout 180s;
    proxy_send_timeout 180s;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
NGX

if [[ -n "${NGX_ENABLED}" ]]; then
  ln -sf "${NGX_PATH}" "${NGX_ENABLED}"
  rm -f /etc/nginx/sites-enabled/default
fi

# RHEL ships a default server block in /etc/nginx/nginx.conf that also listens on :80 default_server,
# which would clash with ours. Disable the embedded one if it's there.
if [[ "${FAMILY}" == "rhel" ]] && grep -qE '^\s*server\s*\{' /etc/nginx/nginx.conf 2>/dev/null; then
  sed -i -E 's|(^\s*server\s*\{)|#\1|' /etc/nginx/nginx.conf
fi

# If SELinux is enforcing, allow nginx to make outbound connections (to uvicorn on :8000).
if command -v getenforce >/dev/null 2>&1 && [[ "$(getenforce)" == "Enforcing" ]]; then
  setsebool -P httpd_can_network_connect 1 >/dev/null 2>&1 || true
fi

nginx -t
systemctl reload nginx

# ── Health check (local) ──────────────────────────────────────────────────────
step "Local health check on the VPS"
sleep 2
if curl -fsS http://127.0.0.1:8000/health >/dev/null; then
  echo "  ✓ uvicorn responds on :8000"
else
  echo "  ✗ uvicorn /health failed — see: journalctl -u ${SERVICE_NAME} --no-pager | tail -50"
  exit 1
fi
if curl -fsS http://127.0.0.1/health >/dev/null; then
  echo "  ✓ nginx -> uvicorn pipeline OK"
else
  echo "  ✗ nginx /health failed — see: nginx -T  and  systemctl status nginx"
  exit 1
fi
REMOTE_EOF

# ── Step 5: External health check from your laptop ─────────────────────────────
say "Verifying http://${VPS_HOST}/health from your laptop"
if curl -fsS --max-time 10 "http://${VPS_HOST}/health" >/dev/null; then
  ok "Deployment succeeded — http://${VPS_HOST}/health responds."
else
  warn "Local checks on the VPS passed but external call failed."
  warn "Most likely: VPS firewall blocks port 80. On the VPS, run:"
  warn "    ufw allow 80/tcp && ufw allow 22/tcp && ufw --force enable"
fi

cat <<DONE

═══════════════════════════════════════════════════════════════════
  Rastarant backend is live at:  http://${VPS_HOST}
  Health endpoint:                http://${VPS_HOST}/health
  API docs:                       http://${VPS_HOST}/docs
  Customer menu:                  http://${VPS_HOST}/menu/<outlet_id>

  Secrets saved (gitignored):     deploy/.deploy-secrets

  Useful remote commands (ssh ${VPS_USER}@${VPS_HOST}):
    systemctl status ${SERVICE_NAME}          # is the service up?
    journalctl -u ${SERVICE_NAME} -f          # tail logs
    systemctl restart ${SERVICE_NAME}         # restart after manual .env edit
    nano ${REMOTE_DIR}/backend/.env           # edit env vars

  To push future code changes from this laptop, run:
    bash deploy/redeploy.sh
═══════════════════════════════════════════════════════════════════
DONE
