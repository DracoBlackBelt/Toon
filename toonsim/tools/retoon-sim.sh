#!/bin/sh
# Stand-in for ReToon/retoon.sh in the simulator (tools/add_retoon.sh copies it to apps/retoon/retoon.sh).
#
# The real retoon.sh runs as root on a Toon 2: it mounts /dev/mmcblk3p1 and p3, writes a kernel, a boot
# script and a root filesystem, and reboots. None of that may happen on a PC, so this script does
# none of it: it only writes the same /tmp/retoon.status messages (so the app's tile and screen can be
# tried), with a pause between the steps, and remembers in /tmp/retoon.sim-installed that the "install"
# was pressed. It touches nothing but the files named here, in the simulator's /tmp.
#
#   check    -> needed (first time) or ready (after a fake install)
#   install  -> steps 1..7, then ready "(Simulator: nothing was written, no restart.)"
#   RETOON_SIM_FAIL=1 in the environment of toonsim -> install ends in an error, to see that screen

STATUS=/tmp/retoon.status
DONE=/tmp/retoon.sim-installed
STEPS=7

ACTION=${1:-$(cat /tmp/retoon.request 2>/dev/null)}
rm -f /tmp/retoon.request
[ -n "$ACTION" ] || ACTION=check

status() {	# state, step, text
	printf '{"state":"%s","step":%s,"steps":%s,"text":"%s"}\n' "$1" "$2" $STEPS "$3" > $STATUS.tmp
	mv $STATUS.tmp $STATUS
}

case "$ACTION" in
check)
	if [ -f $DONE ]; then
		status ready 0 "ReToon is on this Toon. Press the button to start it. (Simulator: nothing is really installed.)"
	else
		status needed 0 "ReToon is not on this Toon yet (7 files to put in place). Press the button to install and start it. (Simulator: nothing is really installed.)"
	fi
	;;
install)
	status working 1 "Unpacking (simulated)"; sleep 2
	status working 2 "Putting the system in place (simulated)"; sleep 2
	status working 3 "Putting the start-up files in place (simulated)"; sleep 2
	status working 4 "Taking over the WiFi settings (simulated)"; sleep 1
	status working 5 "Copying the WiFi and Bluetooth firmware (simulated)"; sleep 1
	status working 6 "Preparing the restart (simulated)"; sleep 2
	if [ -n "$RETOON_SIM_FAIL" ]; then
		status error 0 "Simulated failure: the boot partition cannot be written."
		exit 1
	fi
	touch $DONE
	status ready $STEPS "Everything is in place. (Simulator: nothing was written, no restart.)"
	;;
*)
	status error 0 "Unknown request: $ACTION"
	exit 1
	;;
esac
