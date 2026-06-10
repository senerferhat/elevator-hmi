# LMT101 + EM3566 v3 — External lab test cheat sheet

**Board:** Boardcon EM3566 v3 (CM3566) · **Panel:** LMT101SX006C (800×1280, 4-lane MIPI-DSI)  
**Current flash target (2026-06-10 — BUILD B):** `core-image-minimal-elevator-hmi-em3566.rootfs-20260610170030.wic`  
**SHA-256:** `dd5be78dec198a984dce271a658219b3e44006df58d04709a3bed66fbb9728ad`  
**Login:** `root` (no password on minimal image) · **Console:** UART 1500000 8N1 (`ttyFIQ0`)

> **Artifact-triple rule:** every bench result must be logged with (1) WIC SHA-256, (2) the dmesg build-signature line observed ON target, (3) `git rev-parse HEAD` (`e19ae163`).

Print this page. Run phases in order. Record **PASS / FAIL** and measured voltages in the blank column.

---

## 1. Pin map (what the software actually drives)

| CON1 pin | Net | SoM signal | Linux GPIO | Role | Idle PASS (DMM) |
|----------|-----|------------|------------|------|-----------------|
| **5, 6** | VCC3V3_LCD | (carrier Q17 output) | — | Panel **3.3 V logic** | **~3.3 V** |
| **11** | TOUCH_RST | GPIO0_C6 / SPI0_CS0_M0 | **gpio-22** `reset` | Panel **XRES** (active-low) | **~3.3 V** (reset released) |
| **13** | LCD_PWREN_H | GPIO0_C7 | gpio-23 | **Not** the main rail switch | don't use for rail pass/fail |
| **14** | LCD_BL_PWM | PWM (backlight dim) | — | Backlight PWM | scope optional |
| — | (carrier only) | **PWM0_M0** / GPIO0_B7 | **gpio-15** `vcc3v3-lcd0-n` | **Switches VCC3V3_LCD** (Q18→Q17) | debugfs **`out hi`** |

**Wiring reminders**

- LCD FPC pin **5 (RESET)** → CON1 pin **11** (not 9 or 10).
- LCD FPC pins **2–3 (VDDIN)** → CON1 pins **5–6**.
- **Plan B bypass** (if installed): `VCC3V3_SYS` → CON1 **5/6** — pins 5/6 always ~3.3 V; still run GPIO checks.

---

## 2. One-time setup on the board

```bash
mount -t debugfs none /sys/kernel/debug
```

BusyBox note: use `head -n 20`, not `head -20`.

### libgpiod (reset line diagnostics)

Image includes **`libgpiod-tools`**: `gpiodetect`, `gpioinfo`, `gpioset`.

| Item | Value |
|------|--------|
| Panel **XRES** / `reset-gpios` | **`gpiochip0` line `22`** (= **gpio-22**, CON1 **pin 11**) |
| Idle | **out hi** in debugfs (~3.3 V at pin 11) |
| `gpioset gpiochip0 22=…` while `jadard` loaded | **`Device or resource busy`** = **PASS** (driver owns the line) |

```bash
gpiodetect
gpioinfo gpiochip0 | grep -E '^line\s+22:'
gpioset -m time -s 1 gpiochip0 22=0 2>&1   # expect EBUSY when driver bound
```

**End-to-end reset pulse (scope):** `docs/LMT101-XRES-SCOPE-PROCEDURE.md` — dual probe **CON1 pin 11** + **FPC pin 5** during `modetest -M rockchip -s <conn>:#0`.

---

## 3. Test phases — commands and pass criteria

### Phase A — Boot and image sanity

| Step | Command | PASS when |
|------|---------|-----------|
| A1 | Power on, watch UART | U-Boot → Linux → **`login:`** prompt |
| A2 | `root` + Enter | Shell prompt `#` |
| A3 | `uname -r` | Contains **`6.1`** |
| A4 | `cat /proc/device-tree/compatible` | Includes **`boardcon,em3566`** or project board string |
| A5 | `ls -la /boot/*.dtb /boot/Image` | **`elevator-hmi-boardcon-em3566-v3.dtb`** present |
| A6 | `grep -i jadard /boot/config-* 2>/dev/null \|\| zcat /proc/config.gz 2>/dev/null \| grep JADARD` | **`CONFIG_DRM_PANEL_JADARD_JD9365DA_H3=y`** |

