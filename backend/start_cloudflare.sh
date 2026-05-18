#!/bin/bash
# Start Rastarant on Cloudflare Tunnel (quick tunnel — no account needed).
# Run with: bash start_cloudflare.sh

set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

if [ ! -f .env ]; then
  echo "ERROR: .env not found."
  exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║    Rastarant · Full Stack on Cloudflare Tunnel       ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── Step 1: Build customer menu React app ────────────────────────────────────
echo "[1/3] Building customer menu..."
bash build_frontend.sh
echo ""

# ── Step 2: Start Cloudflare quick tunnel and capture the public URL ─────────
echo "[2/3] Starting Cloudflare Tunnel..."
CF_LOG=$(mktemp /tmp/cloudflared-XXXXXX.log)

# Run cloudflared in background, write all output to log file
cloudflared tunnel --url http://localhost:8001 >"$CF_LOG" 2>&1 &
CF_PID=$!

# Poll for the trycloudflare.com URL (up to 25 seconds)
CF_URL=""
for i in $(seq 1 25); do
  CF_URL=$(grep -oP 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' "$CF_LOG" 2>/dev/null | head -1)
  if [ -n "$CF_URL" ]; then break; fi
  sleep 1
done

if [ -z "$CF_URL" ]; then
  echo "ERROR: Cloudflare tunnel did not start in time."
  echo "       Check log: $CF_LOG"
  kill "$CF_PID" 2>/dev/null || true
  exit 1
fi

echo ""
echo "  ✅ Cloudflare Tunnel is live!"
echo ""
echo "  🌐 Public URL:       $CF_URL"
echo "  📋 API docs:         $CF_URL/docs"
echo "  🍽️  Customer menu:   $CF_URL/menu/YOUR_OUTLET_ID"
echo ""
echo "  (Tunnel PID: $CF_PID — keep this terminal open)"
echo ""
rm -f "$CF_LOG"

# Trap to kill cloudflared when this script exits
cleanup() {
  echo ""
  echo "Shutting down Cloudflare tunnel (PID $CF_PID)..."
  kill "$CF_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# ── Step 3: Start FastAPI backend with the Cloudflare URL as BASE_URL ────────
echo "[3/3] Starting FastAPI server..."
echo "      BASE_URL = $CF_URL"
echo "      (ngrok disabled — using Cloudflare instead)"
echo ""

# Pass BASE_URL as env var override; suppress ngrok so it doesn't conflict
NGROK_AUTHTOKEN="" NGROK_STATIC_DOMAIN="" BASE_URL="$CF_URL" \
  python3 -m uvicorn main:app --host 0.0.0.0 --port 8001
