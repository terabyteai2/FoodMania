#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

HOST_BUILD_DIR="$ROOT_DIR/build/linux_host_debug"
BUNDLE_DIR="$HOST_BUILD_DIR/bundle"
GENERATED_CONFIG="$ROOT_DIR/linux/flutter/ephemeral/generated_config.cmake"
CONFIG_LOG="$HOST_BUILD_DIR/flutter_config.log"

command -v flutter >/dev/null
command -v /usr/bin/cmake >/dev/null
command -v /usr/bin/clang >/dev/null
command -v /usr/bin/clang++ >/dev/null
command -v /usr/bin/ninja >/dev/null
command -v /usr/bin/pkg-config >/dev/null

mkdir -p "$HOST_BUILD_DIR"

# Snap Flutter writes the required ephemeral config before its bundled CMake
# fails against newer host libraries. The host CMake build below is isolated
# from that broken generated build cache.
echo "Refreshing Flutter Linux debug configuration..."
if ! flutter build linux --debug --config-only >"$CONFIG_LOG" 2>&1; then
  if [[ ! -f "$GENERATED_CONFIG" ]]; then
    cat "$CONFIG_LOG" >&2
    exit 1
  fi
  echo "Snap Flutter CMake is incompatible with this host; continuing with system CMake."
fi

/usr/bin/cmake \
  -S "$ROOT_DIR/linux" \
  -B "$HOST_BUILD_DIR" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_INSTALL_PREFIX="$BUNDLE_DIR" \
  -DCMAKE_C_COMPILER=/usr/bin/clang \
  -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
  -DCMAKE_MAKE_PROGRAM=/usr/bin/ninja \
  -DPKG_CONFIG_EXECUTABLE=/usr/bin/pkg-config \
  -DFLUTTER_TARGET_PLATFORM=linux-x64

/usr/bin/cmake --build "$HOST_BUILD_DIR" --target install

echo
echo "Launching: $BUNDLE_DIR/local_pos"
exec "$BUNDLE_DIR/local_pos" "$@"
