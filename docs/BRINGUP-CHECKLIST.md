# EM3566 v3 — first Yocto image bring-up checklist

Canonical lab checklist for **Boardcon EM3566 v3** + project `**kas`** workspace. Project context: `[CLAUDE.md](../CLAUDE.md)`. Tasks: `[AGENTS.md](../AGENTS.md)`. Board collateral index: `[library/EM3566/README.md](../library/EM3566/README.md)`.

---

## 1. Build host (TASK-002)

- Use **Ubuntu 22.04 or 24.04 LTS** — both are allowed by `[scripts/setup-build-host.sh](../scripts/setup-build-host.sh)` (TASK-002 originally validated **22.04**; **24.04** uses the same package set in this repo).
- Run `**./scripts/setup-build-host.sh`** once (requires `sudo` for `apt-get`). This installs Scarthgap host deps including `**lz4c`** (`liblz4-tool`), without which BitBake stops immediately (`HOSTTOOLS`). If you skip the script, install at least `**liblz4-tool`** before `**kas build`**.
- Ensure `**kas`** is on `**PATH`** (for example `pip install --user kas` → add `~/.local/bin` to `**PATH`**).
- From the **repository root** (so `KAS_WORK_DIR` is the project root), run builds — see `[README.md](../README.md)`.

---

## 2. Build images with kas

Default manifest: `**kas/elevator-hmi.yml`** — `**MACHINE = elevator-hmi-em3566`**, `**target: core-image-minimal`**.

Smoke sequence (same as **TASK-105**; optional one-shot script `**./scripts/kas-build-task-105.sh`** — see `[scripts/README.md](../scripts/README.md)`):

```bash
cd /path/to/elevator-hmi
mkdir -p build-logs

kas build kas/elevator-hmi.yml --target u-boot-rockchip 2>&1 | tee build-logs/u-boot-rockchip.log
kas build kas/elevator-hmi.yml --target virtual/kernel 2>&1 | tee build-logs/virtual-kernel.log
kas build kas/elevator-hmi.yml 2>&1 | tee build-logs/core-image-minimal.log
```

- Logs under `**build-logs/**` are **gitignored**; keep them locally for A1 / diary notes.
- `**kas dump kas/elevator-hmi.yml`** — quick manifest sanity check (no BitBake).

---

## 3. Where outputs land (after a green build)

Typical deploy directory (Yocto default layout under the kas build dir):

- `**build/tmp/deploy/images/elevator-hmi-em3566/`**

Expect (among others) a `**.wic`** eMMC image and Rockchip `**rockchip-image`** artefacts (e.g. `**rootfs.img`** symlink to ext4 — see BitBake log on success). Exact filenames vary by `**IMAGE_NAME`** / version; use `**ls -la`** on that directory after `**do_image_complete`**.

**TASK-105 / lab:** A green `**kas build`** on this manifest has produced `**core-image-minimal-elevator-hmi-em3566.rootfs.wic`** plus `**loader.bin`**, `**idblock.img`**, `**uboot.img**` under the path above — see `**diary/PROGRESS.md**` (2026-04-18 lab milestone) for a stable `**rkdeveloptool**` command block using those symlinks.

**Partition geometry** comes from `**meta-hmi-platform/wic/elevator-hmi-emmc.wks.in`** (TASK-003). Do **not** change the `**.wks`** file without an A1 task spec.

---

## 4. UART console (host ↔ board)

- Use the carrier **serial / debug headers** for **U-Boot + Linux** logs (interim diagnostics — `[CLAUDE.md](../CLAUDE.md)` §8).
- **Pinout / connector table:** `[library/EM3566/Usermanual/EM3566_hardware_manual.md](../library/EM3566/Usermanual/EM3566_hardware_manual.md)` (see TOC **§2.14 UART (J10, J11, J12)** and board overview for **debug** vs **UART1/2**).
- **Baud:** Rockchip BSPs commonly use **115200 8N1** — confirm against **meta-rockchip** / vendor U-Boot defconfig for your exact image if serial is garbage.

---

## 5. Display: MIPI LCD + LMT101

