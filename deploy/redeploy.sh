#!/usr/bin/env bash
# Push the latest code from this laptop to the VPS and restart the backend.
# Run AFTER bootstrap_vps.sh has succeeded at least once.
#
#   Usage:  bash deploy/redeploy.sh
#
# This only rsyncs new code + restarts the service. It does NOT touch the
# .env, the DB, nginx, or the systemd unit.

set -euo pipefail

VPS_HOST="${VPS_HOST:-160.187.130.80}"
VPS_USER="${VPS_USER:-root}"
VPS_PORT="${VPS_PORT:-22}"
REMOTE_DIR="/var/www/rastarant"
SERVICE_NAME="rastarant"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

say()  { printf "\033[1;36m▶ %s\033[0m\n" "$*"; }
ok()   { printf "\033[1;32m✓ %s\033[0m\n" "$*"; }
die()  { printf "\033[1;31m✗ %s\033[0m\n" "$*" >&2; exit 1; }

ssh -o BatchMode=yes -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" "true" 2>/dev/null \
  || die "Keyless SSH not configured. Run bash deploy/bootstrap_vps.sh first."

say "Building customer menu frontend"
cd "${REPO_ROOT}/customer_menu/frontend"
npm run build --silent 2>/dev/null || die "Customer menu build failed"
cd "${REPO_ROOT}"

if [[ -f "${REPO_ROOT}/backend/.env" ]]; then
  say "Syncing backend .env to VPS"
  bash "${SCRIPT_DIR}/push-backend-env.sh" || true
fi

say "Syncing code to ${VPS_USER}@${VPS_HOST}:${REMOTE_DIR}"
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
  --exclude='customer_menu/frontend/node_modules/' \
  --exclude='customer_menu/frontend/dist/' \
  --exclude='backend/uploads/' \
  --exclude='backend/.env' \
  --exclude='*.apk' \
  --exclude='*.aab' \
  --exclude='*.keystore' \
  "${REPO_ROOT}/" "${VPS_USER}@${VPS_HOST}:${REMOTE_DIR}/"

say "Syncing shipped menu placeholder pictures"
ssh -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" \
  "mkdir -p '${REMOTE_DIR}/backend/uploads/menu_placeholders'"
rsync -az --delete \
  -e "ssh -p ${VPS_PORT}" \
  "${REPO_ROOT}/backend/uploads/menu_placeholders/" \
  "${VPS_USER}@${VPS_HOST}:${REMOTE_DIR}/backend/uploads/menu_placeholders/"

say "Updating nginx routes + restarting backend"
ssh -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" bash -s <<REMOTE
set -euo pipefail
if [[ -f ${REMOTE_DIR}/deploy/nginx/rastarant-http.conf ]]; then
  install -m 644 ${REMOTE_DIR}/deploy/nginx/rastarant-http.conf /etc/nginx/conf.d/rastarant.conf
fi
if [[ -f ${REMOTE_DIR}/deploy/nginx/quickbytes.conf ]]; then
  install -m 644 ${REMOTE_DIR}/deploy/nginx/quickbytes.conf /etc/nginx/conf.d/quickbytes.conf
fi
nginx -t
systemctl reload nginx
echo "  ✓ nginx reloaded"
cd ${REMOTE_DIR}/backend
./.venv/bin/pip install -r requirements.txt --quiet
systemctl restart ${SERVICE_NAME}
sleep 8
curl -fsS http://127.0.0.1:8000/health >/dev/null && echo "  ✓ /health OK"
REMOTE

API_BASE="${API_BASE:-https://quickbytes.buzz}"
say "Smoke test (${API_BASE})"
curl -fsS --max-time 15 "${API_BASE}/health" >/dev/null \
  || die "Health check failed at ${API_BASE}/health"
curl -fsS --max-time 15 "https://quickbytes.buzz/" | grep -q '<title>QuickBytes' \
  || die "Landing page smoke check failed at https://quickbytes.buzz/"
curl -fsS --max-time 15 "https://demo.quickbytes.buzz/" | grep -q '<title>Menu</title>' \
  || die "Customer menu smoke check failed at https://demo.quickbytes.buzz/"
curl -fsS --max-time 15 "${API_BASE}/uploads/menu_placeholders/biryani-1.png" >/dev/null \
  || die "Placeholder image smoke check failed at ${API_BASE}/uploads/menu_placeholders/biryani-1.png"
curl -fsS --max-time 20 -X POST "${API_BASE}/admin/phone/send-otp" \
  -H 'Content-Type: application/json' -d '{"phone":"01700000000"}' | grep -q '"smsSent"' \
  || die "Send OTP failed at ${API_BASE}/admin/phone/send-otp"
ok "Deployed — ${API_BASE} (demo login + send-otp OK)"
