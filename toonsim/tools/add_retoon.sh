#!/bin/sh
# Puts the ReToon setup app (../ReToon) in the simulator's apps folder, so its tile and setup screen can
# be tried. Only the QML goes in. retoon.sh is NOT copied: the real one writes boot partitions and reboots
# a Toon 2; apps/retoon/retoon.sh is tools/retoon-sim.sh instead, which only fakes the progress messages.
#
#   sh tools/add_retoon.sh [apps-folder]       (default: toonsim/apps)
# then restart toonsim; add the ReToon tile through the GUI's tile chooser. After "Install and start"
# the app says everything is in place; nothing is written anywhere and nothing restarts.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$HERE/../../ReToon
DEST=${1:-$HERE/../apps}/retoon
[ -f "$SRC/RetoonApp.qml" ] || { echo "ReToon/RetoonApp.qml not found next to toonsim" >&2; exit 1; }
mkdir -p "$DEST"
cp "$SRC"/RetoonApp.qml "$SRC"/RetoonScreen.qml "$SRC"/RetoonTile.qml "$SRC"/version.txt "$SRC"/Changelog.txt "$DEST"/
cp "$HERE/retoon-sim.sh" "$DEST/retoon.sh"
echo "ReToon installed in $DEST (simulated install script: it writes nothing and restarts nothing)"
