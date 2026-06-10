#!/bin/sh
# EM3566 v3 — manual GPIO toggle for lab (CON4 header + CON1 panel XRES).
#
# CON4 (§2.10 EM3566 hardware manual): signals are **1.8 V** (VDDIO_18 on pins 11–12).
# Default test pin: **CON4 pin 2** = CIF_8BIT_HREF = GPIO4_B6 (gpiochip4 line 14).
#
# Panel RESET (LMT101 FPC pin 5) on carrier **CON1 pin 11** = GPIO0_C6 (**3.3 V**).
# Do **not** wire CON4 (1.8 V) directly to panel RESET unless you confirm the panel
# accepts 1.8 V logic on RESX; use `reset-*` commands for the existing CON1 wire.
#
# Needs: gpioset/gpioget (libgpiod-tools) **or** legacy /sys/class/gpio export.
# If a line is "busy", another driver owns it — stop modetest / check debugfs gpio.

set -eu

CON4_PIN="${CON4_PIN:-2}"

# chip, line (within chip), global (legacy sysfs), name
con4_pin_spec() {
	_p="$1"
	case "$_p" in
	1)  echo "4 17 145 CIF_8BIT_CLKIN GPIO4_C1" ;;
	2)  echo "4 14 142 CIF_8BIT_HREF GPIO4_B6" ;;
	3)  echo "4 5 133 CIF_8BIT_D7 GPIO4_A5" ;;
	4)  echo "4 4 132 CIF_8BIT_D6 GPIO4_A4" ;;
	5)  echo "4 3 131 CIF_8BIT_D5 GPIO4_A3" ;;
	6)  echo "4 2 130 CIF_8BIT_D4 GPIO4_A2" ;;
	7)  echo "4 1 129 CIF_8BIT_D3 GPIO4_A1" ;;
	8)  echo "4 0 128 CIF_8BIT_D2 GPIO4_A0" ;;
	9)  echo "3 31 127 CIF_8BIT_D1 GPIO3_D7" ;;
	10) echo "3 30 126 CIF_8BIT_D0 GPIO3_D6" ;;
	*)  echo "unknown" >&2; return 1 ;;
	esac
}

RESET_CHIP=0
RESET_LINE=22
RESET_GLOBAL=22

usage() {
	cat <<'EOF'
Usage: con4-gpio-toggle <command> [args]

CON4 (1.8 V header) — default pin 2 (HREF), override with CON4_PIN=1..10:
  status              Show gpiod/sysfs state for CON4 pin + panel reset GPIO
  hi | lo | toggle    Drive CON4 pin high / low / square wave (toggle [period_s] [count])
  pulse [low_ms]      Brief low pulse on CON4 pin (default 500 ms)

CON1 pin 11 panel XRES (GPIO0_C6, 3.3 V, active-low semantics):
  reset-status        Read reset line (1 = released / ~3.3 V, 0 = asserted / low)
  reset-hi            Release reset (drive high)
  reset-lo            Assert reset (drive low)
  reset-pulse         Vendor Q1-ish: 10 ms idle, 20 ms low, 120 ms idle

Examples:
  con4-gpio-toggle status
  con4-gpio-toggle hi
  con4-gpio-toggle toggle 1 10          # 1 Hz, 10 cycles on CON4 pin 2
  CON4_PIN=10 con4-gpio-toggle lo
  con4-gpio-toggle reset-hi
  con4-gpio-toggle reset-pulse

Scope: CON4 pin vs GND (pin 13/14) should swing 0–1.8 V. CON1 pin 11 vs GND: 0–3.3 V.
EOF
}

debugfs_gpio() {
	if [ ! -d /sys/kernel/debug/gpio ]; then
		mount -t debugfs none /sys/kernel/debug 2>/dev/null || true
	fi
	[ -r /sys/kernel/debug/gpio ] && cat /sys/kernel/debug/gpio
}

line_status() {
	_label="$1"
	_chip="$2"
	_line="$3"
	_global="$4"
	if command -v gpioget >/dev/null 2>&1; then
		_val=$(gpioget "gpiochip${_chip}" "${_line}" 2>/dev/null) || _val="?"
		printf "%s: gpiochip%s line %s (= global gpio-%s) gpioget=%s\n" \
			"$_label" "$_chip" "$_line" "$_global" "$_val"
	elif [ -d "/sys/class/gpio/gpio${_global}" ]; then
		printf "%s: gpio-%s sysfs value=%s direction=%s\n" \
			"$_label" "$_global" \
			"$(cat "/sys/class/gpio/gpio${_global}/value" 2>/dev/null || echo '?')" \
			"$(cat "/sys/class/gpio/gpio${_global}/direction" 2>/dev/null || echo '?')"
	else
		printf "%s: gpiochip%s line %s (global gpio-%s) — not exported\n" \
			"$_label" "$_chip" "$_line" "$_global"
	fi
}

