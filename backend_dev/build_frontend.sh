#!/bin/bash
# Build the customer menu React app into backend/frontend_dist/
# Run from the backend directory: bash build_frontend.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$SCRIPT_DIR/../customer_menu/frontend"

if [ ! -d "$FRONTEND_DIR" ]; then
  echo "ERROR: frontend directory not found at $FRONTEND_DIR"
  exit 1
fi

echo "→ Installing frontend dependencies..."
cd "$FRONTEND_DIR"
NPM=$(which npm 2>/dev/null || echo "/usr/share/nodejs/corepack/shims/npm")
"$NPM" install --silent

echo "→ Building React app..."
"$NPM" run build

echo "✓ Frontend built → $SCRIPT_DIR/frontend_dist/"
