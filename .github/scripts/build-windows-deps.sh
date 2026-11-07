#!/usr/bin/env bash
# Builds/downloads the 32 bit Windows (MinGW) libraries the client needs.
# Usage: build-windows-deps.sh <work dir>
# Result: <work dir>/prefix with include/, lib/ and bin/ (DLLs to ship).
set -euo pipefail

WORK="$(mkdir -p "$1" && cd "$1" && pwd)"
HOST=i686-w64-mingw32
PREFIX="$WORK/prefix"
DL="$WORK/downloads"
SRC="$WORK/src"
mkdir -p "$PREFIX"/{include,lib,bin} "$DL" "$SRC"
JOBS="$(nproc)"

fetch() { # url -> local file
    local f="$DL/$(basename "$1")"
    [ -s "$f" ] || curl -fsSL --retry 3 -o "$f" "$1"
    echo "$f"
}

echo "::group::zlib"
tar -C "$SRC" -xzf "$(fetch https://zlib.net/fossils/zlib-1.3.1.tar.gz)"
make -C "$SRC/zlib-1.3.1" -f win32/Makefile.gcc PREFIX=$HOST- libz.a -j"$JOBS"
cp "$SRC/zlib-1.3.1/libz.a" "$PREFIX/lib/"
cp "$SRC/zlib-1.3.1/zlib.h" "$SRC/zlib-1.3.1/zconf.h" "$PREFIX/include/"
echo "::endgroup::"

echo "::group::libpng"
tar -C "$SRC" -xJf "$(fetch https://download.sourceforge.net/libpng/libpng-1.6.43.tar.xz)"
( cd "$SRC/libpng-1.6.43" &&
  CPPFLAGS="-I$PREFIX/include" LDFLAGS="-L$PREFIX/lib" \
  ./configure --host=$HOST --prefix="$PREFIX" --disable-shared --enable-static &&
  make -j"$JOBS" && make install )
echo "::endgroup::"

echo "::group::libxml2"
tar -C "$SRC" -xJf "$(fetch https://download.gnome.org/sources/libxml2/2.9/libxml2-2.9.14.tar.xz)"
( cd "$SRC/libxml2-2.9.14" &&
  CPPFLAGS="-I$PREFIX/include" LDFLAGS="-L$PREFIX/lib" \
  ./configure --host=$HOST --prefix="$PREFIX" --disable-shared --enable-static \
      --without-python --without-lzma --without-iconv --without-icu \
      --with-http --without-catalog --with-zlib="$PREFIX" &&
  make -j"$JOBS" && make install )
echo "::endgroup::"

echo "::group::SDL 1.2"
tar -C "$SRC" -xzf "$(fetch https://www.libsdl.org/release/SDL-devel-1.2.15-mingw32.tar.gz)"
cp -r "$SRC/SDL-1.2.15/include/SDL" "$PREFIX/include/"
cp "$SRC/SDL-1.2.15/lib/"libSDL*.a "$PREFIX/lib/"
cp "$SRC/SDL-1.2.15/bin/SDL.dll" "$PREFIX/bin/"
echo "::endgroup::"

# SDL_image and SDL_mixer: official prebuilt DLLs, MinGW links against DLLs directly
for pkg in SDL_image-devel-1.2.12-VC SDL_mixer-devel-1.2.12-VC; do
    name="${pkg%%-devel*}"
    echo "::group::$name"
    rm -rf "$SRC/$pkg" && mkdir -p "$SRC/$pkg"
    unzip -q -o "$(fetch https://www.libsdl.org/projects/$name/release/$pkg.zip)" -d "$SRC/$pkg"
    d="$(find "$SRC/$pkg" -maxdepth 1 -mindepth 1 -type d | head -1)"
    cp "$d"/include/*.h "$PREFIX/include/SDL/"
    cp "$d"/lib/x86/*.dll "$PREFIX/bin/"
    echo "::endgroup::"
done

ls -l "$PREFIX/lib" "$PREFIX/bin"
