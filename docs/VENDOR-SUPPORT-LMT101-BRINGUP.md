# LMT101SX006C — technical support brief (hardware + Linux bring-up)

**Audience:** display vendor (e.g. LCD Mall / AllTouchDisplay) — engineering review  
**Project:** Elevator HMI — custom Linux on **Compulab CM3566 (RK3566)** on **Boardcon EM3566 v3** carrier  
**Panel:** **LMT101SX006C** — **JD9365DA-H3** (Jadard) — **MIPI-DSI** — **800×1280** portrait  
**Document purpose:** single message describing **connections → software → measured results** and **specific questions** we need the vendor to answer.

**Email thread:** use this as the **technical appendix** for our **reply** after LCD Mall sent **`LMT101SX006C initial codes.txt`** — implementation in Linux, bench results, and FAE questions (same narrative as `[VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL.txt](VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL.txt)`).

**Plain-text email (headers + body to paste):** `[VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL.txt](VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL.txt)`

**Related in-repo:**  
`[library/LMT101/](../library/LMT101/)` (FPC map, `**LMT101SX006C initial codes.txt`**) · `[docs/BRINGUP-CHECKLIST.md](BRINGUP-CHECKLIST.md)` · `[docs/LAB-LMT101-TEST-CHEATSHEET.md](LAB-LMT101-TEST-CHEATSHEET.md)` · `[diary/BLOCKERS.md](../diary/BLOCKERS.md)` (**BLK-006** closed, **BLK-014** open)

**Last bench update:** **2026-06-02** — software lab closed; vendor email ready in `[VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL.txt](VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL.txt)`.

---

## 1. Executive summary

We have completed Linux integration using your **authoritative DCS init** (`**LMT101SX006C initial codes.txt`**). On target (**2026-06-02**):

- **MIPI-DSI** **connected**; **468 × 4 Mbps**; mode **800×1280 @ 60.08 Hz**; **VIDEO | VIDEO_BURST** (`mode_flags=0x203`), **four lanes**, **RGB888**.
- `**jadard`** binds; **196** init commands **`rc=0`**; **XRES** on **GPIO0_C6** (**gpio-22**, CON1 pin **11**); boot **`dmesg`:** assert/release @ ~3.5 s; **SLPOUT** / **DISON** sent; **`GET_POWER_MODE(0x0A)=0x18`**.
- **DRM scanout active:** CRTC **112**; **plane 96** (`Smart1-win0`) → **fb 192** **XR24 800×1280** on **video_port1**; sustained **`modetest -F tiles -v`** reports **`freq: 60.08Hz`** (page-flip loop).
- **LCD 3.3 V:** **Plan B** bypass to CON1 **5/6** (~3.3 V); **`vcc3v3_lcd0_n`** enable **1** (**gpio-15**).
- **Remaining symptom:** **external ~9 V backlight** → **backlit black only** — no pattern from tiles test, no change from full **`/dev/fb0`** white fill.

**Conclusion:** Linux/DRM path is **on and scanning**; failure is **after** SoC framebuffer (MIPI HS video / JD9365 source / lane wiring / burst mode vs panel). **Not** absent probe, wrong connector (**191** is correct), or wrong plane (**96**, not **57**).

We request FAE review of: **`0x0A=0x18` meaning**, **HS burst vs command mode**, **post-DISON init**, **scope signatures** when DRM is green but glass is black.

---

## 2. Mechanical / electrical setup

### 2.1 Modules and carrier


| Item                   | Description                                                                                                                                                               |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **SoM**                | Compulab **CM3566** (RK3566, **2 GB** LPDDR4, eMMC)                                                                                                                       |
| **Carrier (bring-up)** | Boardcon **EM3566 v3** — **MIPI LCD** connector **CON1** (4-lane DSI + clock + power + control)                                                                           |
| **Panel**              | **LMT101SX006C** — **40-pin FPC** per vendor pin list (see `[library/LMT101/LMT101-40pin-FPC-input-terminals.md](../library/LMT101/LMT101-40pin-FPC-input-terminals.md)`) |
| **Attach point**       | Panel flex to carrier **CON1** (not LVDS-only mode — **DSI** selected per carrier design).                                                                                |


