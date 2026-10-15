#!/bin/sh
# Builds bin/toonsim on Linux with the system's Qt 5.15 (tools/build.bat is the Windows build).
# Debian/Ubuntu: the packages are in docs/MANUAL.md ("Linux").
set -e
cd "$(dirname "$0")/../src"
mkdir -p build-linux
cd build-linux
JOBS="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)"
QMAKE=qmake
if [ "$(uname)" = "Darwin" ]; then
	# macOS: Homebrew's keg-only qt@5; a plain binary (bin/toonsim) instead of toonsim.app
	for q in /opt/homebrew/opt/qt@5/bin/qmake /usr/local/opt/qt@5/bin/qmake; do [ -x "$q" ] && QMAKE="$q" && break; done
	"$QMAKE" ../toonsim.pro CONFIG+=release CONFIG-=app_bundle CONFIG+=sdk_no_version_check
else
	"$QMAKE" ../toonsim.pro CONFIG+=release
fi
make -j"$JOBS"
echo "built $(cd ../../bin && pwd)/toonsim"
