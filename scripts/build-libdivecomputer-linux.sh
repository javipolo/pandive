#!/usr/bin/env bash
#
# Compila libdivecomputer para la app Linux (x86_64 nativo) como librería
# estática con -fPIC, que se enlaza dentro del ejecutable de Flutter.
# Produce build/linux-ldc/install/lib/libdivecomputer.a.
#
# El transporte BLE lo pone la app (dc_custom_open + BlueZ por D-Bus), así que
# no hace falta libusb/hidapi/bluez de libdivecomputer.
#
# Uso:
#   ./scripts/build-libdivecomputer-linux.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/vendor/libdivecomputer"
OUT="$ROOT/build/linux-ldc"

[ -d "$SRC" ] || { echo "Falta $SRC (clona libdivecomputer, ver README)"; exit 1; }

# generar ./configure si falta (clon de git)
[ -x "$SRC/configure" ] || ( cd "$SRC" && autoreconf --install )

# limpiar config previa en el árbol de fuentes (builds out-of-tree)
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
