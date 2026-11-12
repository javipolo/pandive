#!/usr/bin/env bash
#
# Cross-compila libdivecomputer para Android usando el NDK.
# Produce libdivecomputer.so por ABI en build/android/<abi>/install/lib/.
#
# Requisitos:
#   - Android NDK instalado. Exporta ANDROID_NDK apuntando a el, p.ej:
#       export ANDROID_NDK=$HOME/Android/ndk/27.2.12479018
#   - autotools (autoconf/automake/libtool), clang host no necesario.
#
# Uso:
#   ./scripts/build-libdivecomputer-android.sh
#
set -euo pipefail

: "${ANDROID_NDK:?Exporta ANDROID_NDK con la ruta al NDK (p.ej. \$HOME/Android/ndk/27.2.12479018)}"

API=24                       # minSdk 24 (Android 7.0); BLE estable
HOST_TAG=linux-x86_64
ABIS=(arm64-v8a armeabi-v7a x86_64)   # x86_64 solo util para emulador (sin BLE)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/vendor/libdivecomputer"
OUT="$ROOT/build/android"
TOOLCHAIN="$ANDROID_NDK/toolchains/llvm/prebuilt/$HOST_TAG"

[ -d "$TOOLCHAIN" ] || { echo "No existe toolchain NDK: $TOOLCHAIN"; exit 1; }

# triple del compilador clang vs triple --host de configure (difieren en 32-bit arm)
declare -A CC_TRIPLE=( [arm64-v8a]=aarch64-linux-android [armeabi-v7a]=armv7a-linux-androideabi [x86_64]=x86_64-linux-android )
declare -A CONF_HOST=( [arm64-v8a]=aarch64-linux-android [armeabi-v7a]=arm-linux-androideabi   [x86_64]=x86_64-linux-android )

# generar ./configure si falta (clon de git)
[ -x "$SRC/configure" ] || ( cd "$SRC" && autoreconf --install )

# limpiar config previa en el arbol de fuentes (p.ej. de un build nativo),
# que haria fallar los builds out-of-tree con "source directory already configured"
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
  echo "--- $ABI listo:"; ls -la "$PREFIX/lib/"*.so* 2>/dev/null || true
done

echo
echo "OK. Librerias en $OUT/<abi>/install/lib/"
echo "Headers en $OUT/arm64-v8a/install/include/libdivecomputer/"