### 2.2 CON1 signals used for DSI (reference)

Per **Boardcon EM3566 v3** documentation (**§2.8 CON1**), the **MIPI-DSI** signals on CON1 include:

- **CLK:** pins **29–30** (`MIPI_DSI_TX0_CLKP/N`)
- **Data lanes D0…D3:** pins **33–40** (`MIPI_DSI_TX0_D0…D3` P/N pairs)

**Power / control commonly used for the LCD interface:**


| CON1 pin(s) | Signal name (manual) | Role in our bring-up                                                                                                                                          |
| ----------- | -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 5–6         | **VCC3V3_LCD**       | Panel logic **VDDIN** (3.3 V) — maps to panel FPC **VDDIN** in our draft FPC map                                                                              |
| 13          | **LCD_PWREN_H**      | Panel / IO enable (polarity & sequence — **confirm vs your module spec**)                                                                                     |
| 14          | **LCD_BL_PWM**       | Backlight **dimming control** (PWM) into carrier backlight circuit                                                                                            |
| 11          | **TOUCH_RST**        | Touch reset net on carrier — **we do not use GT911 touch** on this adapter; software may repurpose the GPIO net for **panel XRES** during bring-up (see §2.4) |


**eDP pins 17–28** on CON1 must **not** be paralleled to the LMT101 flex in **DSI-only** use (see project FPC map draft).

Full **FPC pin ↔ CON1** table (draft, hardware-owned): `[library/LMT101/EM3566-CON1-to-panel-40pin-mapping.md](../library/LMT101/EM3566-CON1-to-panel-40pin-mapping.md)`.

### 2.3 Backlight (vendor-critical)

Per module design, **LED strings (LEDA / LEDK)** are **not** simple **3.3 V** logic rails — they are typically driven via an **external boost / LED driver** (often **~9 V** class), with **enable** and **PWM** from the carrier.

**Our lab observation:**

- When we **enable our bench / on-assembly backlight power**, the panel shows **backlight glow**.
- **Sysfs** (`**/sys/class/backlight/*`**) may **not** produce a visible dimming change if the LED path is **hard-on** from an external supply or if **PWM** is not in the analogue path that is actually used.

**Vendor ask:** Please confirm the **mandatory** electrical interface for **LEDA/LEDK**, **expected voltage**, and whether **LCD_BL_PWM** must be a certain **frequency/duty** range for the LED driver to pass current to the string. Please confirm whether **LCD_PWREN_H** must be asserted before **DISPLAY_ON** for correct video.

### 2.4 RESET / XRES (vendor-critical)

Vendor init snippet specifies **software reset timing** (assert/deassert delays) but the **physical** **RESET** pin (FPC pin **5** in our draft map) must reach a valid **SoC GPIO** if hardware reset is required.

**Our bring-up situation:**

- Carrier documentation does **not** expose a **dedicated** “LCD_RESX” line next to MIPI in the same table as **TOUCH_RST**; our project documents **BLK-006** (open) for **traced** reset routing.
- **2026-06-02 (corrected):** `**reset-gpios = <&gpio0 RK_PC6 GPIO_ACTIVE_LOW>**` — **CON1 pin 11** / **TOUCH_RST** / **gpio-22**. **`&spi0` disabled**; **`&gt1x` disabled**. Boot log: **`jadard: reset gpio = gpio-22`**, **XRES assert/release**. Earlier mistaken mapping to **RK_PB6** or **RK_PC7** (power-enable) is **withdrawn**.

**Vendor ask:** What is the **absolute requirement** for **XRES** (always vs optional), **active-high vs active-low**, and **maximum** **RC** or **float** allowed on RESET?

---

## 3. Software stack (Linux)

### 3.1 Operating system