- Attach **LMT101SX006C** (when available) to the carrier `**MIPI LCD`** connector — **not** a generic “LVDS-only” assumption; see `[library/EM3566/README.md](../library/EM3566/README.md)` and `**BLK-002`** in `[diary/BLOCKERS.md](../diary/BLOCKERS.md)`.
- **JD9365 XRES / `reset-gpios`:** open `**BLK-006`** — do **not** invent a `**reset-gpios`** line without a **traced** net / cited GPIO.
- **§5.2** — step-by-step **Ask** / command / **Pass if** checks on the board console (kernel + DRM + backlight + image match).

### 5.1 — On-board: DRM modeset with `modetest` (panel power / rails)

Linux may not modeset the DSI panel by default; **LMT101 800×1280** bring-up images ship `**modetest`** (`libdrm-tests`) so you can force a modeset from the shell (this runs `**panel` `prepare()`**, which can bring up rails such as `**vcc3v3_lcd0_n`**).

** Preconditions (typical):**

- Log in as `**root`** on serial (or SSH if enabled).
- If `**/sys/kernel/debug`** is empty: `mount -t debugfs none /sys/kernel/debug`

**Important — use the *connector* id, not encoder or CRTC.** In `modetest -M rockchip` output, under `**Connectors:`**, `**DSI-1`** has a line like `191 190 connected DSI-1 …`. The `**191**` is the connector id for `-s`. The `**190**` is the **encoder** id; `**112`** in `**CRTCs:`** is the **CRTC** id — those are **wrong** for `modetest -s` and yield `failed to find mode "800x1280"`.

**Quick smoke (bundled script, if the image includes it):**

```sh
test-display
```

**Equivalent manual commands:**

```sh
# See which connectors exist and their status
for c in /sys/class/drm/card*-*/status; do echo "$c: $(cat "$c")"; done

# Full topology: encoders, connectors (note connector id = column 1 on DSI-1 line), CRTCs, planes
modetest -M rockchip

# Force modeset: DSI-1 connector id @ 800×1280 (example from lab: connector 191, not 190 nor 112)
modetest -M rockchip -s 191:800x1280

# If WxH matching fails, try mode by index (here #0 is 800x1280 in modetest):
# modetest -M rockchip -s 191:#0

# Optional: confirm LCD rail enable after modeset (debugfs)
cat /sys/kernel/debug/regulator/vcc3v3_lcd0_n/enable
```

**BusyBox / `modetest` gotchas:**

- After `setting mode 800x1280…`, `**modetest -s` keeps running** until you press **Ctrl+C** (it holds the KMS client). The shell looking “stuck” is **expected** unless you background the process or exit it.
- **Do not pipe** `modetest -s` to `**head -40`**: BusyBox rejects GNU-style `**head -40`** (`invalid option -- '4'`); use `**head -n 40**` only if you truly need truncation. More importantly, `**modetest` often prints one line then blocks** while `**head`** waits for 40 lines — the pipeline **stalls**.
- Bundled `**test-display`** avoids that: it runs `**modetest` for a few seconds in the background**, then continues with backlight max and regulator checks (rebuild image to pick up script fixes).

**Check framebuffer (if `CONFIG_DRM_FBDEV_EMULATION=y`):**

```sh
ls -l /dev/fb0
```

If `**modetest**` reports **permission denied** on `**/dev/dri/card0`**, run as `**root`** or fix device node permissions for your test user.

### Black panel after a successful `modetest -s` line

If you see `**setting mode 800x1280-… on connectors 191, crtc 112**` but the LCD stays dark, distinguish two cases:

1. **Pitch black (no glow)** — often **LED string / boost / enable** never turns on; Linux `**brightness`** only helps if `**LCD_BL_PWM`** / `**pwm-backlight**` (`**TASK-118**`) actually reaches your driver (**BLK-008**).
2. **Backlit black (you see backlight glow)** — illumination works (often from **external LED supply** or always-on analogue path), but **no pixels**. Board `**brightness`** may **do nothing visible** if your bench wiring **bypasses** PWM dimming or `**LCD_BL_PWM`** is unused on your harness — **that is hardware routing**, not proof the kernel backlight device is useless. Priority shifts to **image path**: framebuffer paint, `**DISPLAY_ON`** / panel state, `**reset-gpios`** polarity (**BLK-006**).

