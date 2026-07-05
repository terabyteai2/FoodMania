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

ensure_modern_node() {
  local major=0
  if command -v node >/dev/null 2>&1; then
    major="$(node -p "Number(process.versions.node.split('.')[0])" 2>/dev/null || echo 0)"
  fi
  if [[ "${major}" -ge 18 ]]; then
    return
  fi

  local nvm_sh="${NVM_DIR:-$HOME/.nvm}/nvm.sh"
  [[ -f "${nvm_sh}" ]] || die "Node 18+ is required for Vite builds. Install Node 20 or nvm."
  # shellcheck disable=SC1090
  source "${nvm_sh}"
  nvm use 20.20.0 >/dev/null 2>&1 \
    || nvm use 20 >/dev/null 2>&1 \
    || nvm use --lts >/dev/null 2>&1 \
    || die "Could not switch to Node 18+ with nvm."

  major="$(node -p "Number(process.versions.node.split('.')[0])" 2>/dev/null || echo 0)"
  [[ "${major}" -ge 18 ]] || die "Node 18+ is required for Vite builds; current node is $(node -v)."
}

ensure_modern_node

ssh -o BatchMode=yes -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" "true" 2>/dev/null \
  || die "Keyless SSH not configured. Run bash deploy/bootstrap_vps.sh first."

say "Installing customer menu dependencies"
cd "${REPO_ROOT}/customer_menu/frontend"
if [[ -f package-lock.json ]]; then
  npm ci --silent 2>/dev/null || die "Customer menu npm ci failed"
else
  npm install --silent 2>/dev/null || die "Customer menu npm install failed"
fi

say "Building customer menu frontend"
VITE_MAPBOX_TOKEN="${VITE_MAPBOX_TOKEN:-}" npm run build --silent 2>/dev/null || die "Customer menu build failed"
cd "${REPO_ROOT}"

say "Installing platform admin dependencies"
cd "${REPO_ROOT}/platform_admin"
if [[ -f package-lock.json ]]; then
  npm ci --silent 2>/dev/null || die "Platform admin npm ci failed"
else
  npm install --silent 2>/dev/null || die "Platform admin npm install failed"
fi

say "Building platform admin"
VITE_BASE_PATH=/admin/ npm run build --silent 2>/dev/null || die "Platform admin build failed"
cd "${REPO_ROOT}"

if [[ -d "${REPO_ROOT}/pos_web" ]]; then
  say "Installing POS web dependencies"
  cd "${REPO_ROOT}/pos_web"
  if [[ -f package-lock.json ]]; then
    npm ci --silent 2>/dev/null || die "POS web npm ci failed"
  else
    npm install --silent 2>/dev/null || die "POS web npm install failed"
  fi

  say "Building POS web app"
  npm run build --silent 2>/dev/null || die "POS web build failed"
  cd "${REPO_ROOT}"
fi

if [[ -f "${REPO_ROOT}/backend/.env" ]]; then
  say "Syncing backend .env to VPS"
  bash "${SCRIPT_DIR}/push-backend-env.sh" || true
fi

PLACEHOLDER_SOURCE="${REPO_ROOT}/backend/uploads/menu_placeholders"
if [[ ! -d "${PLACEHOLDER_SOURCE}" ]]; then
  PLACEHOLDER_SOURCE="${REPO_ROOT}/admin_app/assets/menu_placeholders"
fi
[[ -d "${PLACEHOLDER_SOURCE}" ]] || die "Missing menu placeholder source directory"

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
  --exclude='landing/' \
  --exclude='Restuarent_POS_Admin_APP/' \
  --exclude='admin_app/' \
  --exclude='platform_admin/' \
  --exclude='customer_menu/frontend/node_modules/' \
  --exclude='customer_menu/frontend/dist/' \
  --exclude='backend/uploads/' \
  --exclude='backend/In_App_Update_Apk_File/' \
  --exclude='backend/.env' \
  --exclude='*.apk' \
  --exclude='*.aab' \
  --exclude='*.keystore' \
  "${REPO_ROOT}/" "${VPS_USER}@${VPS_HOST}:${REMOTE_DIR}/"

say "Syncing platform admin build"
ssh -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" \
  "mkdir -p '${REMOTE_DIR}/platform_admin'"
rsync -az --delete \
  -e "ssh -p ${VPS_PORT}" \
  "${REPO_ROOT}/platform_admin/dist/" \
  "${VPS_USER}@${VPS_HOST}:${REMOTE_DIR}/platform_admin/"

say "Syncing QuickBytes landing page"
ssh -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" \
  "mkdir -p '${REMOTE_DIR}/landing/dist'"
