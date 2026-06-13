#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/build/app/outputs/flutter-apk"
TERMINAL_APK="$OUTPUT_DIR/app-terminal-release.apk"

cd "$ROOT_DIR"

POS_TERMINAL_BUILD=true \
  flutter build apk --release --android-skip-build-dependency-validation

cp "$OUTPUT_DIR/app-release.apk" "$TERMINAL_APK"
echo "Terminal APK: $TERMINAL_APK"
