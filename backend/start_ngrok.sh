#!/bin/bash
# Start everything on ngrok:
#   1. Build the React customer menu
#   2. Launch Python backend (which starts the ngrok tunnel)
#
# Public URL: https://kiwi-equator-banknote.ngrok-free.dev
# Customer menu: https://kiwi-equator-banknote.ngrok-free.dev/menu/YOUR_OUTLET_ID
#
# Run with: bash start_ngrok.sh

set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

if [ ! -f .env ]; then
  echo "ERROR: .env not found."
  exit 1
fi

source <(grep -E "^NGROK_AUTHTOKEN|^NGROK_STATIC_DOMAIN" .env)
if [ -z "$NGROK_AUTHTOKEN" ]; then
  echo "ERROR: NGROK_AUTHTOKEN is not set in .env"
  exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║          Rastarant · Full Stack on ngrok             ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "Domain: https://$NGROK_STATIC_DOMAIN"
echo ""

# Step 1 — build the React customer menu
echo "[1/2] Building customer menu React app..."
bash build_frontend.sh
echo ""

# Step 2 — start Python (opens ngrok tunnel internally)
echo "[2/2] Starting Python API server with ngrok..."
echo "      API docs:       https://$NGROK_STATIC_DOMAIN/docs"
echo "      Customer menu:  https://$NGROK_STATIC_DOMAIN/menu/YOUR_OUTLET_ID"
echo ""

python3 main.py