---

### Phase B — GPIO and regulator (no panel modeset yet)

| Step | Command | PASS when |
|------|---------|-----------|
| B1 | `cat /sys/kernel/debug/gpio \| grep -E 'gpio-1[45]|gpio-22\|lcd\|reset'` | **gpio-15** → `vcc3v3-lcd0-n` **`out hi`** · **gpio-22** → `reset` **`out hi`** · **no gpio-14** (I2C B6) |
| B2 | `cat /sys/kernel/debug/regulator/vcc3v3_lcd0_n/enable` | **`1`** |
| B3 | `cat /sys/kernel/debug/regulator/vcca_1v8/enable` | **`1`** |
| B4 | `ls /sys/class/drm/card*-*` | At least one connector; **`...-DSI-1`** or similar exists |

**FAIL hints:** gpio-15 **`out lo`** → LCD rail software off · gpio-22 **`out lo`** → panel held in reset.

---

### Phase C — DMM at idle (before `modetest`)

Measure **CON1 pin vs GND (pin 3 or 4)**. FPC connected unless doing no-load rail check.

| Step | Measurement point | PASS when | FAIL means |
|------|-------------------|-----------|------------|
| C1 | **Pin 5 or 6** (VCC3V3_LCD) | **2.9–3.6 V** | Rail off or Plan B missing + gpio-15 wrong |
| C2 | **Pin 11** (RESET / XRES) | **2.9–3.6 V** | Reset stuck active (check gpio-22, wiring) |
| C3 | **Pin 9** (I2C SCL) | **~3.3 V** idle | OK if high (not used for reset) |
| C4 | **Pin 10** (I2C SDA) | **~3.3 V** idle | OK if high (not used for reset) |
| C5 | **Pin 13** (LCD_PWREN_H) | any | **Informational only** — not rail switch |

Optional no-load rail check (FPC unplugged): repeat **C1** — still expect **~3.3 V** with `regulator-always-on`.

---

### Phase D — DRM / DSI / panel driver (software)

| Step | Command | PASS when |
|------|---------|-----------|
| D1 | `modetest -M rockchip 2>&1 \| head -n 80` | Line with **`DSI-1`** and **`connected`** |
| D2 | `modetest -M rockchip 2>&1 \| awk '/connected/ && /DSI-1/ {print $1; exit}'` | Prints connector id (often **`191`**) |
| D3 | `cat /sys/class/drm/card*-DSI-*/status` | **`connected`** |
| D4 | `dmesg \| grep -iE 'jadard\|jd9365\|panel\|dsi' \| tail -n 30` | **`jadard`** probe OK · **no repeating `-517`** defer loop · **no** `init cmd` / `generic_write` errors |
| D5 | `ls /sys/bus/platform/drivers/jadard-jd9365da/` | Directory exists (driver bound) |

---

### Phase E — Modeset (triggers panel init + XRES pulse)

**Important:** `modetest -s` **blocks** until Ctrl+C. For a steady picture, leave it running.

| Step | Command | PASS when |
|------|---------|-----------|
| E1 | `CONN=$(modetest -M rockchip 2>&1 \| awk '/connected/ && /DSI-1/ {print $1; exit}'); echo "CONN=$CONN"` | `CONN=191` (or similar, not empty) |
| E2 | `modetest -M rockchip -s ${CONN}:#0` | First line like **`setting mode 800x1280`** · **no immediate error** · leave running for visual check |
| E3 | (second terminal or after E2) `dmesg \| tail -n 40` | No new **jadard** errors after modeset |

**Quick non-blocking smoke (optional):**

```bash
CONN=$(modetest -M rockchip 2>&1 | awk '/connected/ && /DSI-1/ {print $1; exit}')
modetest -M rockchip -s ${CONN}:#0 >/tmp/modetest.log 2>&1 &
sleep 3
kill %1 2>/dev/null; head -n 5 /tmp/modetest.log
```

PASS: log contains **`setting mode 800x1280`**.

