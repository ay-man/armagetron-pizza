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
    CPPFLAGS="-I$P/include -I$P/include/SDL -I$SRCDIR/src/render" \
    CXXFLAGS="-O2 -include $SRCDIR/.github/scripts/mingw-config.h" \
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
# internal test programs are not shipped and do not link with SDLmain
make -j"$(nproc)" noinst_PROGRAMS=
echo "::endgroup::"

echo "::group::stage"
rm -rf "$STAGE"
make install DESTDIR="$STAGE" noinst_PROGRAMS=
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
# MinGW's thread runtime, used by the game itself
cp "$(find /usr -path "*$HOST*" -name libwinpthread-1.dll | head -1)" "$OUT/"
# MP3 music only, needs an old C++ runtime; the game does not use MP3
rm -f "$OUT/smpeg.dll"
# Linux-only helpers
rm -rf "$OUT/desktop" "$OUT/scripts"
cp "$SRCDIR/COPYING.txt" "$OUT/" 2>/dev/null || true
cp "$SRCDIR/PIZZA_CHANGELOG.md" "$OUT/"
"$HOST-strip" "$OUT/armagetronad.exe"

# every DLL the exe or a shipped DLL imports must be shipped or part of Windows
echo "::group::check DLLs"
missing=0
for f in "$OUT"/*.exe "$OUT"/*.dll; do
    for dll in $("$HOST-objdump" -p "$f" | awk '/DLL Name/ {print $3}'); do
        if [ -e "$OUT/$dll" ]; then continue; fi
        case "$(echo "$dll" | tr 'A-Z' 'a-z')" in
            kernel32.dll|user32.dll|gdi32.dll|advapi32.dll|shell32.dll|msvcrt.dll|winmm.dll|\
            ws2_32.dll|wsock32.dll|opengl32.dll|glu32.dll|ole32.dll|oleaut32.dll|imm32.dll|\
            version.dll|setupapi.dll|dinput.dll|dsound.dll|ddraw.dll|dxguid.dll|comdlg32.dll) ;;
            *) echo "::error::$(basename "$f") needs $dll, which is not shipped"; missing=1 ;;
        esac
    done
done
echo "::endgroup::"
[ "$missing" = 0 ]

echo "Windows build ready in $OUT:"
ls "$OUT"
