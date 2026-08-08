#!/usr/bin/env bash
# Provision + redeploy the QuickBytes DEV backend on the same VPS as production.
#
#   Usage:  bash deploy/dev-backend.sh
#
# Isolation guarantees (production is NEVER touched by this script):
#   - Code:      /var/www/rastarant_dev/backend/   (separate from /var/www/rastarant)
#   - Service:   rastarant_dev.service             (separate unit, uvicorn on 127.0.0.1:8003)
#   - Database:  rastarant_dev + rastarant_dev_user (separate from rastarant DB)
#   - Route:     https://dev.quickbytes.buzz       (exact-match nginx block; prod
#                 *.quickbytes.buzz wildcard + root domain keep routing to :8000)
#   - Env:       its own .env; APP_ENV=development; OTP bypass + demo login ON;
#                UddoktaPay sandbox; no ngrok/R2/Facebook/LLM keys.
#
# It only: rsyncs dev code, builds the dev venv, creates the dev DB, writes the
# dev .env, installs the dev systemd unit + dev nginx conf, restarts the dev
# service, then asserts production still answers.
#
# Overrides (same convention as the other deploy scripts):
#   VPS_HOST=... VPS_USER=... VPS_PORT=... DEV_SOURCE=backend_dev
#
# Re-sync dev code from the main backend later:
#   rsync -a --delete --exclude='.venv/' --exclude='uploads/' --exclude='In_App_Update_Apk_File/' \
#     --exclude='__pycache__/' --exclude='.pytest_cache/' --exclude='.env' \
#     backend/ backend_dev/

set -euo pipefail

VPS_HOST="${VPS_HOST:-160.187.130.80}"
VPS_USER="${VPS_USER:-root}"
VPS_PORT="${VPS_PORT:-22}"
REMOTE_DIR="/var/www/rastarant_dev"
SERVICE_NAME="rastarant_dev"
DEV_PORT="8003"
DB_NAME="rastarant_dev"
DB_USER="rastarant_dev_user"
DEV_BASE_URL="https://dev.quickbytes.buzz"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEV_SOURCE="${DEV_SOURCE:-backend_dev}"
SECRETS_FILE="${SCRIPT_DIR}/.deploy-dev-secrets"

say()  { printf "\033[1;36m▶ %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m! %s\033[0m\n" "$*"; }
die()  { printf "\033[1;31m✗ %s\033[0m\n" "$*" >&2; exit 1; }
ok()   { printf "\033[1;32m✓ %s\033[0m\n" "$*"; }

[[ -d "${REPO_ROOT}/${DEV_SOURCE}" ]] || die "Dev source '${DEV_SOURCE}/' not found. Create it by copying backend/ (or set DEV_SOURCE)."

# ── Step 1: SSH check ─────────────────────────────────────────────────────────
ssh -o BatchMode=yes -o ConnectTimeout=8 -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" "true" \
  || die "Keyless SSH not configured. Run bash deploy/bootstrap_vps.sh first."

# ── Step 2: Load or generate dev secrets ──────────────────────────────────────
if [[ -f "${SECRETS_FILE}" ]]; then
  ok "Using existing dev secrets in ${SECRETS_FILE}"
  # shellcheck disable=SC1090
  source "${SECRETS_FILE}"
else
  say "Generating dev DB password + SECRET_KEY (saved to ${SECRETS_FILE}, gitignored)"
  DB_PASS="$(openssl rand -base64 30 | tr -dc 'A-Za-z0-9' | head -c 32)"
  SECRET_KEY="$(openssl rand -base64 48 | tr -d '\n')"
  umask 077
  cat >"${SECRETS_FILE}" <<EOF
# Generated $(date -u '+%Y-%m-%dT%H:%M:%SZ') by deploy/dev-backend.sh
# Keep this file secret. It is gitignored.
DB_PASS='${DB_PASS}'
SECRET_KEY='${SECRET_KEY}'
EOF
  chmod 600 "${SECRETS_FILE}"
  ok "Dev secrets written"
fi