| Item                    | Value                                                                                        |
| ----------------------- | -------------------------------------------------------------------------------------------- |
| **Build**               | Yocto **Scarthgap** (project `kas` manifest)                                                 |
| **Image**               | `core-image-minimal` + project layers                                                        |
| **Kernel**              | **linux-rockchip** **6.1.x** (vendor BSP fork, pinned revision in `meta-rockchip` via `kas`) |
| **Device tree machine** | `**elevator-hmi-em3566`** → `**elevator-hmi-boardcon-em3566-v3.dtb**`                        |


### 3.2 Panel driver (kernel)


| Item                         | Value                                                                                 |
| ---------------------------- | ------------------------------------------------------------------------------------- |
| **Driver**                   | `**jadard`** — `panel-jadard-jd9365da-h3` (**JD9365DA-H3**)                           |
| **Kconfig**                  | `CONFIG_DRM_PANEL_JADARD_JD9365DA_H3=y`                                               |
| **Device tree `compatible`** | `**elevator-hmi,lmt101sx006c**` + `**jadard,jd9365da-h3**` (product + binding)        |
| **DSI**                      | **Host controller:** `&dsi0` (RK3566 **DSI0**); **panel child:** `panel@0` on DSI bus |


### 3.3 Device-tree summary (panel node — implemented)

See `**elevator-hmi-lmt101sx006c-panel.dtsi`** (in-tree):


| Property           | Value / note                                                                                                             |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| `**compatible**`   | `"elevator-hmi,lmt101sx006c"`, `"jadard,jd9365da-h3"`                                                                    |
| `**reg**`          | `<0>` (single DSI peripheral)                                                                                            |
| `**dsi-lanes**`    | `**<4>**` — matches vendor `**CMD_DSI_INT0**` write `**{0x80,0x03}**` (**four** lanes)                                   |
| `**dsi-format`**   | `**<0>**` — **Rockchip `panel@0` registration** (paired with `**MIPI_DSI_FMT_RGB888`** in driver descriptor)             |
| `**vdd-supply**`   | `**vcc3v3_lcd0_n**` — panel **VDD** rail in BSP naming                                                                   |
| `**vccio-supply`** | `**vcca_1v8**` — **1.8 V** I/O (fixed regulator on CM3566 bring-up — **no RK809** on this SoM)                           |
| `**backlight`**    | `**&backlight**` — BSP `**pwm-backlight**` node                                                                          |
| `**reset-gpios**`  | `**<&gpio0 RK_PC6 GPIO_ACTIVE_LOW>**` — **CON1 pin 11** / **gpio-22**; **`&spi0` off** (**BLK-006** closed **2026-06-02**) |


**Carrier-specific overlays** in `**elevator-hmi-boardcon-em3566-v3.dts`:**