If you see `**setting mode 800x1280-…`** but the LCD stays fully dark **without** an external backlight source, DSI timing may still be fine; bring-up `**LCD_PWREN_H`**, `**LCD_BL_PWM`**, and **~9 V** logic per schematic.

**When §5.2 checks A–J pass:** treat **DSI + panel digital path** as healthy. **Pitch-black** ⇒ chase **absolute LED power / enable / PWM routing**. **Backlit-black** ⇒ chase **pixels** ( `**fb0`** fill, `**reset-gpios`** / **BLK-006**, panel **DISPLAY_ON** / driver state — not MIPI-CSI2 camera `**dmesg`**).

**Project record:** `[diary/BLOCKERS.md](../diary/BLOCKERS.md)` **BLK-012** (includes **external backlight vs sysfs** nuance).

**Try on the running image (no reflash required):**

```sh
# 1) Turn backlight up everywhere the kernel exposes it
for b in /sys/class/backlight/*; do
  echo "--- $b ---"
  cat "$b/brightness" "$b/max" 2>/dev/null || true
  [ -r "$b/max" ] && [ -w "$b/brightness" ] && cat "$b/max" > "$b/brightness"
done

# 2) Re-run modeset (Ctrl+C to return to shell if it stays open)
modetest -M rockchip -s 191:#0

# 3) If you already have backlight from an EXTERNAL supply but the image stays black —
# prove whether anything is reaching the framebuffer (needs CONFIG_DRM_FBDEV_EMULATION):
cat /sys/class/graphics/fb0/virtual_size /sys/class/graphics/fb0/bits_per_pixel
# dd if=/dev/zero bs=1024 count=1 2>/dev/null | tr '\0' '\377' | dd of=/dev/fb0 conv=notrunc 2>/dev/null
```

**Also check:** regulators via debugfs (`**vcc3v3_lcd0_n`** — see above) and `**dmesg | egrep -i 'backlight|pwm|panel|jd9365|dsi'`** for probe errors. If there is **no** `**/sys/class/backlight/`**** device, userspace cannot turn the LED string on until the DT maps `**LCD_BL_PWM`** / `**backlight`** correctly (`**TASK-118`**).

**Kernel log:** `**pwm-backlight … supply power not found, using dummy regulator`** means the BSP `**pwm-backlight`** node’s `**power-supply`** phandle did not resolve (common after PMIC/rail changes on CM3566). The board DTS should set `**power-supply`** to the real LCD rail (e.g. `**vcc3v3_lcd0_n`**) so enable order matches hardware — rebuild and reflash the DTB. Early `**dw-mipi-dsi-rockchip … -517`** is `**EPROBE_DEFER**` until the panel registers; `**vcc3v3_lcd1_n: disabling**` is often an **unused** second LCD rail releasing, not necessarily the LMT101 path.

Confirm brightness headroom: `**cat /sys/class/backlight/backlight/max`** — if `**max`** is above `**200`**, write `**max`** into `**brightness**` for both `**backlight**` and `**backlight1**`.

### External 9 V backlight supply vs board pins (LMT101-style wiring)

It is **normal** for the **LED string** to be fed from a **bench or on-panel ~9 V supply** (boost / driver), while the **EM3566 carrier** only brings **logic-level control** over the `**MIPI LCD`** connector — e.g. `**LCD_BL_PWM`** (dimming) and `**LCD_PWREN_H`** (panel / rail enable per Boardcon schematic — **cite traced nets**, do not guess polarity).

**Implication:** 9 V present at the LED driver does **not** guarantee light. Many drivers need **enable** and/or a **non-stuck PWM** from the SoM. Linux `**/sys/class/backlight/*`** only works if `**pwm-backlight`** in DT drives `**LCD_BL_PWM`** (`**TASK-118`** / **BLK-008**). If that driver is missing, you may still need a **scope or meter** on `**LCD_BL_PWM`** and `**LCD_PWREN_H`** during `**modetest`** and after writing `**brightness`**.

**Bench sanity (hardware):** 9 V at the driver input (per your assembly), `**VCC3V3_LCD`** / panel digital rails as per schematic, FPC pins seated, and **no** conflict between a “always-on” bench 9 V and an **enable** line that keeps the driver in shutdown.

