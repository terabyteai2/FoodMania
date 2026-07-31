#!/usr/bin/env bash
# Deploy JUST the backend directory to the VPS and restart the service.
#
#   Usage:  bash deploy/deploy-backend-only.sh
#
# This script:
#   - Syncs the backend directory to VPS
#   - Installs Python dependencies
#   - Restarts the backend service

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

# Check SSH connectivity
ssh -o BatchMode=yes -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" "true" 2>/dev/null \
  || die "Keyless SSH not configured. Run bash deploy/bootstrap_vps.sh first."

say "Syncing backend directory to ${VPS_USER}@${VPS_HOST}:${REMOTE_DIR}/backend"
rsync -az --delete \
  -e "ssh -p ${VPS_PORT}" \
  --exclude='__pycache__/' \
  --exclude='.venv/' \
  --exclude='venv/' \
  --exclude='.pytest_cache/' \
  --exclude='uploads/' \
  --exclude='In_App_Update_Apk_File/' \
  --exclude='.env' \
  "${REPO_ROOT}/backend/" "${VPS_USER}@${VPS_HOST}:${REMOTE_DIR}/backend/"

ok "Backend code synced"

say "Installing dependencies and restarting backend"
ssh -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" bash -s <<REMOTE
set -euo pipefail
cd ${REMOTE_DIR}/backend
./.venv/bin/pip install -r requirements.txt --quiet
systemctl restart ${SERVICE_NAME}
REMOTE

ok "✓ Backend deployed and restarted successfully"
