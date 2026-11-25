#!/usr/bin/env bash
#
# Builds libdivecomputer for the Linux app (native x86_64) as a static
# library with -fPIC, linked into the Flutter executable.
# Produces build/linux-ldc/install/lib/libdivecomputer.a.
#
# The app provides the BLE transport (dc_custom_open + BlueZ over D-Bus), so
# libdivecomputer's libusb/hidapi/bluez aren't needed.
#
# Usage:
#   ./scripts/build-libdivecomputer-linux.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/vendor/libdivecomputer"
OUT="$ROOT/build/linux-ldc"

[ -d "$SRC" ] || { echo "Falta $SRC (clona libdivecomputer, ver README)"; exit 1; }

# generate ./configure if missing (git clone)
[ -x "$SRC/configure" ] || ( cd "$SRC" && autoreconf --install )

# clean previous config in the source tree (out-of-tree builds)
[ -f "$SRC/Makefile" ] && ( cd "$SRC" && make distclean >/dev/null 2>&1 || true )

BUILDDIR="$OUT/build"
PREFIX="$OUT/install"
rm -rf "$BUILDDIR" "$PREFIX"
mkdir -p "$BUILDDIR"

( cd "$BUILDDIR" && CFLAGS="-O2 -fPIC" "$SRC/configure" \
    --prefix="$PREFIX" \
    --disable-shared --enable-static \
    --without-libusb --without-hidapi --without-bluez \
    --disable-examples --disable-doc )

make -C "$BUILDDIR" -j"$(nproc)"
make -C "$BUILDDIR" install
ls -la "$PREFIX/lib/libdivecomputer.a"
