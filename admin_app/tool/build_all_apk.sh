#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/build/app/outputs/flutter-apk"
COMBINED_DIR="$OUTPUT_DIR/all"
STAMP="$(date +%Y%m%d-%H%M%S)"

cd "$ROOT_DIR"

echo "=== [1/2] Mobile (phone) build: arm64, minSdk 24 ==="
"$ROOT_DIR/tool/build_admin_apk.sh"

echo ""
echo "=== [2/2] POS-terminal build: full ABI set, minSdk 23 ==="
"$ROOT_DIR/tool/build_terminal_apk.sh"

mkdir -p "$COMBINED_DIR"
for apk in "$OUTPUT_DIR"/app-release.apk \
           "$OUTPUT_DIR"/app-*-release.apk \
           "$OUTPUT_DIR"/app-terminal-release.apk \
           "$OUTPUT_DIR"/app-terminal-*-release.apk; do
  if [[ -f "$apk" ]]; then
    cp "$apk" "$COMBINED_DIR/"
  fi
done

cat > "$COMBINED_DIR/README.txt" <<EOF
Combined admin + terminal release APKs built $STAMP.

Mobile (phone) — arm64 only, minSdk 24:
  app-release.apk                      fat APK (in-app update)
  app-arm64-v8a-release.apk            arm64 sideload

POS terminal (SUNMI/iMin/PAX) — full ABI set, minSdk 23:
  app-terminal-release.apk             fat APK (in-app update)
  app-terminal-arm64-v8a-release.apk   arm64 sideload
  app-terminal-armeabi-v7a-release.apk 32-bit sideload
  app-terminal-x86_64-release.apk      x86_64 sideload

All APKs are signed with the release keystore (android/key.properties).
EOF

echo ""
echo "=== All APKs (combined) ==="
ls -lh "$COMBINED_DIR"
echo ""
echo "Combined output: $COMBINED_DIR"