---

### Phase F — Backlight and bundled script

| Step | Command | PASS when |
|------|---------|-----------|
| F1 | `ls /sys/class/backlight/` | At least one entry (e.g. **`backlight`**) |
| F2 | `cat /sys/class/backlight/*/brightness` | Numeric (e.g. **200**) |
| F3 | `cat /sys/class/backlight/*/max_brightness 2>/dev/null \|\| cat /sys/class/backlight/*/max` | **255** or similar |
| F4 | `echo 255 > /sys/class/backlight/backlight/brightness` (adjust path if needed) | No error |
| F5 | `test-display` | Script exits **0** · shows **DSI-1 connected** · **setting mode 800x1280** in log |

---

### Phase G — Visual acceptance

| Step | Check | PASS when |
|------|-------|-----------|
| G1 | With **E2** still running (or rerun E2) | Panel shows **test pattern / color bars** (not black) |
| G2 | After **F4** max brightness | Backlight visibly on (may need external LED supply per carrier) |
| G3 | Power cycle, repeat E2 once | Image returns (no one-shot only failure) |

**Backlit black with all software PASS (2026-06-02):** Linux is **scanning** — use **Phase H** below. Next: **vendor FAE** (`docs/VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL.txt`) + **MIPI scope** on CLK/D0. Not more `modetest` without **`-P 96`**.

---

### Phase H — DRM plane + sustained pattern (software lab closure)

Run after **Phase E** modeset OK but **G1 FAIL** (backlit only).

| Step | Command | PASS when |
|------|---------|-----------|
| H1 | `mount -t debugfs none /sys/kernel/debug` | No error |
| H2 | `cat /sys/kernel/debug/dri/0/state \| sed -n '/plane\[96\]/,/plane\[/p' \| head -n 12` | **plane[96]** `Smart1-win0`, **fb=**, **XR24**, **800x1280** |
| H3 | `modetest -M rockchip -s 191@112:#0 -P 96@112:800x1280+0+0 -F tiles -v` | **`setting mode 800x1280`** · **`testing … plane 96`** · **`freq: 60.08Hz`** repeating |
| H4 | Visual | **FAIL expected today:** backlit black despite H3 PASS — log **BLK-014** / email vendor |

**Wrong plane id:** `modetest -P 57@112` → `no unused plane` — use **96**, not **57**.

**Stop stuck modetest:** `killall -9 modetest`

**Optional framebuffer probe:**

```bash
tr '\000' '\377' </dev/zero | dd of=/dev/fb0 bs=4096 count=1000 status=none
```

---

## 4. Copy-paste full suite (run as `root`)

```bash
# --- setup ---
mount -t debugfs none /sys/kernel/debug

echo "=== A: boot sanity ==="
uname -r
ls -la /boot/elevator-hmi-boardcon-em3566-v3.dtb /boot/Image

echo "=== B: GPIO / regulators ==="
cat /sys/kernel/debug/gpio | grep -E 'gpio-1[45]|gpio-22|lcd|reset'
cat /sys/kernel/debug/regulator/vcc3v3_lcd0_n/enable
cat /sys/kernel/debug/regulator/vcca_1v8/enable

echo "=== D: DSI / driver ==="
modetest -M rockchip 2>&1 | head -n 40
cat /sys/class/drm/card*-DSI-*/status
dmesg | grep -iE 'jadard|jd9365|panel|dsi' | tail -n 25

echo "=== E: modeset (3 s smoke) ==="
CONN=$(modetest -M rockchip 2>&1 | awk '/connected/ && /DSI-1/ {print $1; exit}')
echo "CONN=$CONN"
modetest -M rockchip -s ${CONN}:#0 >/tmp/modetest.log 2>&1 &
sleep 3
kill %1 2>/dev/null
head -n 8 /tmp/modetest.log

echo "=== F: backlight + script ==="
ls /sys/class/backlight/
test-display

echo "=== DONE — now run Phase C DMM and Phase G visual with: ==="
echo "  modetest -M rockchip -s ${CONN}:#0"
```

---

## 5. Results worksheet (fill at lab — BUILD B / Phase J)

