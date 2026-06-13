#!/usr/bin/env bash
# Merge VPS-relevant keys from local backend/.env into /var/www/rastarant/backend/.env
# Does NOT touch DATABASE_URL or SECRET_KEY (VPS keeps its own DB/password from bootstrap).
#
#   bash deploy/push-backend-env.sh

set -euo pipefail

VPS_HOST="${VPS_HOST:-160.187.130.80}"
VPS_USER="${VPS_USER:-root}"
VPS_PORT="${VPS_PORT:-22}"
REMOTE_ENV="/var/www/rastarant/backend/.env"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOCAL_ENV="${REPO_ROOT}/backend/.env"

# Keys copied from laptop .env → VPS (never DATABASE_URL / SECRET_KEY / deploy SSH vars).
SYNC_KEYS=(
  BASE_URL
  GOOGLE_CLIENT_IDS
  UDDOKTAPAY_BASE_URL
  UDDOKTAPAY_API_KEY
  UDDOKTAPAY_SANDBOX
  PLATFORM_ADMIN_EMAIL
  PLATFORM_ADMIN_PASSWORD
  STAFF_DEV_BYPASS_SECRET
  ONECODESOFT_API_KEY
  ONECODESOFT_SENDER_ID
  ONECODESOFT_API_URL
  TWILIO_ACCOUNT_SID
  TWILIO_AUTH_TOKEN
  TWILIO_VERIFY_SERVICE_SID
  APP_ENV
  DEV_OTP_BYPASS_ENABLED
  DEV_OTP_BYPASS_CODE
  DEMO_MANAGER_LOGIN_ENABLED
  DEMO_MANAGER_SERVER_ID
  SENTRY_DSN
  SENTRY_ENVIRONMENT
  GIT_COMMIT_SHA
  OCR_SPACE_API_KEY
  OCR_SPACE_API_URL
  OCR_SPACE_ENGINE
  OCR_SPACE_LANGUAGE
  GROQ_API_KEY
  MENU_SCAN_GROQ_MODEL
  OPENROUTER_API_KEY
  OPENROUTER_API_KEYS
  CHATBOT_OPENROUTER_MODEL
  CHATBOT_DEEPSEEK_MODEL
  XAI_API_KEY
  DEEPSEEK_API_KEY
  OPENAI_API_KEY
  MENU_SCAN_XAI_MODEL
  MENU_SCAN_DEEPSEEK_MODEL
  MENU_SCAN_OPENAI_MODEL
  FACEBOOK_APP_ID
  FACEBOOK_APP_SECRET
  FACEBOOK_WEBHOOK_VERIFY_TOKEN
  META_GRAPH_API_VERSION
  FACEBOOK_LOGIN_SCOPES
  NGROK_AUTHTOKEN
  NGROK_STATIC_DOMAIN
  PORT
)

die() { printf "\033[1;31m✗ %s\033[0m\n" "$*" >&2; exit 1; }
say() { printf "\033[1;36m▶ %s\033[0m\n" "$*"; }
ok()  { printf "\033[1;32m✓ %s\033[0m\n" "$*"; }

[[ -f "${LOCAL_ENV}" ]] || die "Missing ${LOCAL_ENV}"

BLOCK_FILE="$(mktemp)"
: > "${BLOCK_FILE}"
for key in "${SYNC_KEYS[@]}"; do
  line="$(grep -E "^${key}=" "${LOCAL_ENV}" | tail -1 || true)"
  [[ -n "${line}" ]] || continue
  printf '%s\n' "${line}" >> "${BLOCK_FILE}"
done

[[ -s "${BLOCK_FILE}" ]] || die "No syncable keys found in ${LOCAL_ENV}"

say "Merging $(wc -l < "${BLOCK_FILE}") env line(s) onto ${VPS_USER}@${VPS_HOST}"
scp -P "${VPS_PORT}" "${BLOCK_FILE}" "${VPS_USER}@${VPS_HOST}:/tmp/rastarant-env-merge.txt"

ssh -p "${VPS_PORT}" "${VPS_USER}@${VPS_HOST}" bash -s <<'REMOTE'
set -euo pipefail
ENV_FILE="/var/www/rastarant/backend/.env"
touch "${ENV_FILE}"
while IFS= read -r line || [[ -n "${line}" ]]; do
  [[ "${line}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
  key="${line%%=*}"
  sed -i "/^${key}=/d" "${ENV_FILE}"
done < /tmp/rastarant-env-merge.txt
cat /tmp/rastarant-env-merge.txt >> "${ENV_FILE}"
rm -f /tmp/rastarant-env-merge.txt
chmod 600 "${ENV_FILE}"
systemctl restart rastarant
for i in {1..60}; do
  if curl -fsS --max-time 3 http://127.0.0.1:8000/health >/dev/null 2>&1; then
    echo "  ✓ local /health OK"
    exit 0
  fi
  sleep 2
done
echo "  ✗ local /health did not recover after restart" >&2
systemctl --no-pager --full status rastarant >&2 || true
journalctl -u rastarant -n 80 --no-pager >&2 || true
exit 1
REMOTE

rm -f "${BLOCK_FILE}"

say "Health check"
HEALTH_JSON="$(mktemp)"
health_ok=0
for i in {1..60}; do
  if curl -fsS --max-time 5 "https://quickbytes.buzz/health" -o "${HEALTH_JSON}" 2>/dev/null; then
    health_ok=1
    break
  fi
  sleep 2
done
if [[ "${health_ok}" != "1" ]]; then
  rm -f "${HEALTH_JSON}"
  die "Health check failed at https://quickbytes.buzz/health"
fi
python3 - "${HEALTH_JSON}" <<'PY'
import json,sys
path=sys.argv[1]
try:
    d=json.load(open(path)).get('data',{})
except Exception as exc:
    raise SystemExit(f"Health response was not JSON: {exc}")
print('  phoneOtpMode:', d.get('phoneOtpMode'))
print('  onecodesoftConfigured:', d.get('onecodesoftConfigured'))
print('  smsProvider:', d.get('smsProvider'))
print('  demoManagerLoginEnabled:', d.get('demoManagerLoginEnabled'))
PY
rm -f "${HEALTH_JSON}"

ok "Backend env synced and rastarant restarted"