| Change                                                                 | Reason                                                                                                                                 |
| ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| **Fixed regulators** + `**pmu_io_domains`**                            | CM3566 has **no** **RK809** at BSP I²C address — **io-domains** and **VOP/DSI** supplies use **fixed** rails (**TASK-119 / TASK-120**) |
| `**chosen/bootargs`**                                                  | Root on `**/dev/mmcblk0p2**` (project eMMC layout)                                                                                     |
| `**&gt1x` `status = "disabled"**` · `**&spi0` disabled**`              | Release **GPIO0_C6** for panel XRES; no SPI0_CS0 conflict (**TASK-121** / **2026-06**)                                                  |
| `**&backlight` / `&backlight1`** `**power-supply = <&vcc3v3_lcd0_n>**` | Avoid **dummy** backlight supply after PMIC delete (**TASK-120**); **TASK-118** may further refine **PWM** routing to **CON1 14**      |


### 3.4 Vendor init in kernel (source of truth)


| Item                            | Source                                                                                                                                                                                             |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **DCS register table**          | `**library/LMT101/LMT101SX006C initial codes.txt`** (LCD Mall)                                                                                                                                     |
| **Kernel implementation**       | Patch `**0003-drm-panel-jadard-lmt101sx006c-vendor-init.patch`** — `**lmt101sx006c_init_cmds[]**` through registers up to `**0xE7,0x0C**`; **four-lane** and **RGB888** in `**lmt101sx006c_desc`** |
| **Sleep-out / display-on tail** | Patch `**0004-drm-panel-jadard-lmt101-vendor-enable-seq.patch`** — `**0x11**`, delays, `**0x29**` per vendor tail                                                                                  |
| **Timing**                      | Mode line **800×1280**, **~70 MHz** clock, porches aligned with vendor `**PLL_CLOCK=420`** snippet in your file                                                                                    |


---

## 4. Verification matrix (on-target results)

All commands run on the board (`**root**` shell) unless noted. Results reflect **lab logs captured during bring-up**; use as a **template** for your own retest.

### 4.1 DRM / mode / connector


| Check                    | Command or observation                  | Result                                                                                                    |
| ------------------------ | --------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| **DSI connector status** | `cat /sys/class/drm/card0-DSI-1/status` | `**connected`**                                                                                           |
| **modetest topology**    | `modetest -M rockchip`                  | **Connector DSI-1 id `191`**, **encoder `190`**, **CRTC `112`** — use **connector id `191`** for `**-s**` |
| **Listed mode**          | From modetest **Connectors** block      | **800×1280**, **60.08 Hz**, timings **800 840 860 880** × **1280 1310 1314 1324**, **70000** kHz          |
| **Forced modeset**       | `modetest -M rockchip -s 191:800x1280`  | `**setting mode 800x1280-60.08Hz on connectors 191, crtc 112`**                                           |


### 4.2 DSI host / bandwidth


| Check                  | Command or observation                                  | Result                                                                     |
| ---------------------- | ------------------------------------------------------- | -------------------------------------------------------------------------- |
| **DSI link bandwidth** | `dmesg` filtered for `dw-mipi-dsi-rockchip` / bandwidth | `**final DSI-Link bandwidth: 468 x 4`** (interpreted as **four-lane** DSI) |


### 4.3 Panel driver binding


| Check               | Command or observation                                | Result                                                                                                                  |
| ------------------- | ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| **MIPI-DSI device** | `cat /sys/bus/mipi-dsi/devices/fe060000.dsi.0/uevent` | `**DRIVER=jadard-jd9365da`**, `**OF_COMPATIBLE_0=elevator-hmi,lmt101sx006c**`, `**OF_COMPATIBLE_1=jadard,jd9365da-h3**` |
| **Kernel config**   | `zcat /proc/config.gz | grep DRM_PANEL_JADARD`        | `**CONFIG_DRM_PANEL_JADARD_JD9365DA_H3=y`**                                                                             |


### 4.4 Regulators (LCD rail)


| Check                | Command or observation                                                      | Result                |
| -------------------- | --------------------------------------------------------------------------- | --------------------- |
| **LCD 3.3 V enable** | `mount -t debugfs none /sys/kernel/debug` then `cat …/vcc3v3_lcd0_n/enable` | `**1`** after modeset |


### 4.5 Backlight (sysfs)


| Check           | Command or observation                               | Result                                          |
| --------------- | ---------------------------------------------------- | ----------------------------------------------- |
| **Sysfs nodes** | `ls /sys/class/backlight/`                           | `**backlight`**, `**backlight1**` present       |
| **Scale**       | `**brightness`** / `**max_brightness**` (kernel ABI) | Typically **200 / 200** at maximum in our tests |


**Note:** Linux exposes `**max_brightness`**, not `**max**`. Scripts must read `**max_brightness**`.

### 4.6 Touch controller conflict


| Check    | Command or observation | Result                                            |
| -------- | ---------------------- | ------------------------------------------------- |
| **gt1x** | `dmesg | grep -i gt1x` | **No** probe lines when disabled in DT (intended) |


### 4.7 DRM plane / sustained test pattern (2026-06-02)

| Check | Command / observation | Result |
| ----- | --------------------- | ------ |
| **Plane state** | `cat /sys/kernel/debug/dri/0/state` | **plane[96]** `Smart1-win0`, **crtc=video_port1**, **fb=192** **XR24 800×1280**, **allocated by [fbcon]** |
| **Sustained tiles** | `modetest -M rockchip -s 191@112:#0 -P 96@112:800x1280+0+0 -F tiles -v` | **setting mode 800x1280-60.08Hz**; **`freq: 60.08Hz`** repeating; **no visible image** on glass |
| **Framebuffer fill** | `tr '\000' '\377' </dev/zero \| dd of=/dev/fb0 bs=4096 count=1000` | **No visible change** while plane 96 active |
| **jadard boot trace** | `dmesg \| grep jadard` | **mode_flags=0x203** video+burst; **init 196 cmds rc=0**; **GET_POWER_MODE(0x0A)=0x18** |