**WIC SHA (verify before flash):** `dd5be78dec198a984dce271a658219b3e44006df58d04709a3bed66fbb9728ad`  
**Tester:** ______________ **Date:** __________ **git HEAD:** `e19ae163`

| Phase | Step | Measured / observed | PASS / FAIL |
|-------|------|---------------------|-------------|
| J0 | WIC SHA verified | dd5be78d… | |
| J1 | dmesg: `FAE page-4 clock fix` present | yes / no | |
| J1 | dmesg: `BIST armed` absent | yes / no | |
| **J2** | **`GET_POWER_MODE(0x0A) pre-TE`** | **0x______** | |
| J2 | Booster bit (0x80) | SET / CLEAR | |
| J3 | FPC pin 2/3 (VDDIN) idle voltage | ______ V | |
| J3 | FPC pin 2/3 VDDIN at SLPOUT | ______ V | |
| J3 | Ammeter: current step at SLPOUT | ______ → ______ mA | |
| C1 | CON1 pin 5/6 (VCC3V3_LCD) | ______ V | |
| C2 | CON1 pin 11 (XRES idle) | ______ V | |
| B1 | gpio-22 state | ______ | |
| D1 | DSI-1 connected | yes / no | |
| J4 | modetest plane 96 / 60 Hz | yes / no | |
| J4 | **Visible pattern on glass** | **yes / no** | |

**Verdict (circle one):** BOOSTER UP / BOOSTER OFF-POWER / BOOSTER OFF-SOFTWARE / PASS

---

## 6. Quick FAIL → action

| Symptom | Likely cause | Next check |
|---------|--------------|------------|
| Pin **5/6 ~0 V**, gpio-15 **lo** | Rail enable wrong or Q17 path | Re-flash latest WIC · scope PWM0_M0 (SoM pin 140) |
| Pin **5/6 ~3.3 V**, pin **11 ~0.9 V** | Reset stuck | gpio-22 must be **hi** at idle · FPC pin 5 → CON1 pin 11 |
| modetest OK, **backlit black** | Software complete — **BLK-014** | Phase **H** (plane **96**, `-F tiles -v`) · vendor email · scope CLK/D0 |
| modetest OK, **pitch black** (no glow) | Backlight path | LED supply · **F4** · external 9 V |
| **`dmesg` `-517` loop** | Regulator defer storm | Wrong/old DTB — use **20260521225949** or newer PWM0_M0 fix |
| **`jadard` init errors** | DSI / init table | Paste full `dmesg \| grep -i jadard` to project log |

---

### Phase I — FAE BIST v1 (BUILD A — historical, already flashed, result = BIST black)

| Step | Result |
|------|--------|
| WIC | `…20260606151107` / SHA `d2ce5af7…` — **retired**, file gone from disk |
| Boot | `jadard: BIST armed (500ms post-unlock)` confirmed in dmesg |
| Glass | **Black** — `GET_POWER_MODE(0x0A) = 0x18` → booster bit D7 CLEAR |
| Conclusion | Booster (JD5001 charge pump → AVDD/AVEE/VGH/VGL) never started. BIST black and video black share the same root cause. |

---

### Phase J — BUILD B (FAE page-4 clock fix) — **CURRENT BENCH TARGET**

> **Decisive test:** `GET_POWER_MODE(0x0A) pre-TE`. Booster bit = 0x80.  
> A healthy panel after SLPOUT + clock fix reads **0x9C**. Board currently reads **0x18** (booster off).  
> This phase determines which fault domain owns the failure.

#### J0 — Flash (host, before powering the panel)

```bash
# Step 0a: verify SHA before flashing (do not skip)
DEPLOY=build/tmp/deploy/images/elevator-hmi-em3566
sha256sum "$DEPLOY/core-image-minimal-elevator-hmi-em3566.rootfs-fae-clock.wic"
# Expected: dd5be78dec198a984dce271a658219b3e44006df58d04709a3bed66fbb9728ad

# Step 0b: enter Maskrom
# Power off → hold RECOVERY → plug USB OTG → release RECOVERY after 2s
lsusb | grep 2207   # expect 2207:350a (Maskrom) or 2207:0006 (Loader)

# Step 0c: flash (Maskrom path)
cd "$DEPLOY"
sudo rkdeveloptool db loader.bin
sudo rkdeveloptool wl 0 core-image-minimal-elevator-hmi-em3566.rootfs-fae-clock.wic
sudo rkdeveloptool wl 64 idblock.img
sudo rkdeveloptool wl 0x4000 uboot.img
sudo rkdeveloptool rd

# Loader mode (2207:0006): omit the 'db' line above
```

