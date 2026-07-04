#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/build/app/outputs/flutter-apk"

cd "$ROOT_DIR"

flutter build apk --release --split-per-abi --android-skip-build-dependency-validation
echo "Terminal APKs:"
ls -1 "$OUTPUT_DIR"/app-*-release.apk
