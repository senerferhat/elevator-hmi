#!/bin/sh
# Elevator HMI — DSI panel modeset smoke test
# modetest -s needs the *connector* id (Connectors: block, column 1), not encoder nor CRTC.
# On RK3566 + DSI-1 this is often 191; encoder 190 / CRTC 112 are wrong for -s.
# LMT101-style: LED string may be fed from external ~9 V; board still drives LCD_BL_PWM / enables
# (see TASK-118). sysfs backlight only affects pixels if pwm-backlight is wired in DT.

set -eu

# Linux backlight class uses max_brightness (ABI). Some BSPs also expose "max" — try both.
bl_max_path() {
	_b="$1"
	if [ -r "$_b/max_brightness" ]; then
		echo "$_b/max_brightness"
	elif [ -r "$_b/max" ]; then
		echo "$_b/max"
	else
		echo ""
	fi
}

echo "=== DRM connectors (sysfs) ==="
for c in /sys/class/drm/card*-*/status; do
	printf "%s: %s\n" "$c" "$(cat "$c")"
done

echo "=== Resolving DSI-1 connector id ==="
DSI_CONN=$(modetest -M rockchip 2>/dev/null | awk '/connected/ && /DSI-1/ {print $1; exit}')
if [ -z "$DSI_CONN" ]; then
	echo "ERROR: no connected DSI-1 line in modetest output. Run: modetest -M rockchip" >&2
	exit 1
fi
echo "DSI-1 connector id: $DSI_CONN (example: modetest -M rockchip -s ${DSI_CONN}:#0)"

echo "=== Backlight (before modeset) ==="
for b in /sys/class/backlight/*; do
	[ -d "$b" ] || continue
	_m=$(bl_max_path "$b")
	printf "%s brightness=%s max_brightness=%s\n" "$b" "$(cat "$b/brightness" 2>/dev/null || echo "?")" "$([ -n "$_m" ] && cat "$_m" 2>/dev/null || echo "?")"
done

echo "=== Forcing modeset via modetest (#0 = first listed mode, often 800x1280) ==="
echo "(modetest -s stays running in the KMS hot path until exit; BusyBox/Coreutils-safe: brief background run + kill so this script continues.)"

MODLOG="/tmp/modetest-dsi.$$"
trap 'rm -f "$MODLOG"' EXIT

# Do NOT pipe modetest to head: modetest often prints one line then blocks; head waits for N lines → hang.
modetest -M rockchip -s "${DSI_CONN}:#0" >"$MODLOG" 2>&1 &
MPID=$!
sleep 3
kill "$MPID" 2>/dev/null || true
wait "$MPID" 2>/dev/null || true
# BusyBox head only accepts "-n NUMBER", not "-NUMBER"
head -n 15 "$MODLOG" 2>/dev/null || cat "$MODLOG"

echo "Note: this script stops modetest after a few seconds; some DRM stacks may go idle. For a steady modeset, run:"
echo "  modetest -M rockchip -s ${DSI_CONN}:#0"
echo "(leave it running or press Ctrl+C when done)"

echo "=== Backlight: set to max (often fixes black panel after modeset) ==="
for b in /sys/class/backlight/*; do
	_m=$(bl_max_path "$b")
	[ -n "$_m" ] && [ -r "$_m" ] && [ -w "$b/brightness" ] || continue
	maxv=$(cat "$_m")
	echo "$maxv" > "$b/brightness"
	echo "Set $(basename "$b") brightness -> $maxv (via $(basename "$_m"))"
done

echo "=== Panel regulator state (needs debugfs) ==="
if [ -r /sys/kernel/debug/regulator/vcc3v3_lcd0_n/enable ]; then
	cat /sys/kernel/debug/regulator/vcc3v3_lcd0_n/enable
else
	echo "(skip) mount debugfs: mount -t debugfs none /sys/kernel/debug"
fi
