#!/bin/bash
# Platform admin UI — same-WiFi LAN access from phone.
# Run with: bash start.sh

set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

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

PORT="${PORT:-5174}"
LAN_URL="http://$LAN_IP:$PORT"

echo "Starting Platform Admin (same-WiFi LAN)..."
echo "Laptop URL:  http://localhost:$PORT"
echo "Phone URL:   $LAN_URL"
echo ""
echo "Make sure the backend is running first:"
echo "  cd ../backend && ./start.sh"
echo ""

if [ ! -d node_modules ]; then
  echo "Installing npm dependencies..."
  npm install
fi

npm run dev
