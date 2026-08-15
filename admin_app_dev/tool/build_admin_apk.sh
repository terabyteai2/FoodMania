#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/build/app/outputs/flutter-apk"

cd "$ROOT_DIR"

# Fat APK (in-app update) — the single-file admin release.
flutter build apk --release --android-skip-build-dependency-validation

# Per-ABI APKs (sideload / store distribution) alongside the fat release.
flutter build apk --release --split-per-abi --android-skip-build-dependency-validation

echo "Admin release APKs:"
ls -1 "$OUTPUT_DIR"/app*-release.apk