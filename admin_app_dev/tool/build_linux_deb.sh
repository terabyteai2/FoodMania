#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PACKAGE_NAME="terafoods-pos"
APP_NAME="Terafoods POS"
VERSION="$(sed -n "s/^version: \([^+]*\).*/\1/p" pubspec.yaml)"
ARCH="$(dpkg --print-architecture)"
BUNDLE_DIR="$ROOT_DIR/build/linux_host_release/bundle"
HOST_BUILD_DIR="$ROOT_DIR/build/linux_host_release"
PACKAGE_ROOT="$ROOT_DIR/build/packaging/linux_deb"
DIST_DIR="$ROOT_DIR/dist"
OUTPUT="$DIST_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"

if [[ "${1:-}" != "--skip-build" ]]; then
  command -v cmake >/dev/null
  command -v clang >/dev/null
  command -v clang++ >/dev/null
  command -v ninja >/dev/null
  command -v pkg-config >/dev/null
  flutter pub get
  flutter build linux --release --config-only
  rm -rf "$HOST_BUILD_DIR"
  /usr/bin/cmake \
    -S "$ROOT_DIR/linux" \
    -B "$HOST_BUILD_DIR" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$BUNDLE_DIR" \
    -DCMAKE_C_COMPILER=/usr/bin/clang \
    -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
    -DPKG_CONFIG_EXECUTABLE=/usr/bin/pkg-config \
    -DFLUTTER_TARGET_PLATFORM=linux-x64
  /usr/bin/cmake --build "$HOST_BUILD_DIR" --target install
fi

if [[ ! -x "$BUNDLE_DIR/local_pos" ]]; then
  echo "Linux release bundle was not found at: $BUNDLE_DIR" >&2
  echo "Run this script without --skip-build to compile the host-toolchain bundle." >&2
  exit 1
fi

rm -rf "$PACKAGE_ROOT"
mkdir -p \
  "$PACKAGE_ROOT/DEBIAN" \
  "$PACKAGE_ROOT/opt/$PACKAGE_NAME" \
  "$PACKAGE_ROOT/usr/bin" \
  "$PACKAGE_ROOT/usr/share/applications" \
  "$PACKAGE_ROOT/usr/share/icons/hicolor/512x512/apps" \
  "$DIST_DIR"

cp -a "$BUNDLE_DIR/." "$PACKAGE_ROOT/opt/$PACKAGE_NAME/"
install -m 0644 \
  "$ROOT_DIR/assets/icons/Admin_res.png" \
  "$PACKAGE_ROOT/usr/share/icons/hicolor/512x512/apps/$PACKAGE_NAME.png"

ln -s "/opt/$PACKAGE_NAME/local_pos" "$PACKAGE_ROOT/usr/bin/$PACKAGE_NAME"

cat > "$PACKAGE_ROOT/DEBIAN/control" <<EOF
Package: $PACKAGE_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Depends: libgtk-3-0 | libgtk-3-0t64, libgstreamer1.0-0, libgstreamer-plugins-base1.0-0, libsqlite3-0, libstdc++6
Maintainer: TeraByteAI
Description: $APP_NAME desktop restaurant point-of-sale software
 Native desktop POS for counter sales, dine-in tables, shifts, reporting,
 offline operation, and thermal receipt printing.
EOF

cat > "$PACKAGE_ROOT/usr/share/applications/$PACKAGE_NAME.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$APP_NAME
Comment=Restaurant point-of-sale software
Exec=$PACKAGE_NAME
Icon=$PACKAGE_NAME
Terminal=false
Categories=Office;Finance;
StartupNotify=true
EOF

chmod 0755 "$PACKAGE_ROOT/DEBIAN"
dpkg-deb --root-owner-group --build "$PACKAGE_ROOT" "$OUTPUT"

echo
echo "Created: $OUTPUT"
echo "Install with:"
echo "  sudo apt install \"$OUTPUT\""
