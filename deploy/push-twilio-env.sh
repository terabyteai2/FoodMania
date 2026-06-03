#!/usr/bin/env bash
# Copy TWILIO_* (and optional APP_ENV) from local backend/.env to the VPS.
# Usage (from repo root):
#   1. Add TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_VERIFY_SERVICE_SID to backend/.env
#   2. bash deploy/push-twilio-env.sh
#   3. bash deploy/redeploy.sh   # optional if code already deployed

set -euo pipefail

VPS_HOST="${VPS_HOST:-160.187.130.80}"
VPS_USER="${VPS_USER:-root}"
VPS_PORT="${VPS_PORT:-22}"
REMOTE_ENV="/var/www/rastarant/backend/.env"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOCAL_ENV="${REPO_ROOT}/backend/.env"

die() { printf "\033[1;31m✗ %s\033[0m\n" "$*" >&2; exit 1; }
say() { printf "\033[1;36m▶ %s\033[0m\n" "$*"; }

[[ -f "${LOCAL_ENV}" ]] || die "Missing ${LOCAL_ENV}"

extract() {
  grep -E "^${1}=" "${LOCAL_ENV}" | tail -1 || true
}

SID="$(extract TWILIO_ACCOUNT_SID)"
TOKEN="$(extract TWILIO_AUTH_TOKEN)"
VSID="$(extract TWILIO_VERIFY_SERVICE_SID)"
APP_ENV_LINE="$(extract APP_ENV)"

[[ -n "${SID}" && -n "${TOKEN}" && -n "${VSID}" ]] \
  || die "Add TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, and TWILIO_VERIFY_SERVICE_SID to backend/.env first."

say "Updating Twilio vars on ${VPS_USER}@${VPS_HOST}"
ssh -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" bash -s <<REMOTE
set -euo pipefail
ENV_FILE="${REMOTE_ENV}"
touch "\${ENV_FILE}"
for key in TWILIO_ACCOUNT_SID TWILIO_AUTH_TOKEN TWILIO_VERIFY_SERVICE_SID APP_ENV; do
  sed -i "/^\${key}=/d" "\${ENV_FILE}"
done
cat >> "\${ENV_FILE}" <<EOF
${SID}
${TOKEN}
${VSID}
${APP_ENV_LINE:-APP_ENV=production}
EOF
chmod 600 "\${ENV_FILE}"
systemctl restart rastarant
sleep 6
curl -fsS http://127.0.0.1:8000/health | head -c 400
echo ""
REMOTE

say "Done. Check phoneOtpMode is \"twilio\" in /health above."