### 5.2 — On-board: LCD firmware parameters (console Q&A)

Use this after login (typically `**root`** on `**ttyFIQ0`**). Answer each Ask on the serial console with the matching commands; compare to Pass if. Targets: in-tree DT + `**jadard`** patches (`**library/LMT101/LMT101SX006C initial codes.txt`**, `**elevator-hmi-lmt101sx006c-panel.dtsi`**, `**elevator-hmi-boardcon-em3566-v3.dts**`). For modetest, replace connector id `**191**` if `**modetest -M rockchip`** shows another id for **DSI-1** (see **§5.1**).

**A — Ask: Is the JD9365 / `jadard` panel driver enabled in this kernel?**

```sh
zcat /proc/config.gz 2>/dev/null | grep -F DRM_PANEL_JADARD
```

**Pass if:** line shows `**CONFIG_DRM_PANEL_JADARD_JD9365DA_H3=y`** (or `**=m`**).

**B — Ask: Does the MIPI-DSI panel device bind to `jadard` with our device-tree compatibles?**

```sh
ls /sys/bus/mipi-dsi/devices/
for d in /sys/bus/mipi-dsi/devices/*; do echo "=== $d ==="; grep -E 'DRIVER=|OF_COMPATIBLE|MODALIAS' "$d/uevent" 2>/dev/null; done
```

**Pass if:** `**DRIVER=jadard-jd9365da`** (or equivalent); `**OF_COMPATIBLE`** includes `**elevator-hmi,lmt101sx006c`** and/or `**jadard,jd9365da-h3`**.

**C — Ask: Does DRM list the DSI connector as connected with mode 800×1280 at ~70000 kHz?**

```sh
modetest -M rockchip
```

**Pass if:** under **Connectors**, **DSI-1** is **connected**; listed mode is **800×1280** and clock **~70000** kHz (~60 Hz).

**D — Ask: Does forcing that mode succeed?** (use the connector id from **C**, e.g. **191**)

```sh
modetest -M rockchip -s 191:800x1280
```

**Pass if:** output contains **setting mode 800x1280** and names **connectors** + **crtc** with no failure line.

**E — Ask: Does the log show a healthy DSI / JD9365 link (incl. 4 lanes hints)?**

```sh
dmesg | egrep -i 'dsi|mipi|jadard|jd9365|lanes|bandwidth' | tail -n 40
```

**Pass if:** no stuck **probe failed** for `**jadard`**; optional Rockchip line such as **DSI-Link bandwidth** … **4 lanes**.

**F — Ask:** After the successful **modetest** in **D**, is the LCD 3V3 rail enabled in debugfs?

```sh
mount -t debugfs none /sys/kernel/debug 2>/dev/null
cat /sys/kernel/debug/regulator/vcc3v3_lcd0_n/enable 2>/dev/null
```

**Pass if:** `**1`**. If the path is missing, fall back to `**dmesg | grep -i vcc3v3_lcd`**.

**G — Ask: Does the kernel expose sysfs backlight control?**

```sh
ls -la /sys/class/backlight/
for b in /sys/class/backlight/*; do echo "=== $b ==="; cat "$b/max" "$b/brightness" 2>/dev/null; done
```

**Pass if:** at least one `**backlight`** entry; `**max`** present; `**cat max > brightness`** works for a visible dimming test.

**H — Ask: Is PWM backlight not stuck on a dummy supply in `dmesg`?**

```sh
dmesg | grep -Fi pwm-backlight
```

**Pass if:** no lingering *supply power not found, using dummy regulator* after the board DTS maps `**power-supply`** to `**vcc3v3_lcd0_n`** (otherwise **reflash** fixed DTB).

**I — Ask: Is `gt1x` touch not competing for the panel reset GPIO?**

```sh
dmesg | grep -i gt1x
```

**Pass if:** ideally **no** `**gt1x` probe** (DT `**gt1x` disabled** for **TASK-121**). If `**gt1x`** loads, it may conflict with `**jadard`** on **RK_PB6** — confirm DT with `**strings /boot/elevator-hmi-boardcon-em3566-v3.dtb | grep -i gt1x`** or `**dtc -I dtb -O dts /boot/your.dtb`** on a host.

