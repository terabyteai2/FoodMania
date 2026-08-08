#!/bin/bash
# Local server — no ngrok tunnel.
# Run with: bash start.sh

set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

if [ ! -f .env ]; then
  echo "ERROR: .env not found. Copy .env.example to .env and fill in values."
  exit 1
fi

PYTHON_BIN="python3"
if [ -x ".venv/bin/python" ]; then
  PYTHON_BIN=".venv/bin/python"
fi

LAN_IP=""
if command -v hostname >/dev/null 2>&1; then
  LAN_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi
if [ -z "$LAN_IP" ] && command -v ip >/dev/null 2>&1; then
  LAN_IP="$(ip route get 8.8.8.8 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}')"
fi
if [ -z "$LAN_IP" ]; then
  LAN_IP="YOUR_COMPUTER_IP"
fi

PORT="${PORT:-8000}"
LAN_URL="http://$LAN_IP:$PORT"

echo "Starting Rastarant API server (same-WiFi LAN)..."
echo "Local URL:  http://localhost:$PORT"
echo "Phone URL:  $LAN_URL"
echo "Docs:       $LAN_URL/docs"
echo ""
echo "Flutter run command for phone testing:"
echo "  flutter run --dart-define=POS_CLOUD_API_URL=$LAN_URL"
echo ""

NGROK_AUTHTOKEN="" NGROK_STATIC_DOMAIN="" BASE_URL="$LAN_URL" PORT="$PORT" "$PYTHON_BIN" main.py