**Note:** `**modetest -P 57@112**` fails (**no unused plane**) — primary DSI plane is **96**, not **57**.

### 4.8 Not applicable to this panel (ignore for support)


| Noise in `dmesg`                                                                       | Relevance                                                       |
| -------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| `**rockchip-mipi-csi2`**, `**rkcif_mipi_lvds**`, **“no link between dphy and sensor”** | **Camera / ISP** path on SoC — **not** the **DSI display** path |


---

## 5. Current symptoms (please advise)

### 5.1 Symptom A — **Backlit black** (primary, 2026-06-02)

**Observation:** With **~9 V external backlight** and **§4** all **green** (including **plane 96** scanout @ **60 Hz** and **`0x0A` read**), the **display area remains black** — no tiles, no white fill.

**Hypotheses (software lab closed):** **MIPI HS burst vs panel requirement**, **lane P/N or swap**, **JD9365 source/gamma blocks after video start**, **`0x0A=0x18` = wrong power state**, **FPC / analogue path**. **XRES GPIO mapping** is **validated** in software (**BLK-006** closed); scope on **CON1 pin 11 / FPC pin 5** still recommended.

### 5.2 Symptom B — **SoC backlight sysfs vs bench**

**Observation:** **Sysfs** brightness may not correlate with perceived brightness if **external** backlight feeding is used.

**Hypothesis:** **PWM** (**CON1 14**) may not be in circuit that actually dims the LED current, or **enable** sequence differs from your reference schematic.

### 5.3 Specific questions to vendor

1. **DCS 0x0A:** After **DISON**, we read **`GET_POWER_MODE(0x0A)=0x18`**. What state does **0x18** indicate? Should we expect a different value when video should be visible?
2. **MIPI video mode:** We use **VIDEO | VIDEO_BURST** (`**mode_flags=0x203**`), **4 lanes**, **RGB888**. Is **burst HS** correct for **LMT101SX006C**, or must we use **non-burst** / **command mode**?
3. **Post-init:** After your table + **0x11** / **0x29**, are **page-select / gamma / source-on** registers still required before HS pixel stream?
4. **RESET:** We pulse **XRES** on **GPIO0_C6** (CON1 **11**, active-low) per your **Q1** timing. Confirm **FPC pin 5** mandatory and polarity.
5. **Backlight vs picture:** Can **MIPI picture** appear with **external 9 V** on LED string and **no** `LCD_BL_PWM`, or does LED **EN** gate the LCD source?
6. **Scope:** With **468 Mbps × 4** and **60 Hz** plane scanout but **black glass**, what should we see on **CLK** and **D0** during active video?

---

## 6. Attachments we can provide on request

- Redacted `**dmesg`** excerpt (DSI / DRM / regulator only).
- `**modetest -M rockchip**` connector section (text).
- Git-pinned **patch list** and **device tree** files (for NDA review).
- Photo of **FPC** / **CON1** connection (if allowed).

---

## 7. Contact block (fill locally)


| Field              | Value                                             |
| ------------------ | ------------------------------------------------- |
| **Company**        | *(fill)*                                          |
| **Project ref**    | Elevator HMI — LMT101SX006C                       |
| **Hardware**       | CM3566 + EM3566 v3 + LMT101SX006C                 |
| **Software**       | Yocto — linux-rockchip 6.1 — `jadard` JD9365DA-H3 |
| **Email / ticket** | *(fill)*                                          |


---

*Internal cross-ref: **BLK-006** closed (XRES **PC6**), **BLK-014** (backlit black / software lab closed), **BLK-012** closed, **TASK-118** (PWM deferred), **TASK-125** / patches **0008–0010**, **TASK-106** `[TESTING]`.*