rsync -az --delete \
  -e "ssh -p ${VPS_PORT}" \
  "${REPO_ROOT}/QuickBytes_Landing_Page/" \
  "${VPS_USER}@${VPS_HOST}:${REMOTE_DIR}/landing/dist/"

say "Syncing shipped menu placeholder pictures"
ssh -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" \
  "mkdir -p '${REMOTE_DIR}/backend/uploads/menu_placeholders'"
rsync -az --delete \
  -e "ssh -p ${VPS_PORT}" \
  "${PLACEHOLDER_SOURCE}/" \
  "${VPS_USER}@${VPS_HOST}:${REMOTE_DIR}/backend/uploads/menu_placeholders/"

say "Updating nginx routes + restarting backend"
ssh -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" bash -s <<REMOTE
set -euo pipefail
mkdir -p ${REMOTE_DIR}/backend/uploads/software_downloads
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
for i in {1..60}; do
  if curl -fsS --max-time 3 http://127.0.0.1:8000/health >/dev/null 2>&1; then
    echo "  ✓ /health OK"
    systemctl is-active --quiet ${SERVICE_NAME} && echo "  ✓ ${SERVICE_NAME} active"
    exit 0
  fi
  sleep 2
done
echo "  ✗ /health did not recover after restart" >&2
systemctl --no-pager --full status ${SERVICE_NAME} >&2 || true
journalctl -u ${SERVICE_NAME} -n 100 --no-pager >&2 || true
exit 1
REMOTE

API_BASE="${API_BASE:-https://quickbytes.buzz}"
say "Smoke test (${API_BASE})"
check_url_contains() {
  local url="$1"
  local needle="$2"
  local label="$3"
  local body
  body="$(mktemp)"
  if ! curl -fsS --max-time 15 "${url}" -o "${body}"; then
    rm -f "${body}"
    die "${label} smoke check failed at ${url}"
  fi
  if ! grep -Fq "${needle}" "${body}"; then
    rm -f "${body}"
    die "${label} smoke check failed at ${url}"
  fi
  rm -f "${body}"
}

for i in {1..45}; do
  if curl -fsS --max-time 8 "${API_BASE}/health" >/dev/null 2>&1; then
    ok "Health check OK"
    break
  fi
  if [[ "$i" == "45" ]]; then
    die "Health check failed at ${API_BASE}/health"
  fi
  sleep 2
done
check_url_contains "https://quickbytes.buzz/" "<title>QuickBytes POS</title>" "POS dashboard"
check_url_contains "https://quickbytes.buzz/landing/" "<title>QuickBytes" "Landing page"
check_url_contains "https://quickbytes.buzz/admin/" "<title>Rastarant Platform Admin</title>" "Platform admin"
check_url_contains "https://demo.quickbytes.buzz/" "<title>Menu</title>" "Customer menu"
placeholder_headers="$(mktemp)"
curl -fsSI --max-time 15 -D "${placeholder_headers}" -o /dev/null \
  "${API_BASE}/uploads/menu_placeholders/biryani-1.png" \
  || die "Placeholder image smoke check failed at ${API_BASE}/uploads/menu_placeholders/biryani-1.png"
grep -qi '^content-type: image/' "${placeholder_headers}" \
  || die "Placeholder image returned an unexpected content type"
upload_status="$(curl -sS --max-time 15 -o /dev/null -w '%{http_code}' \
  -X POST "${API_BASE}/platform/app-update/upload")"
[[ "${upload_status}" == "401" || "${upload_status}" == "403" ]] \
  || die "APK upload route smoke check failed at ${API_BASE}/platform/app-update/upload (HTTP ${upload_status})"
download_headers="$(mktemp)"
download_body="$(mktemp)"
trap 'rm -f "${placeholder_headers}" "${download_headers}" "${download_body}"' EXIT
download_status="$(curl -sS --max-time 15 -D "${download_headers}" -o "${download_body}" \
  -H 'Range: bytes=0-0' \
  -w '%{http_code}' "${API_BASE}/app-download/app-release.apk")"
if [[ "${download_status}" == "404" ]]; then
  grep -qi '^content-type: application/json' "${download_headers}" \
    || die "APK download route returned HTTP 404 with an unexpected content type"
elif [[ "${download_status}" == "200" || "${download_status}" == "206" ]]; then
  grep -qi '^content-type: application/vnd.android.package-archive' "${download_headers}" \
    || die "APK download route returned HTTP ${download_status} without the APK content type"
else
  die "APK download route smoke check failed at ${API_BASE}/app-download/app-release.apk (HTTP ${download_status})"
fi
ok "Deployed — ${API_BASE}"
