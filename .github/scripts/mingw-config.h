/* Force-included into every file of the MinGW Windows build
   (see build-windows.sh); mirrors src/win32/config_common.h. */

/* include windows.h first so its renaming macros (GetUserName ->
   GetUserNameA and friends) apply consistently to every file */
#include <windows.h>

/* the particle library is compiled into the game, not used as a DLL */
#define PARTICLEDLL_EXPORTS

/* per-user settings, logs and screenshots; kept apart from the
   official Armagetron Advanced so the two never mix */
#define USER_DATA_DIR  "${APPDATA}/Armagetron Pizza"
#define SCREENSHOT_DIR "${MYPICTURES}/Armagetron Pizza"
