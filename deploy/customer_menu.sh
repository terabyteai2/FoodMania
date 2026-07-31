#!/usr/bin/env bash
# Build and deploy ONLY the customer menu frontend (static SPA at /var/www/rastarant/backend/frontend_dist/).
#
# Usage:  bash deploy/customer_menu.sh

set -euo pipefail

VPS_HOST="${VPS_HOST:-160.187.130.80}"
VPS_USER="${VPS_USER:-root}"
VPS_PORT="${VPS_PORT:-22}"
REMOTE_DIR="/var/www/rastarant/backend/frontend_dist"

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
  [[ -f "${nvm_sh}" ]] || die "Node 18+ is required for Vite builds."
  # shellcheck disable=SC1090
  source "${nvm_sh}"
  nvm use 20.20.0 >/dev/null 2>&1 \
    || nvm use 20 >/dev/null 2>&1 \
    || nvm use --lts >/dev/null 2>&1 \
    || die "Could not switch to Node 18+ with nvm."
  major="$(node -p "Number(process.versions.node.split('.')[0])" 2>/dev/null || echo 0)"
  [[ "${major}" -ge 18 ]] || die "Node 18+ is required for Vite builds; current node is $(node -v)."
}

say "Checking SSH connectivity"
ssh -o BatchMode=yes -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" "true" 2>/dev/null \
  || die "Keyless SSH not configured. Run bash deploy/bootstrap_vps.sh first."

ensure_modern_node

say "Installing customer_menu dependencies"
cd "${REPO_ROOT}/customer_menu/frontend"
if [[ -f package-lock.json ]]; then
  npm ci --silent 2>/dev/null || die "npm ci failed"
else
  npm install --silent 2>/dev/null || die "npm install failed"
fi

say "Building customer_menu"
npm run build || die "Build failed"

say "Syncing build output to ${VPS_USER}@${VPS_HOST}:${REMOTE_DIR}"
ssh -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" "mkdir -p '${REMOTE_DIR}'"
rsync -az --delete \
  -e "ssh -p ${VPS_PORT}" \
  "${REPO_ROOT}/backend/frontend_dist/" \
  "${VPS_USER}@${VPS_HOST}:${REMOTE_DIR}/"

ok "Customer menu build deployed"

say "Reloading nginx"
ssh -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" "nginx -t && systemctl reload nginx"
ok "Done — customer menu updated (wildcard subdomains *.quickbytes.buzz)"
