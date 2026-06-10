# LMT101 XRES — dual-point scope procedure (EM3566 v3)

**Goal:** Prove the **~20 ms active-low** reset pulse from `jadard_prepare()` reaches the panel IC, not only the SoC pad.

**Software mapping (project DTB):**

| Item | Value |
|------|--------|
| Linux GPIO | **gpio-22** (`GPIO0_C6`) |
| libgpiod | **`gpiochip0` line `22`** |
| CON1 (carrier) | **pin 11** (`TOUCH_RST`) |
| LMT101 FPC | **pin 5** (`RESET` / XRES) |
| Idle (released) | **~3.3 V** on both probes |
| Asserted | **~0 V** for **~20 ms** during `prepare` |

**Image tools:** `libgpiod-tools` (`gpiodetect`, `gpioinfo`, `gpioset`) — see §4.

---

## 1. Prerequisites

1. Flash an image built **after** kernel patch **0009** (bring-up trace) and DT with **`reset-gpios = <&gpio0 RK_PC6 …>`** + **`&spi0 { status = "disabled"; }`**.
2. **Wiring:** FPC pin **5** ↔ CON1 pin **11** (continuity check with DMM beep mode).
3. **Rails:** CON1 pins **5–6** ≈ **3.3 V** (see `docs/FLASH-PROCEDURE.md` TASK-132/133).
4. **Scope:** Two channels (or one scope + one DMM on the second node). **Ground** on CON1 pin **3** or **4**.
5. UART console attached — trigger and `dmesg` timestamps must correlate.

---

## 2. When to arm the scope

**`modetest -s` on an already-active pipe does not call `prepare()` again.** XRES + init run **once at boot** (~2–4 s in `dmesg`). To see the pulse:

- **Cold boot:** arm scope on CON1 pin 11 + FPC pin 5, then power-cycle; or  
- **Force re-prepare:** `modetest -M rockchip -s <conn>:0` (disable), then `modetest -M rockchip -s <conn>:#0` (enable).

Flat **3.3 V during a manual `modetest` after boot** only means you missed the boot-time pulse — not necessarily a dead GPIO.

---

## 3. Trigger (single modeset)

```bash
mount -t debugfs none /sys/kernel/debug 2>/dev/null || true

CONN=$(modetest -M rockchip 2>&1 | awk '/connected/ && /DSI-1/ {print $1; exit}')
echo "CONN=$CONN"
test -n "$CONN"

# Blocks until Ctrl+C — run scope capture when this starts
modetest -M rockchip -s "${CONN}:#0"
```

**Optional 3 s smoke** (scope single-shot may still catch pulse if armed before command):

```bash
modetest -M rockchip -s "${CONN}:#0" >/tmp/modetest-xres.log 2>&1 &
sleep 3
kill %1 2>/dev/null
head -n 5 /tmp/modetest-xres.log
```

---

## 4. Scope capture (simultaneous)

| Probe | Attach | Expected waveform when `modetest` runs |
|-------|--------|----------------------------------------|
| **CH1** | CON1 **pin 11** (SoM side) | **HIGH** idle → **LOW ~20 ms** → **HIGH** → stable before MIPI init |
| **CH2** | FPC **pin 5** (panel side) | **Same shape** as CH1 (allow small RC delay / overshoot) |

**Settings (starting point):** 500 ms/div total window, 10 ms/div around pulse, **DC** coupling, 1× probe, trigger **CH1 falling** to **~1.6 V**, single-shot.

**PASS**

- Both channels show a **~20 ms LOW** pulse (18–25 ms acceptable).
- **CH2** tracks **CH1** (not stuck HIGH/LOW).
- UART/`dmesg` shows (patch **0009**):
  - `jadard: reset gpio = gpio-22`
  - `jadard: XRES assert` / `jadard: XRES release`
  - `jadard: dsi mode_flags=0x… lanes=4 format=0 video=1 burst=1`
- `jadard: init table: 196 cmds, rc=0` (after generic-write burst)
- `jadard: SLPOUT sent` (DCS **0x11**, after table)
- `jadard: DISON sent` (DCS **0x29**, after **120 ms** post-SLPOUT + `0xE0/0x00`)
- `jadard: GET_POWER_MODE(0x0A)=0x..` (panel ACK on bus) or read failed

**FAIL**

| Observation | Likely cause |
|-------------|----------------|
| Pulse on **pin 11** only; FPC **pin 5** stuck HIGH | Open FPC reset net, wrong FPC pin, flex damage |
| **No** pulse on pin 11; `reset gpio = ABSENT` | DT missing `reset-gpios` or wrong DTB flashed |
| `reset gpio = gpio-23` (not 22) | Old DTB (PC7 mapping) — reflash kernel+DTB |
| Pin 11 stuck **LOW** at idle | **SPI0** still enabled, wrong pin, or short |
| Pulse **&lt;5 ms** or **&gt;50 ms** | Wrong kernel (pre-0008), or scope timebase |
| `gpioset` works but no pulse on modetest | DRM not calling `prepare` — check connector / `dmesg` |

---

## 5. libgpiod (on-target)

```bash
gpiodetect
# Expect gpiochip0 [gpio0] ...

gpioinfo gpiochip0 | grep -E '^line\s+22:'
# Expect: line  22:  "reset"  output  active-low  [used]  (when jadard bound)

# While panel driver is loaded — expect EBUSY (driver owns the line):
gpioset -m time -s 1 gpiochip0 22=0 2>&1
# PASS message contains: Device or resource busy
```

**Interpretation:** **`EBUSY`** after probe = **correct** (kernel holds reset). If `gpioset` toggles the line while `jadard` is bound, the driver did not claim GPIO-22 — check probe/`dmesg`.

**debugfs cross-check:**

```bash
grep -E 'gpio-22|reset' /sys/kernel/debug/gpio
# Idle after boot: gpio-22 ... reset ... out hi
```

---

## 6. Evidence checklist (paste into `diary/PROGRESS.md`)

- [ ] Photo or scope screenshot: CH1 + CH2, **~20 ms** LOW
- [ ] `dmesg | grep jadard` after modetest (four trace lines above)
- [ ] `gpioinfo gpiochip0` line **22** + `gpioset` **EBUSY** snippet
- [ ] `modetest` first line: `setting mode 800x1280…`

---

*See also:* `docs/LAB-LMT101-TEST-CHEATSHEET.md`, `docs/FLASH-PROCEDURE.md` (rail protocol).
