#!/bin/bash
# Start backend + ngrok static domain tunnel (pyngrok).
#
# Prerequisites in backend/.env:
#   NGROK_AUTHTOKEN=...           (https://dashboard.ngrok.com/get-started/your-authtoken)
#   NGROK_STATIC_DOMAIN=hostname  (bare host, e.g. my-site.ngrok-free.app — reserve at Cloud Edge → Domains)
#
# Public URL prints at startup — use the SAME host in Flutter e.g.
#   flutter run --dart-define=POS_NGROK_DOMAIN=my-site.ngrok-free.app
#
# Run: bash start_ngrok.sh

set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

if [ ! -f .env ]; then
  echo "ERROR: .env not found."
  exit 1
fi

PYTHON_BIN="python3"
if [ -x ".venv/bin/python" ]; then
  PYTHON_BIN=".venv/bin/python"
fi

source <(grep -E "^NGROK_AUTHTOKEN=|^NGROK_STATIC_DOMAIN=" .env || true)
if [ -z "$NGROK_AUTHTOKEN" ]; then
  echo "ERROR: NGROK_AUTHTOKEN is empty in .env"
  exit 1
fi
if [ -z "$NGROK_STATIC_DOMAIN" ]; then
  echo "ERROR: NGROK_STATIC_DOMAIN is empty in .env (use your reserved ngrok hostname, no https://)."
  exit 1
fi

export PORT="${PORT:-8000}"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║          Rastarant · Backend + ngrok tunnel          ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "Reserved domain host: ${NGROK_STATIC_DOMAIN}"
echo "Local bind:           http://127.0.0.1:${PORT}  (tunnel forwards HTTPS → here)"
echo ""
echo "[1/2] Building customer menu React app..."
bash build_frontend.sh
echo ""

echo "[2/2] Starting API + tunnel (reload is OFF when ngrok is active)..."
echo "      Flutter: dart-define POS_NGROK_DOMAIN or POS_CLOUD_API_URL must match this hostname."
echo "      Docs after boot: https://${NGROK_STATIC_DOMAIN}/docs"
echo ""

"$PYTHON_BIN" main.py
