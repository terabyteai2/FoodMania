#!/bin/bash
# Build the desktop POS React app into backend/pos_dist/
# Run from the backend directory: bash build_pos.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POS_DIR="$SCRIPT_DIR/../pos_web"

if [ ! -d "$POS_DIR" ]; then
  echo "ERROR: pos_web directory not found at $POS_DIR"
  exit 1
fi

echo "→ Installing POS web dependencies..."
cd "$POS_DIR"
NPM=$(which npm 2>/dev/null || echo "/usr/share/nodejs/corepack/shims/npm")
"$NPM" install --silent

echo "→ Building POS React app..."
"$NPM" run build

echo "✓ POS app built → $SCRIPT_DIR/pos_dist/"