**J — Ask: Did panel / VOP / DRM finish probing (not stuck deferring forever)?**

```sh
dmesg | egrep -i 'jadard|jd9365|mipi_dsi|vop|rockchip.*drm' | tail -n 30
```

**Pass if:** early `**-517`** defer is OK if later logs show bind/probe; **not** an endless **defer** loop.

**K — Ask (optional): Do `/boot` kernel + DTB match the build host deploy tree?**

On the **build host:**

```sh
cd /path/to/elevator-hmi
md5sum build/tmp/deploy/images/elevator-hmi-em3566/Image
md5sum build/tmp/deploy/images/elevator-hmi-em3566/elevator-hmi-boardcon-em3566-v3.dtb
```

On the **board:**

```sh
md5sum /boot/Image
md5sum /boot/elevator-hmi-boardcon-em3566-v3.dtb
```

**Pass if:** both **MD5** pairs match — confirms flashed firmware, not a stale image.

---

**One-shot sweep** (same checks, copy-paste once):

```sh
echo "== A =="; zcat /proc/config.gz 2>/dev/null | grep -F DRM_PANEL_JADARD || true
echo "== B =="; for d in /sys/bus/mipi-dsi/devices/*; do echo "--- $d ---"; cat "$d/uevent" 2>/dev/null; done
echo "== E =="; dmesg | egrep -i 'dsi|mipi|jadard|jd9365|lanes|bandwidth' | tail -n 30
echo "== F =="; mount -t debugfs none /sys/kernel/debug 2>/dev/null; cat /sys/kernel/debug/regulator/vcc3v3_lcd0_n/enable 2>/dev/null || echo "(no node)"
echo "== G =="; for b in /sys/class/backlight/*; do echo "--- $b ---"; cat "$b/max" "$b/brightness" 2>/dev/null; done
echo "== H =="; dmesg | grep -Fi pwm-backlight || true
echo "== I =="; dmesg | grep -i gt1x || echo "(no gt1x lines)"
```

**Reset GPIO polarity (BLK-006):** `**reset-gpios`** **HIGH vs LOW** is **not** in the vendor `**.txt`** — console checks **A–K** cannot validate it. Use **bench** (scope / DMM) on **XRES / TOUCH_RST** vs `**jadard`** reset timing if the screen stays black while **A–K** pass.

---

## 6. Flashing / upgrade tools (no invented offsets)

This checklist does **not** document `**rkdeveloptool` / `upgrade_tool` / RKDevTool** partition offsets or loader addresses — those depend on the exact **loader + GPT + image** bundle and are easy to get wrong without the vendor flow.

**In-repo references (owner reads and follows vendor steps):**

- `[library/EM3566/Linux6.1/Usermanual/EM3566 linux6.1 user manual_V1.0.md](../library/EM3566/Linux6.1/Usermanual/EM3566%20linux6.1%20user%20manual_V1.0.md)` — vendor Linux 6.1 bring-up (includes RKDevTool references).
- `[library/EM3566/Linux6.1/Tools/RKDevTool/RKDevTool_Release/RKDevTool_manual_v1.2_en.md](../library/EM3566/Linux6.1/Tools/RKDevTool/RKDevTool_Release/RKDevTool_manual_v1.2_en.md)` — RKDevTool manual (Windows-centric; still authoritative for many Boardcon flows).
- **meta-rockchip** README (in the `**meta-rockchip`** checkout created by `**kas`**) — `**upgrade_tool` / `.wic`** notes upstream.

**Unknown until bench:** which single command-line invocation your lab standardizes on for flashing the `**.wic`** produced above — record the **working** command in `[diary/PROGRESS.md](../diary/PROGRESS.md)` after the first successful flash.

### Lab-verified notes (2026-04-18)