Expected flash time: ~4 min for 3.1 GiB WIC. `rd` triggers reboot — open UART now.

---

#### J1 — Boot signature (UART / dmesg, no panel needed)

```bash
# On board as root — run immediately after boot
dmesg | grep -i jadard
```

| Line | Expected | FAIL means |
|------|----------|------------|
| `jadard: dsi mode_flags=0x…` | Present | Driver not loaded |
| `jadard: FAE page-4 clock fix (pre-SLPOUT)` | **MUST be present** | Wrong image flashed (BIST or old build) |
| `jadard: BIST armed` | **MUST NOT appear** | Wrong descriptor selected — check bbappend |
| `jadard: XRES assert` | Present | Reset GPIO not wired |
| `jadard: XRES release` | Present | — |
| `jadard: init table: 196 cmds, rc=0` | **`rc=0`** | Init table comms failure |
| `jadard: SLPOUT sent` | Present | — |
| `jadard: GET_POWER_MODE(0x0A) pre-TE=0x??` | **Record the hex value — it is the verdict** | — |
| `jadard: FAE TE on (0x35,0x00)` | Present after power-mode read | — |

**Record the full jadard dmesg block verbatim and paste into `diary/PROGRESS.md`.**

---

#### J2 — Booster-bit verdict (the decisive measurement)

Read the `GET_POWER_MODE(0x0A) pre-TE=0x??` value from J1:

| `0x0A` value | Bit 7 (0x80) | Meaning | Next action |
|---|---|---|---|
| **`0x9C`** | **SET** | Booster up, sleep-out+normal+display-on | Glass test (J4) then modetest (J5). If still black → H5 lane continuity |
| `0x18` | **CLEAR** | Booster still off despite clock fix | Combine with B1 VDDIN measurement → H1 (power) or H4 (init table) domain |
| `0x08` | CLEAR | Booster off + sleep-out dropped | Brown-out on VDDIN during charge-pump start attempt → H1 (power) |
| `0x9E` or `0x1C` | SET / depends | Partial | Note value, continue to J4 |

**DCS 0x0A bit map:**

```
Bit 7 = 0x80  Booster on (JD5001 charge pump → AVDD/AVEE/VGH/VGL)
Bit 4 = 0x10  Sleep out
Bit 3 = 0x08  Normal display mode
Bit 2 = 0x04  Display on
Healthy after init = 0x9C (0x80|0x10|0x08|0x04)
```

---

#### J3 — VDDIN power measurement (parallel to J1/J2, no reflash needed)

Run this **while J1/J2 diagnostics are fresh in dmesg** — the board stays powered.

**Equipment:** DMM (minimum). Preferred: bench supply 3.3V / 1A with ammeter.

| Measurement | Point | PASS | Failure mode |
|-------------|-------|------|--------------|
| **VDDIN idle** | FPC pin 2 or 3 vs pin 4 (GND) | **3.1–3.5 V** | Plan B jumper contact loss / sag |
| **VDDIN at SLPOUT** (~3.4–4.0 s from boot) | FPC pin 2 or 3 vs GND | Same **3.1–3.5 V** | Sag → H1 supply domain |
| **CON1 5/6 at idle** | CON1 pin 5 or 6 vs pin 3 (GND) | **3.0–3.5 V** | Plan B jumper not making contact |

**Ammeter test (preferred — decisive for H1):**
1. Remove Plan B jumper from CON1 5/6.
2. Connect bench supply: **3.3V, 1A limit** → FPC pins 2 and 3. GND → FPC pin 4.
3. Power on board. Watch ammeter from ~3s onward.
4. Record:
   - Idle current (before boot): _____ mA
   - Current at SLPOUT (~3.7 s): does it **step up**? _____ mA → _____ mA
   - Current after init: _____ mA steady

