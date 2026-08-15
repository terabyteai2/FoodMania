#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/build/app/outputs/flutter-apk"
TERMINAL_APK="$OUTPUT_DIR/app-terminal-release.apk"

cd "$ROOT_DIR"

# Fat APK (in-app update) — keeps the current single-file release.
POS_TERMINAL_BUILD=true \
  flutter build apk --release --android-skip-build-dependency-validation

cp "$OUTPUT_DIR/app-release.apk" "$TERMINAL_APK"

# Per-ABI APKs (sideload / store distribution) alongside the fat release.
POS_TERMINAL_BUILD=true \
  flutter build apk --release --split-per-abi --android-skip-build-dependency-validation

for abi in arm64-v8a armeabi-v7a x86_64; do
  cp "$OUTPUT_DIR/app-$abi-release.apk" "$OUTPUT_DIR/app-terminal-$abi-release.apk"
done

echo "Terminal APK: $TERMINAL_APK"
echo "ABI APKs:"
ls -1 "$OUTPUT_DIR"/app-terminal-*-release.apk