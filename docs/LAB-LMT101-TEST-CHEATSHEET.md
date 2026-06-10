# LMT101 + EM3566 v3 — External lab test cheat sheet

**Board:** Boardcon EM3566 v3 (CM3566) · **Panel:** LMT101SX006C (800×1280, 4-lane MIPI-DSI)  
**Image (2026-05-22 build):** `core-image-minimal-elevator-hmi-em3566.rootfs-20260521225949.wic`  
**Login:** `root` (no password on minimal image) · **Console:** UART 115200 8N1 (`ttyFIQ0`)

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

## 5. Results worksheet (fill at lab)

| Phase | Item | Measured / observed | PASS / FAIL |
|-------|------|---------------------|-------------|
| C1 | CON1 pin 5/6 voltage | ______ V | |
| C2 | CON1 pin 11 voltage | ______ V | |
| B1 | gpio-15 state | ______ | |
| B1 | gpio-22 state | ______ | |
| D1 | DSI-1 connected | yes / no | |
| E2 | modetest 800x1280 | yes / no | |
| G1 | Picture on panel | yes / no | |

**Tester:** ______________ **Date:** __________ **WIC flashed:** __________

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

### Phase I — FAE BIST (BUILD A — flash before clock fix)

| Step | Command / action | PASS when |
|------|------------------|-----------|
| I1 | Flash WIC built with **0011+0012** (`docs/FAE-BIST-CLOCK-BUILD.md`) | Image labeled **fae-bist** |
| I2 | Cold boot; `dmesg \| grep -i jadard` | **`FAE BIST enable sequence`** |
| I3 | **Visual only** — do not run modetest first | **Pattern on glass** = panel OK → proceed BUILD B |
| I4 | Still backlit black | Log in `diary/PROGRESS.md`; may be panel/power — not only MIPI rate |

---

## 7. Lab status (2026-06-02)

| Item | Status |
|------|--------|
| GPIO / rails / reset (**PC6**) | **PASS** |
| `jadard` init + DSI link | **PASS** |
| DRM scanout plane **96** @ 60 Hz | **PASS** |
| Visible pixels on glass | **FAIL** — **BLK-014** |
| FAE patches | **0011–0013** in-tree; **BUILD A (BIST)** default in `bbappend` |
| Next gate | Flash **TASK-134** BIST → **TASK-135** clock fix |

## 8. Reference files (repo)

- Vendor email: `docs/VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL.txt`
- Technical brief: `docs/VENDOR-SUPPORT-LMT101-BRINGUP.md`
- Pin wiring: `library/LMT101/EM3566-CON1-to-panel-40pin-mapping.md`
- Flash steps: `docs/FLASH-PROCEDURE.md`
- Session log: `diary/PROGRESS.md` (2026-06-02)
- Schematic: `library/EM3566/Schematic/em3566_v3sch.md` (sheet 11 — Q17/Q18/PWM0_M0)