# ── Step 3: rsync dev code ────────────────────────────────────────────────────
say "Syncing ${DEV_SOURCE}/ to ${VPS_USER}@${VPS_HOST}:${REMOTE_DIR}/backend"
ssh -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" "mkdir -p ${REMOTE_DIR}"
rsync -az --delete \
  -e "ssh -p ${VPS_PORT}" \
  --exclude='__pycache__/' \
  --exclude='.pytest_cache/' \
  --exclude='.venv/' \
  --exclude='venv/' \
  --exclude='uploads/' \
  --exclude='In_App_Update_Apk_File/' \
  --exclude='teammate_private_files/' \
  --exclude='*.zip' \
  --exclude='.env' \
  "${REPO_ROOT}/${DEV_SOURCE}/" "${VPS_USER}@${VPS_HOST}:${REMOTE_DIR}/backend/"
ok "Dev code synced"

say "Syncing nginx dev vhost template"
ssh -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" "mkdir -p ${REMOTE_DIR}/deploy/nginx"
rsync -az \
  -e "ssh -p ${VPS_PORT}" \
  "${SCRIPT_DIR}/nginx/rastarant-dev.conf" \
  "${VPS_USER}@${VPS_HOST}:${REMOTE_DIR}/deploy/nginx/rastarant-dev.conf"
ok "nginx template synced"

# ── Step 4: Remote bootstrap ──────────────────────────────────────────────────
say "Provisioning dev backend on the VPS (venv, DB, .env, systemd, nginx)"
ssh -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" \
  "REMOTE_DIR='${REMOTE_DIR}' \
   SERVICE_NAME='${SERVICE_NAME}' \
   DEV_PORT='${DEV_PORT}' \
   DB_NAME='${DB_NAME}' \
   DB_USER='${DB_USER}' \
   DB_PASS='${DB_PASS}' \
   SECRET_KEY='${SECRET_KEY}' \
   SUPPORT_CHAT_LLM_API_KEY='${SUPPORT_CHAT_LLM_API_KEY}' \
   DEV_BASE_URL='${DEV_BASE_URL}' \
   bash -s" <<'REMOTE_EOF'
set -euo pipefail

step() { printf "\n\033[1;34m[dev-remote] %s\033[0m\n" "$*"; }
die()  { printf "\n\033[1;31m[dev-remote] ✗ %s\033[0m\n" "$*" >&2; exit 1; }

# ── Python venv + deps ────────────────────────────────────────────────────────
step "Building dev venv"
cd "${REMOTE_DIR}/backend"
if [[ ! -d .venv ]]; then
  python3 -m venv .venv
fi
./.venv/bin/pip install --upgrade pip >/dev/null
./.venv/bin/pip install -r requirements.txt >/dev/null

mkdir -p "${REMOTE_DIR}/backend/uploads/menu_images" \
         "${REMOTE_DIR}/backend/uploads/menu_placeholders" \
         "${REMOTE_DIR}/backend/uploads/hero_media" \
         "${REMOTE_DIR}/backend/uploads/outlet_images" \
         "${REMOTE_DIR}/backend/uploads/outlet_videos"

# ── Postgres role + database (dev only; never touches prod 'rastarant') ───────
step "Creating dev Postgres role + database (${DB_NAME})"
sudo -u postgres psql <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}') THEN
    CREATE ROLE ${DB_USER} LOGIN PASSWORD '${DB_PASS}';
  ELSE
    ALTER ROLE ${DB_USER} WITH PASSWORD '${DB_PASS}';
  END IF;
END
\$\$;

SELECT 'CREATE DATABASE ${DB_NAME} OWNER ${DB_USER}'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname='${DB_NAME}')\\gexec

GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
SQL

# ── Write dev .env ────────────────────────────────────────────────────────────
step "Writing dev .env"
cat > "${REMOTE_DIR}/backend/.env" <<ENV
DATABASE_URL=postgresql+asyncpg://${DB_USER}:${DB_PASS}@127.0.0.1:5432/${DB_NAME}
SECRET_KEY=${SECRET_KEY}
IMAGES_DIR=${REMOTE_DIR}/backend/uploads/menu_images
BASE_URL=${DEV_BASE_URL}
GOOGLE_CLIENT_IDS=17506890816-phe8hk3uo1ia5tjvaqqt06s7inu43v29.apps.googleusercontent.com,17506890816-bnmtl46m2u9mebmc1mnb37tm18sdvsit.apps.googleusercontent.com,17506890816-g9fjpo7dsv9a4nib0ar9rg0sjfcc9d42.apps.googleusercontent.com

UDDOKTAPAY_BASE_URL=https://sandbox.uddoktapay.com
UDDOKTAPAY_API_KEY=
UDDOKTAPAY_SANDBOX=true

