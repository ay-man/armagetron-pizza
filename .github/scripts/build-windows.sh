#!/usr/bin/env bash
# Cross-compiles the 32 bit Windows client with MinGW and lays it out as a
# folder you can unzip and run: the .exe, its DLLs and the game data side by side.
# Usage: build-windows.sh <work dir> <output folder>
# Run from the repository root after build-windows-deps.sh <work dir>.
set -euo pipefail

WORK="$(cd "$1" && pwd)"
OUT="$(mkdir -p "$2" && cd "$2" && pwd)"
HOST=i686-w64-mingw32
P="$WORK/prefix"
SRCDIR="$(pwd)"
BUILD="$WORK/build"
STAGE="$WORK/stage"

echo "::group::bootstrap"
test -x configure || ./bootstrap.sh
echo "::endgroup::"

SDL_CFLAGS="-I$P/include/SDL -D_GNU_SOURCE=1"
SDL_LIBS="-L$P/lib -lmingw32 -lSDLmain -lSDL -mwindows"

# stand-in for sdl-config: configure asks it whether this is a Windows build
mkdir -p "$WORK/tools"
cat > "$WORK/tools/sdl-config" <<EOF
#!/bin/sh
case "\$1" in
  --cflags) echo "$SDL_CFLAGS" ;;
  --libs) echo "$SDL_LIBS" ;;
  --version) echo 1.2.15 ;;
esac
EOF
chmod +x "$WORK/tools/sdl-config"
export PATH="$WORK/tools:$PATH"

echo "::group::configure"
rm -rf "$BUILD" && mkdir -p "$BUILD"
cd "$BUILD"
# Windows system libraries use the stdcall convention, which autoconf's
# generic link tests can't detect, so declare them as present.
"$SRCDIR/configure" --host=$HOST --prefix=/ \
    --disable-sysinstall --disable-desktop --disable-uninstall --enable-music --disable-binreloc \
    ac_cv_lib_opengl32_glVertex3f=yes \
    ac_cv_lib_glu32_gluBuild3DMipmaps=yes \
    ac_cv_lib_wsock32_connect=yes \
    ac_cv_lib_SDL_mixer_Mix_OpenAudio=yes \
    SDL_CONFIG="$WORK/tools/sdl-config" \
    CPPFLAGS="-include $SRCDIR/.github/scripts/mingw-config.h -I$P/include -I$P/include/SDL" \
    LDFLAGS="-L$P/lib -L$P/bin -static-libgcc -static-libstdc++" \
    SDL_CFLAGS="$SDL_CFLAGS" \
    SDL_LIBS="$SDL_LIBS" \
    SDL_IMAGE_CFLAGS="-I$P/include/SDL" \
    SDL_IMAGE_LIBS="-L$P/bin -lSDL_image $SDL_LIBS" \
    XML2_CFLAGS="-I$P/include/libxml2 -DLIBXML_STATIC" \
    XML2_LIBS="-L$P/lib -lxml2 -lz -lws2_32" \
    LIBPNG_CFLAGS="-I$P/include/libpng16" \
    LIBPNG_LIBS="-L$P/lib -lpng16 -lz" \
    || { cat config.log | tail -60; exit 1; }
echo "::endgroup::"

echo "::group::build"
make -k -j"$(nproc)"
echo "::endgroup::"

echo "::group::stage"
rm -rf "$STAGE"
make install DESTDIR="$STAGE"
echo "::endgroup::"

# flatten: data folders next to the exe, settings in config/
DATA="$(dirname "$(find "$STAGE" -path '*/language/english_base.txt' | head -1)")/.."
CONF="$(dirname "$(find "$STAGE" -name settings.cfg | head -1)")"
EXE="$(find "$BUILD/src" -maxdepth 1 -name 'armagetronad_main.exe' | head -1)"
test -n "$EXE" && test -d "$DATA" && test -d "$CONF"

rm -rf "$OUT" && mkdir -p "$OUT/config"
cp -r "$DATA"/. "$OUT/"
cp -r "$CONF"/. "$OUT/config/"
cp "$EXE" "$OUT/armagetronad.exe"
cp "$P"/bin/*.dll "$OUT/"
cp "$SRCDIR/COPYING.txt" "$OUT/" 2>/dev/null || true
cp "$SRCDIR/PIZZA_CHANGELOG.md" "$OUT/"
"$HOST-strip" "$OUT/armagetronad.exe"

echo "Windows build ready in $OUT:"
ls "$OUT"
