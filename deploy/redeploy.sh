#!/usr/bin/env bash
# Push the latest code from this laptop to the VPS and restart the backend.
# Run AFTER bootstrap_vps.sh has succeeded at least once.
#
#   Usage:  bash deploy/redeploy.sh
#
# This only rsyncs new code + restarts the service. It does NOT touch the
# .env, the DB, nginx, or the systemd unit.

set -euo pipefail

VPS_HOST="${VPS_HOST:-103.191.240.34}"
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

say "Reinstalling Python deps (in case requirements.txt changed) + restarting service"
ssh -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" bash -s <<REMOTE
set -euo pipefail
cd ${REMOTE_DIR}/backend
./.venv/bin/pip install -r requirements.txt --quiet
systemctl restart ${SERVICE_NAME}
sleep 2
curl -fsS http://127.0.0.1:8000/health >/dev/null && echo "  ✓ /health OK"
REMOTE

say "External check"
if curl -fsS --max-time 10 "http://${VPS_HOST}/health" >/dev/null; then
  ok "Deployed — http://${VPS_HOST} is live with the new code."
else
  die "External /health failed. Run: ssh ${VPS_USER}@${VPS_HOST} 'journalctl -u ${SERVICE_NAME} --no-pager | tail -50'"
fi