gpio_export_sysfs() {
	_g="$1"
	if [ -d "/sys/class/gpio/gpio${_g}" ]; then
		return 0
	fi
	if [ ! -w /sys/class/gpio/export ]; then
		echo "ERROR: /sys/class/gpio/export missing (use libgpiod-tools or enable GPIO sysfs)" >&2
		return 1
	fi
	echo "$_g" > /sys/class/gpio/export
	echo out > "/sys/class/gpio/gpio${_g}/direction"
}

gpio_set() {
	_chip="$1"
	_line="$2"
	_global="$3"
	_val="$4"
	if command -v gpioset >/dev/null 2>&1; then
		gpioset -c "gpiochip${_chip}" -t0 "${_line}=${_val}"
		return 0
	fi
	gpio_export_sysfs "$_global"
	echo "$_val" > "/sys/class/gpio/gpio${_global}/value"
}

cmd_status() {
	read -r _c _l _g _n _rk <<EOF
$(con4_pin_spec "$CON4_PIN")
EOF
	echo "=== CON4 pin ${CON4_PIN} (${_n}, ${_rk}) — 1.8 V domain ==="
	line_status "CON4" "$_c" "$_l" "$_g"
	echo "=== CON1 pin 11 panel XRES (GPIO0_C6) — 3.3 V, active-low ==="
	line_status "RESET" "$RESET_CHIP" "$RESET_LINE" "$RESET_GLOBAL"
	echo "=== debugfs gpio (claimed lines) ==="
	debugfs_gpio 2>/dev/null | grep -E 'gpio-(126|127|128|129|130|131|132|133|142|145|22)|reset' || true
}

cmd_con4() {
	_mode="$1"
	shift
	read -r _c _l _g _n _rk <<EOF
$(con4_pin_spec "$CON4_PIN")
EOF
	case "$_mode" in
	hi)  gpio_set "$_c" "$_l" "$_g" 1 ;;
	lo)  gpio_set "$_c" "$_l" "$_g" 0 ;;
	toggle)
		_period="${1:-1}"
		_count="${2:-0}"
		_i=0
		while [ "$_count" -eq 0 ] || [ "$_i" -lt "$_count" ]; do
			gpio_set "$_c" "$_l" "$_g" 1
			sleep "$_period"
			gpio_set "$_c" "$_l" "$_g" 0
			sleep "$_period"
			_i=$((_i + 1))
		done
		;;
	pulse)
		_low_ms="${1:-500}"
		gpio_set "$_c" "$_l" "$_g" 1
		sleep 0.05
		gpio_set "$_c" "$_l" "$_g" 0
		# BusyBox sleep may lack fractional seconds
		sleep "$(awk "BEGIN { printf \"%.3f\", ${_low_ms}/1000 }")" 2>/dev/null || sleep 1
		gpio_set "$_c" "$_l" "$_g" 1
		;;
	esac
	echo "CON4 pin ${CON4_PIN} (${_n}): ${_mode} done"
}

cmd_reset() {
	_sub="$1"
	case "$_sub" in
	status)
		line_status "RESET" "$RESET_CHIP" "$RESET_LINE" "$RESET_GLOBAL"
		;;
	hi)
		gpio_set "$RESET_CHIP" "$RESET_LINE" "$RESET_GLOBAL" 1
		echo "RESET released (expect ~3.3 V on CON1 pin 11)"
		;;
	lo)
		gpio_set "$RESET_CHIP" "$RESET_LINE" "$RESET_GLOBAL" 0
		echo "RESET asserted (expect ~0 V on CON1 pin 11)"
		;;
	pulse)
		gpio_set "$RESET_CHIP" "$RESET_LINE" "$RESET_GLOBAL" 1
		sleep 0.01
		gpio_set "$RESET_CHIP" "$RESET_LINE" "$RESET_GLOBAL" 0
		sleep 0.02
		gpio_set "$RESET_CHIP" "$RESET_LINE" "$RESET_GLOBAL" 1
		sleep 0.12
		echo "RESET pulse done (vendor Q1 timing: 10/20/120 ms)"
		;;
	esac
}

main() {
	[ $# -ge 1 ] || { usage; exit 1; }
	case "$1" in
	status)        cmd_status ;;
	hi|lo)         cmd_con4 "$1" ;;
	toggle)        shift; cmd_con4 toggle "$@" ;;
	pulse)         shift; cmd_con4 pulse "$@" ;;
	reset-status)  cmd_reset status ;;
	reset-hi)      cmd_reset hi ;;
	reset-lo)      cmd_reset lo ;;
	reset-pulse)   cmd_reset pulse ;;
	-h|--help)     usage ;;
	*)             usage; exit 1 ;;
	esac
}

main "$@"