**Interpretation:**
- No current step = panel never attempted booster → software/rate domain (consistent with H2/H4)
- Current steps up then collapses = supply sag under load → H1 (fix jumper gauge/contact)
- Current steps up and holds → booster started; if 0x0A still 0x18, panel is defective (H6)

---

#### J4 — Glass check (visual, with modetest tiles pattern)

```bash
# Run from board as root — modetest is blocking; Ctrl+C to stop
CONN=$(modetest -M rockchip 2>&1 | awk '/connected/ && /DSI-1/ {print $1; exit}')
echo "CONN=$CONN"   # expect 191

modetest -M rockchip -s ${CONN}@112:#0 -P 96@112:800x1280+0+0 -F tiles -v
```

| Output line | PASS when |
|-------------|-----------|
| `setting mode 800x1280-60` | First line of modetest output |
| `testing plane 96…` | Plane id confirmed |
| `freq: 60.08Hz` | Repeating — SoC scanout running |
| **Glass** | **Color bars / tile pattern visible** |

If `0x0A` showed `0x9C` (booster up) in J2 but glass is black here → proceed to H5 (FPC lane continuity check, `library/LMT101/` FPC pin map: D0(8/9), D1(11/12), CLK(14/15), D2(17/18), D3(20/21)).

---

#### J5 — DRM state confirmation (after J4 modetest running)

```bash
# In a second terminal or after stopping modetest
mount -t debugfs none /sys/kernel/debug 2>/dev/null || true

# Plane state
cat /sys/kernel/debug/dri/0/state | sed -n '/plane\[96\]/,/plane\[/p' | head -15

# Framebuffer fill smoke (optional, tests fb0 path separately from modetest)
tr '\000' '\377' </dev/zero | dd of=/dev/fb0 bs=4096 count=1000 status=none
# Then watch glass — should show white if booster is up and lanes are OK
```

---

#### J6 — Full copy-paste suite (BUILD B, run as root)

```bash
#!/bin/sh
# BUILD B test suite — paste as root on target
# WIC: dd5be78dec198a984dce271a658219b3e44006df58d04709a3bed66fbb9728ad
# git HEAD: e19ae163b81db9c08b1b04813b313079787f0ff0

echo "=== [J1] dmesg jadard — BUILD B signature check ==="
dmesg | grep -i jadard

echo ""
echo "=== [J1] EXPECTED: FAE page-4 clock fix (pre-SLPOUT) ==="
echo "=== [J1] EXPECTED: GET_POWER_MODE(0x0A) pre-TE=0x?? — record value ==="
echo "=== [J1] MUST NOT: BIST armed ==="

echo ""
echo "=== [A] Boot sanity ==="
uname -r
ls -la /boot/elevator-hmi-boardcon-em3566-v3.dtb /boot/Image
grep CONFIG_DRM_PANEL_JADARD /proc/config.gz 2>/dev/null | zcat 2>/dev/null || \
  grep CONFIG_DRM_PANEL_JADARD /boot/config-* 2>/dev/null | head -1

echo ""
echo "=== [B] GPIO and regulators ==="
mount -t debugfs none /sys/kernel/debug 2>/dev/null || true
cat /sys/kernel/debug/gpio | grep -E 'gpio-22|gpio-23|gpio-15|lcd|reset'
cat /sys/kernel/debug/regulator/vcc3v3_lcd0_n/enable 2>/dev/null && echo " (vcc3v3_lcd0_n enable)"
cat /sys/kernel/debug/regulator/vcca_1v8/enable 2>/dev/null && echo " (vcca_1v8 enable)"

echo ""
echo "=== [C] VDDIN voltage (DMM — manual step) ==="
echo "  Measure FPC pin 2 or 3 vs GND (pin 4) with DMM → record _____ V"
echo "  Measure CON1 pin 5 or 6 vs GND (pin 3) → record _____ V"

echo ""
echo "=== [D] DSI / driver ==="
modetest -M rockchip 2>&1 | head -n 60
cat /sys/class/drm/card*-DSI-*/status 2>/dev/null

echo ""
echo "=== [J4] Modeset + plane 96 (3 s smoke) ==="
CONN=$(modetest -M rockchip 2>&1 | awk '/connected/ && /DSI-1/ {print $1; exit}')
echo "CONN=$CONN"
modetest -M rockchip -s ${CONN}@112:#0 -P 96@112:800x1280+0+0 -F tiles -v \
  >/tmp/modetest_buildb.log 2>&1 &
MPID=$!
sleep 4
kill $MPID 2>/dev/null
echo "--- modetest log head ---"
head -n 15 /tmp/modetest_buildb.log
echo "--- modetest log tail ---"
tail -n 5 /tmp/modetest_buildb.log

echo ""
echo "=== [J5] DRM plane state ==="
cat /sys/kernel/debug/dri/0/state 2>/dev/null | sed -n '/plane\[96\]/,/plane\[/p' | head -12

echo ""
echo "=== DONE ==="
echo "Paste ALL output above into diary/PROGRESS.md with:"
echo "  WIC SHA: dd5be78dec198a984dce271a658219b3e44006df58d04709a3bed66fbb9728ad"
echo "  dmesg build signature: jadard: FAE page-4 clock fix (pre-SLPOUT)"
echo "  git HEAD: e19ae163b81db9c08b1b04813b313079787f0ff0"
```

