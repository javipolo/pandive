#!/usr/bin/env bash
#
# Cross-compiles libdivecomputer for Android using the NDK.
# Produces libdivecomputer.so per ABI in build/android/<abi>/install/lib/.
#
# Requirements:
#   - Android NDK installed. Export ANDROID_NDK pointing to it, e.g.:
#       export ANDROID_NDK=$HOME/Android/ndk/27.2.12479018
#   - autotools (autoconf/automake/libtool), host clang not needed.
#
# Usage:
#   ./scripts/build-libdivecomputer-android.sh
#
set -euo pipefail

: "${ANDROID_NDK:?Exporta ANDROID_NDK con la ruta al NDK (p.ej. \$HOME/Android/ndk/27.2.12479018)}"

API=24                       # minSdk 24 (Android 7.0); stable BLE
HOST_TAG=linux-x86_64
ABIS=(arm64-v8a armeabi-v7a x86_64)   # x86_64 only useful for the emulator (no BLE)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/vendor/libdivecomputer"
OUT="$ROOT/build/android"
TOOLCHAIN="$ANDROID_NDK/toolchains/llvm/prebuilt/$HOST_TAG"

[ -d "$TOOLCHAIN" ] || { echo "No existe toolchain NDK: $TOOLCHAIN"; exit 1; }

# clang compiler triple vs configure --host triple (they differ on 32-bit arm)
declare -A CC_TRIPLE=( [arm64-v8a]=aarch64-linux-android [armeabi-v7a]=armv7a-linux-androideabi [x86_64]=x86_64-linux-android )
declare -A CONF_HOST=( [arm64-v8a]=aarch64-linux-android [armeabi-v7a]=arm-linux-androideabi   [x86_64]=x86_64-linux-android )

# generate ./configure if missing (git clone)
[ -x "$SRC/configure" ] || ( cd "$SRC" && autoreconf --install )

# clean previous config in the source tree (e.g. from a native build),
# which would make out-of-tree builds fail with "source directory already configured"
[ -f "$SRC/Makefile" ] && ( cd "$SRC" && make distclean >/dev/null 2>&1 || true )

for ABI in "${ABIS[@]}"; do
  echo "=== Building $ABI ==="
  CCT=${CC_TRIPLE[$ABI]}
  export CC="$TOOLCHAIN/bin/${CCT}${API}-clang"
  export AR="$TOOLCHAIN/bin/llvm-ar"
  export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
  export STRIP="$TOOLCHAIN/bin/llvm-strip"
  export CFLAGS="-O2 -fPIC"

  BUILDDIR="$OUT/$ABI/build"
  PREFIX="$OUT/$ABI/install"
  rm -rf "$BUILDDIR" "$PREFIX"
  mkdir -p "$BUILDDIR"

  ( cd "$BUILDDIR" && "$SRC/configure" \
      --host="${CONF_HOST[$ABI]}" \
      --prefix="$PREFIX" \
      --enable-shared --disable-static \
      --without-libusb --without-hidapi \
      --disable-examples --disable-doc )

  make -C "$BUILDDIR" -j"$(nproc)"
  make -C "$BUILDDIR" install
  echo "--- $ABI done:"; ls -la "$PREFIX/lib/"*.so* 2>/dev/null || true
done

echo
echo "OK. Libraries in $OUT/<abi>/install/lib/"
echo "Headers in $OUT/arm64-v8a/install/include/libdivecomputer/"