PLATFORM_ADMIN_EMAIL=admin@food.com
PLATFORM_ADMIN_PASSWORD=1234

# Dev-only conveniences
APP_ENV=development
DEV_OTP_BYPASS_ENABLED=true
DEV_OTP_BYPASS_CODE=000000
DEMO_MANAGER_LOGIN_ENABLED=true
DEMO_MANAGER_SERVER_ID=DEV-MANAGER
STAFF_DEV_BYPASS_SECRET=dev-staff-bypass-secret

# Disabled on dev VPS
NGROK_AUTHTOKEN=
NGROK_STATIC_DOMAIN=
SENTRY_DSN=

# In-app AI support assistant (DeepSeek; shared key with production)
SUPPORT_CHAT_LLM_API_KEY=${SUPPORT_CHAT_LLM_API_KEY}
ENV
chmod 600 "${REMOTE_DIR}/backend/.env"

# ── systemd unit ──────────────────────────────────────────────────────────────
step "Installing systemd unit /etc/systemd/system/${SERVICE_NAME}.service"
cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<UNIT
[Unit]
Description=Rastarant FastAPI backend (DEV)
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=${REMOTE_DIR}/backend
EnvironmentFile=${REMOTE_DIR}/backend/.env
ExecStart=${REMOTE_DIR}/backend/.venv/bin/uvicorn main:app --host 127.0.0.1 --port ${DEV_PORT} --workers 1
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

# ── nginx dev vhost ───────────────────────────────────────────────────────────
step "Installing nginx dev vhost (dev.quickbytes.buzz -> :${DEV_PORT})"
mkdir -p "${REMOTE_DIR}/deploy/nginx"
if [[ -f "${REMOTE_DIR}/deploy/nginx/rastarant-dev.conf" ]]; then
  install -m 644 "${REMOTE_DIR}/deploy/nginx/rastarant-dev.conf" /etc/nginx/conf.d/rastarant-dev.conf
fi
nginx -t
systemctl reload nginx

# ── Local health check ────────────────────────────────────────────────────────
step "Local health check on the VPS"
for i in {1..60}; do
  if curl -fsS --max-time 3 "http://127.0.0.1:${DEV_PORT}/health" >/dev/null 2>&1; then
    echo "  ✓ dev uvicorn responds on :${DEV_PORT}"
    exit 0
  fi
  sleep 2
done
echo "  ✗ dev /health did not recover" >&2
journalctl -u "${SERVICE_NAME}" -n 100 --no-pager >&2 || true
exit 1
REMOTE_EOF
ok "Dev backend provisioned on the VPS"

# ── Step 5: External health check from your laptop ────────────────────────────
say "Verifying ${DEV_BASE_URL}/health from your laptop"
for i in {1..30}; do
  if curl -fsS --max-time 10 "${DEV_BASE_URL}/health" >/dev/null 2>&1; then
    ok "Dev backend live: ${DEV_BASE_URL}"
    break
  fi
  if [[ "$i" == "30" ]]; then
    die "External check failed at ${DEV_BASE_URL}/health"
  fi
  sleep 2
done

# ── Step 6: Production guard — assert prod is untouched ───────────────────────
say "Production guard checks"
ssh -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" "systemctl is-active rastarant" >/dev/null \
  || die "Production service 'rastarant' is not active!"
ok "Production systemd service still active"
curl -fsS --max-time 10 "https://quickbytes.buzz/health" >/dev/null \
  || die "Production https://quickbytes.buzz/health failed!"
ok "Production API health OK"
curl -fsS --max-time 10 "https://demo.quickbytes.buzz/" >/dev/null \
  || die "Customer-menu subdomain check failed!"
ok "Customer-menu subdomains still serving"

cat <<DONE

═══════════════════════════════════════════════════════════════════
  Dev backend is live at:  ${DEV_BASE_URL}
  Health endpoint:         ${DEV_BASE_URL}/health
  API docs:                ${DEV_BASE_URL}/docs
  Dev DB:                  ${DB_NAME} (role ${DB_USER}) — separate from prod
  Dev service:             ${SERVICE_NAME} on 127.0.0.1:${DEV_PORT}
  Dev secrets:             ${SECRETS_FILE} (gitignored)

  Point the dev Flutter app at ${DEV_BASE_URL} (POS_CLOUD_API_URL).
  To re-deploy dev code:    bash deploy/dev-backend.sh
═══════════════════════════════════════════════════════════════════
DONE