---

#### J7 — Decision matrix (fill after J1–J3)

| J3 VDDIN | J2 `0x0A` | J4 glass | Verdict | Next action |
|---|---|---|---|---|
| 3.1–3.5 V solid, current steps up at SLPOUT | **0x9C** (0x80 set) | **Color bars visible** | **FULL PASS — BLK-014 CLOSED** | Log, push, A1 review |
| 3.1–3.5 V solid, current steps up | 0x9C set | Still black | Booster OK, video path fail | H5: lane continuity FPC 8–21 vs spec; then non-burst exact-420 descriptor |
| 3.1–3.5 V solid, **no current step** | 0x18 | Black | Panel never attempted booster despite good power + clock fix | Vendor (B5 email update + booster question) + H6 spare panels |
| Sag / collapse / low reading at FPC | any | any | Supply domain (H1) | Fix Plan B jumper (gauge/contact); bench-supply VDDIN permanently; re-run J1–J4 |
| 3.1–3.5 V solid | 0x18 | — | Clock fix did not unlock booster | Check if 0x0A was read before or after DISON; consider diag patch 0015 (TASK-136) |

---

## 7. Lab status (2026-06-10)

| Item | Status |
|------|--------|
| GPIO / rails / reset (**PC6 / gpio-22**) | **PASS** (BLK-006 closed) |
| `jadard` init + DSI link (**196 cmds, rc=0**) | **PASS** |
| DRM scanout plane **96** @ **60.08 Hz** | **PASS** |
| `GET_POWER_MODE(0x0A)` | **0x18** — booster bit D7 CLEAR (BLK-014) |
| Visible pixels on glass | **FAIL** — BLK-014 (booster never starts) |
| Current image on eMMC | **BIST v1** (`d2ce5af7…`) |
| **Flash target** | **BUILD B** `dd5be78d…` (`…20260610170030.wic`) |
| FAE patches in-tree | **0011–0014** committed HEAD `e19ae163` |
| bbappend | **BUILD B default** (0011+0014+0013 active, 0012 commented) |
| Next gate | **Phase J** above — booster-bit verdict after BUILD B flash |

## 8. Reference files (repo)

- Vendor email: `docs/VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL.txt`
- Technical brief: `docs/VENDOR-SUPPORT-LMT101-BRINGUP.md`
- Pin wiring: `library/LMT101/EM3566-CON1-to-panel-40pin-mapping.md`
- Flash steps: `docs/FLASH-PROCEDURE.md`
- FAE build guide: `docs/FAE-BIST-CLOCK-BUILD.md`
- Clock rate audit: `docs/LMT101-CLOCK-RATE-AUDIT.md`
- Session log: `diary/PROGRESS.md`
- Schematic: `library/EM3566/Schematic/em3566_v3sch.md` (sheet 11 — Q17/Q18/PWM0_M0)
