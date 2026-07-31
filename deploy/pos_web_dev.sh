#!/usr/bin/env bash
# Run pos_web dev server locally with API base URL set.
#
#   Usage:  bash deploy/dev-pos-web.sh [port]
#
# Default port is 5175. Pass a port number as the first argument to override.

set -euo pipefail

PORT="${1:-5175}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}/pos_web"
VITE_API_BASE=https://quickbytes.buzz npx vite --host --port "${PORT}"