- `**rkdeveloptool db …loader.bin`** may return *“The device does not support this operation!”* on this kit while the device still enumerates as `**2207:350a*`*. `**wl`** / `**rd`** can still succeed — `**db` is not always required** for `**wl 0` (WIC)**, `**wl 64` (idblock)**, `**wl 0x4000` (uboot)**. Full copy-paste block: `**diary/PROGRESS.md`** (2026-04-18 lab milestone entry).
- **Deploy paths** (after `kas build` from repo root): `**build/tmp/deploy/images/elevator-hmi-em3566/`** — use symlinks `**core-image-minimal-elevator-hmi-em3566.rootfs.wic`**, `**uboot.img`**, `**idblock.img**`, `**loader.bin**` so commands survive image timestamp bumps.
- **U-Boot:** Vendor `**CONFIG_BOOTDELAY=0`** gives no time to interrupt; project fragment adds `**CONFIG_BOOTDELAY=5`** — rebuild `**u-boot-rockchip`** and reflash `**uboot.img`** to apply.
- **Early shell (`init=/bin/sh`):** `tty` may be **not a tty** → interactive `**passwd`** fails silently; use `**chpasswd`** or fix `**/dev`** (single `**devtmpfs`** on `**/dev`**) or `**openssl passwd -6`** + `**/etc/shadow**` edit. Login banner may show `**ttyFIQ0**` while `**console=ttyS2**` is also on cmdline.

---

## 7. After boot

- Confirm root on expected **eMMC** device (`mmcblk0`, …) vs project partition story in `[CLAUDE.md](../CLAUDE.md)` §5.
- `**/data`** partition intent is documented in the `**.wks`** comments and CLAUDE — validate mount behaviour when you enable that partition in the image.

---

## 8. Lab without LCD (EM3566 v3)

Use this when **LMT101** is **not** on `**MIPI LCD`** yet: **Linux on board** still validates **disk layout**, **RAUC**, and **kernel logs** before panel cable-up (**BLK-008** / **TASK-106**).

**Canonical checklist (rationale + project checklist row):** `[CLAUDE.md](../CLAUDE.md)` **§2.1 — Lab without LCD (owner checklist)**.

**Where to paste:** `[diary/PROGRESS.md](../diary/PROGRESS.md)` — optional `**lsblk -f`**, `**pre-LCD baseline`** `**dmesg**`, `**rauc status**`, UART captures, etc. (same targets as **§2.1** in CLAUDE).

1. **Image** — Use a `**develop`** image **at or after TASK-111** (RAUC `**mmcblk0p2` / `p3`** slots per WIC). **Reflash** if the running image predates that merge.
2. **Partition audit** — On target: `**lsblk -f`**, `**cat /proc/partitions`**; paste into `**diary/PROGRESS.md**` (optional **BLK-009** trail — **TASK-111** closed slot-path drift, but partition listing remains useful).
3. **GPT** — If `**dmesg`** reports **backup GPT / header mismatch**: `**sgdisk -e /dev/mmcblk0`** (image includes `**gptfdisk`**), reboot once.
4. **UART baseline** — Save **one** clean capture: U-Boot → Linux → login (file or `**PROGRESS.md`** section) for later diff when **TASK-106** / **BLK-008** run with the panel.
5. **Pre-LCD `dmesg`** — Capture full `**dmesg**` or a filtered view, e.g. `**dmesg | egrep -i 'vcc3v3_lcd0_n|vcca_1v8|backlight|jd9365|dsi|panel'**`. In `**diary/PROGRESS.md**`, label the block `**pre-LCD baseline**` — expect `**-EPROBE_DEFER` / “no panel”** noise with nothing on **MIPI LCD**; compare after cable-up (**BLK-008**).
6. **RAUC** — `**rauc status`**; note **D-Bus** / **systemd** issues for **TASK-116** follow-up if any.
7. **Optional** — `**ip link`**, `**lsusb`** — carrier Ethernet / USB sanity without a display.
8. **U-Boot countdown** — If autoboot still shows `**0`**, rebuild `**u-boot-rockchip`** and reflash `**uboot.img**` so `**CONFIG_BOOTDELAY=5**` applies (see **§6** lab notes above).

**When the LCD arrives:** resume **TASK-106**; repeat `**dmesg`** + photo; **BLK-006** / **BLK-008** only with **cited** schematic or logs — **no invented GPIO** (same closure rule as **§5**).

---

*TASK-114 — §8 “Lab without LCD” added 2026-04-19 (`[DONE]` A1 review); prior §6/§7 history: TASK-107 (2026-04-18).*