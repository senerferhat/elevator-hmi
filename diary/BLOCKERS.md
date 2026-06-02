# BLOCKERS.md — Active Blockers and Questions

**Owner:** A1 (Claude Code)  
**Format:** Open blockers at top. Closed blockers moved to archive at bottom.

---

## Open Blockers

### BLK-006 — JD9365 / LMT101 panel reset (XRES) — wrong GPIO; GPIO contention on RK_PC7
**Opened:** 2026-04-15 — **Reopened:** 2026-06-02 (TASK-134 audit)  
**Severity:** **HIGH** — panel reset cannot work; GPIO double-claim blocks display init  
**Owner:** A1  

#### Root-Cause Analysis (TASK-134 — 2026-06-02)

**Two distinct faults** identified by cross-referencing the EM3566 v3 carrier schematic, SoM connector pinout, BSP DTS, and the deployed DTB:

**Fault 1 — `reset-gpios` is on the wrong pad (RK_PC7 ≠ TOUCH_RST):**
The panel DTSI (`elevator-hmi-lmt101sx006c-panel.dtsi`) previously mapped `reset-gpios = <&gpio0 RK_PC7 GPIO_ACTIVE_LOW>` (GPIO0_C7). However, per the hardware manual and schematic PDF (owner-locked):

| CON1 pin | Signal name    | SoM pin | SoC GPIO    | Mux function     |
|----------|---------------|---------|-------------|------------------|
| **11**   | **TOUCH_RST** | 131     | **GPIO0_C6** | SPI0_CS0_M0      |
| **12**   | **TOUCH_INT** | 132     | **GPIO0_C5** | SPI0_MISO_M0     |
| **13**   | **LCD_PWREN_H** | 139   | **GPIO0_C7** | *(GPIO-only)*    |

`RK_PC7` (**CON1 pin 13**) is **`LCD_PWREN_H`** — the LCD power-enable signal, **not** the touch/panel reset. The **physical XRES trace** runs to **CON1 pin 11** = **`GPIO0_C6`**. The `jadard` driver was toggling the wrong pin.

**Fault 2 — GPIO0_C7 double-claim (vcc3v3_lcd0_n vs reset-gpios):**
Both nodes claimed `GPIO0_C7`. Restoring the reset GPIO to `GPIO0_C6` eliminates this contention.

#### Summary — 3-Column Net Map (deployed DTB vs hardware)

| Signal / CON1 pin | Schematic GPIO (ground truth) | DTB GPIO (actual) | Status |
|---|---|---|---|
| **TOUCH_RST** (pin 11) | **GPIO0_C6** (SPI0_CS0_M0) | `reset-gpios` in panel@0 | ✅ Correctly assigned (RK_PC6 / gpio-22) |
| **TOUCH_INT** (pin 12) | **GPIO0_C5** (SPI0_MISO_M0) | *Not assigned* | — (unused; sits on C5 / gpio-21) |
| **LCD_PWREN_H** (pin 13) | **GPIO0_C7** | *Not assigned* | — (unclaimed) |
| **LCD_BL_PWM** (pin 14) | **GPIO0_B7** (PWM0_M0) | `vcc3v3_lcd0_n` gpio | ⚠️ Overridden from BSP |
| **VCC3V3_LCD** (pins 5-6) | via load switch + `GPIO0_C7` | `vcc3v3_lcd0_n` → RK_PB7 | ⚠️ BSP default ≠ board override |
| **gt1x rst** (BSP I2C2) | **GPIO0_B6** (SPI0_MOSI_M0) | `goodix,rst-gpio` (disabled) | ✅ Disabled, no conflict |

#### IO-Domain Voltage

GPIO0 bank operates at **3.3 V** (PMU IO domains confirmed in deployed DTB). No voltage mismatch.

#### Required Fix (Completed)

1. **Change `reset-gpios`** in `elevator-hmi-lmt101sx006c-panel.dtsi` from `<&gpio0 RK_PC7 …>` back to `<&gpio0 RK_PC6 GPIO_ACTIVE_LOW>`.
2. **Disable `spi0`** in board DTS to avoid SPI0_CS0_M0 drive conflict on `GPIO0_C6`.
3. **Verify** no other node claims `GPIO0_C6` in the active tree.

**Resolution criteria:** `reset-gpios` on verified **GPIO0_C6** (`TOUCH_RST`, CON1 pin 11), `spi0` disabled, bench validation of timed reset pulse on oscilloscope.

---

## Closed Blockers

### BLK-013 — VCC3V3_LCD on EM3566 v3 (`vcc3v3_lcd0_n` / load switch)
**Opened:** 2026-05-18 — **Closed:** 2026-05-21  
**Severity was:** HIGH  
**Resolution:**  
**Bench — carrier load switch defective (hardware fault):** With **`TASK-132`** + **`TASK-133`** in tree, **CON1 pin 13** (`LCD_PWREN_H`, **`GPIO0_C7`**) was **~0 V** when the rail should be **ON** — software polarity is **validated correct**. **`VCC3V3_LCD`** (**pins 5/6**) did **not** reach **~3.3 V** (observed **~0.8 V** on this prototype reference carrier). Responsibility is isolated to **non-functional / defective analogue switch path on the carrier board**, not DTS or regulator glue in Yocto (stop Phase 1 software iteration on rails).

**Permanent hardware mitigation —** jumper a clean **3.3 V** (`VCC3V3_SYS`, input side of the defective switch) to **CON1 pins 5/6** (`VCC3V3_LCD`). Standard Phase 0/1 bring-up when a **prototype carrier** load switch fails. **Rail power-management** (`vcc3v3_lcd0_n`-mediated sleep / cut-off) **deferred to production carrier** — panel stays powered whenever board 3.3 V is present; **TASK-133** DTS + TASK-132 polarity remain authoritative for reproducible builds and future boards. Caveats (**A1 2026-05-21**): no software power-down via that rail on reference hardware; ensure bypass wire gauge and rail capacity for panel **inrush** (usually acceptable from main 3.3 V).

**Residual software bring-up:** With **TASK-121** **`reset-gpios`** on **CON1 pin 11** / **`RK_PB6`**, **`jadard`** owns a timed reset sequence — if the panel still **black** once **~3.3 V is confirmed at 5–6**, treat as **DSI / lane config / JD9365 init table** (**TASK-125** / **`jadard`**), not rail or trivial reset GPIO mapping.

---

### BLK-012 — Black panel while DRM / DSI / `jadard` / modeset are healthy
**Opened:** 2026-05-07 — **Closed:** 2026-05-11  
**Severity was:** HIGH  
**Resolution:**  
Bench confirmed **CON1 pins 5/6 (`VCC3V3_LCD`) stayed at ~0 V** with the adapter ruled out. Initially diagnosed as a polarity inversion vs P-FET (**TASK-129**). **TASK-130** showed the EM3566 v3 carrier load switch was not behaving as controlled by **`vcc3v3_lcd0_n`** alone. Resolution path finalized in **BLK-013** (**closed 2026-05-21**): **Plan B permanent 3.3 V bypass** to CON1 **5/6** for Phase 0/1; production carrier for proper rail sequencing.

---

### BLK-011 — LMT101SX006C JD9365D DCS init sequence required from LCD Mall
**Opened:** 2026-05-08 — **Closed:** 2026-05-09  
**Severity was:** HIGH  
**Resolution:**  
LCD Mall supplied the authoritative register table as **`library/LMT101/LMT101SX006C initial codes.txt`**. **TASK-125** ports it to **`jadard`** via **`0003-drm-panel-jadard-lmt101sx006c-vendor-init.patch`**: **`lmt101sx006c_init_cmds[]`** (**196** two-byte writes through **`0xE7,0x0C`**, excluding **`0x11` / `0x29`** vendor delays — handled by **`jadard_panel_enable()`**). Descriptor **`lmt101sx006c_desc`** uses vendor DPI timings (**~70 MHz** mode) + **`.lanes = 4`** matching **`CMD_DSI_INT0 {0x80,0x03}`** (**bits[1:0]** = **11**). DTS **`elevator-hmi-lmt101sx006c-panel.dtsi`**: **`dsi-lanes = <4>`**. **TASK-124**’s **`{0x80, 0x11}`** mistakenly selected **two** lanes via **CMD_DSI_INT0** bits **`01`**. On-target validation remains **TASK-106**.  

---

### BLK-010 — Jadard panel driver fails to probe (no dmesg output)
**Opened:** 2026-05-06 — **Closed:** 2026-05-06  
**Severity was:** HIGH  
**Resolution:**  
On-target bring-up (**`elevator-hmi-em3566`**): **DSI-1** connected, **`modetest -M rockchip -s 191:#0`** achieves **800×1280@~60 Hz** on **CRTC 112**; DRM/panel path operational. Earlier failure mode addressed by **`reg`**, **`dsi-lanes`**, **`dsi-format`** on **`panel@0`** (see **`diary/PROGRESS.md`** 2026-05-05 entries), not a silent `jadard` match bug.  
**Follow-up (not this blocker):** **pwm-backlight** **`power-supply`** / **TASK-118** (**LCD_BL_PWM**), visible backlight vs external 9 V LED driver — tracked as display polish, not “no panel probe”.

---

### BLK-008 — DTS phandle validation required at bench (vcc3v3_lcd0_n / vcca_1v8 / backlight)
**Opened:** 2026-04-16 — **Closed:** 2026-05-06
**Severity was:** MEDIUM
**Resolution:**
Verified via `strings` on the built DTB that fixed regulators and phandles match the DSI host and panel nodes. **2026-05-06 on-target:** **`vcc3v3_lcd0_n/enable`** **1** after modeset; **DSI** **`800×1280`** on connector **191**. **`pwm-backlight`** dummy-regulator warnings addressed in tree (**`power-supply`** on **`&backlight`** / **`&backlight1`** — reflash to confirm **`dmesg`**). Full **LCD_BL_PWM** map remains **TASK-118**.

---

### BLK-009 — RAUC system.conf slot device numbers vs WIC GPT layout
**Opened:** 2026-04-18 — **Closed:** 2026-04-18  
**Severity was:** MEDIUM  
**Resolution:**  
`system.conf` had **`mmcblk0p4` / `p5`** from the legacy **6-partition** story. Authoritative **`elevator-hmi-emmc.wks.in`** defines **four** GPT entries in order: **boot `p1`**, **rootfs_a `p2`**, **rootfs_b `p3`**, **data `p4`**. **TASK-111** (A2) updated **`meta-hmi-platform/recipes-images/files/system.conf`** to **`p2` / `p3`** for RAUC A/B slots and documented the mapping in-recipe. **`kas shell … -c "bitbake -p"`** passes.  
**Follow-up (not a blocker):** paste target **`lsblk -f`** into **`diary/PROGRESS.md`** when convenient — if numbering ever diverges from WIC (unlikely on this image), reopen with evidence.

---

### BLK-007 — Ubuntu 24.04 (Noble): `libegl1-mesa` missing from apt (TASK-002 host script)
**Opened:** 2026-04-15 — **Closed:** 2026-04-15  
**Severity was:** LOW (host setup friction, not product silicon)  
**Resolution:**  
On **Noble**, **`libegl1-mesa`** was removed from the archive in favour of the GLVND split (**`libegl1`** + **`libegl-mesa0`**). **`scripts/setup-build-host.sh`** now selects EGL packages by **`VERSION_ID`** (**22.04:** **`libegl1-mesa`**; **24.04:** **`libegl1`** + **`libegl-mesa0`**). **`mesa-common-dev`** unchanged.  
**Tracked in:** `scripts/setup-build-host.sh`, `diary/PROGRESS.md` session notes.

---

### BLK-005 — OmniVision OV13850 datasheet failed PDF-to-Markdown conversion
**Opened:** 2026-04-15 — **Closed:** 2026-04-15  
**Severity was:** LOW  
**Resolution:**  
**Closed — not in project scope.** OV13850 is a dev-kit camera sensor, not used in the elevator HMI BOM or software. No `.md` conversion required unless a future task explicitly needs camera bring-up. The PDF remains in `library/` for reference; OCR or a text-layer vendor PDF is optional follow-up outside current phases.

---

### BLK-001 — R-01: CM3566 minimum operating temperature (vendor response)
**Opened:** 2026-04-15 — **Closed:** 2026-04-15  
**Resolution:**  
Vendor / documentation confirms the CM3566 **can run at −20°C** (reliability test: **4 hours at −20°C ±2°C** passed). **However**, official datasheet limits remain: **recommended operating 0°C–70°C**, **storage −40°C–85°C**. Continuous operation at −20°C is **outside** the stated *recommended* ambient range even though a low-temperature test passed.  
**Project stance:** Treat −20°C as **supported by vendor test evidence** with **residual risk** vs written “recommended” spec — acceptable for Phase 0/1 planning **if** project owner formally accepts this gap (warranty, field profile, or future industrial SKU still optional follow-ups).  
**Tracked in:** `CLAUDE.md` §6 (R-01).

---

### BLK-002 — R-02: MIPI-DSI vs LVDS (hardware manual clarification)
**Opened:** 2026-04-15 — **Closed:** 2026-04-15 (addendum **2026-04-16**: EM3566 v3)  
**Resolution:**  
The CM3566 **SoM does not expose a display FPC** on the module; the connector lives on the **carrier**. Per CM3566 hardware manual, **display data pins 25–34 are multiplexed**: each lane is named **both** `MIPI_DSI_TX0_*` **and** `LVDS_TX0_*` — RK3566 outputs **either** protocol depending on **software and carrier** design, not “MIPI-only” at the SoM ball map.  
**Reference carrier — Boardcon EM3566 v3:** Block diagram / layout (sources in `library/EM3566/`) describe this board as the **CM3566 development kit**. It exposes **HDMI**, **LVDS out** (optional), **MIPI LCD**, **eDP**, BT656, etc. For HMI bring-up: **yes, there is a dedicated `MIPI LCD` connector** — physically intended for **MIPI-DSI** panels. The same muxed **LVDS/MIPI TX** bus from the SoM is **routed both** to that **MIPI LCD** connector **and** to the **LVDS OUT** interface (optional population); therefore the connector is correct for LMT101 **provided** software + hardware mode select **MIPI-DSI** on the SoM mux (DT / strap per Rockchip reference).  
**Project stance:** Use **EM3566 v3 `MIPI LCD`** for bench validation of LMT101; treat **custom production carrier** as a separate schematic review. Debian “LVDS LCD” wording remains explainable as mux + optional LVDS header, not a denial of MIPI.  
**Follow-up (not a blocker):** production carrier schematic + population options; dev kit is not the shipping elevator PCB.  
**Tracked in:** `CLAUDE.md` §1 identity, §6 (R-02).

---

### BLK-003 — Backlight boost IC selection (TPS61187 / RT4813 / MP3309)
**Opened:** 2026-04-15 — **Closed:** 2026-04-15  
**Resolution:**  
**Deferred by product decision:** panel/backlight path is fixed; **constant backlight feed** is acceptable for now — **no boost IC part pick** required for Phase 0/1 gate. Re-open a hardware task when dimming, efficiency, or LMT101 electrical spec demands a dedicated boost design.  
**Tracked in:** `CLAUDE.md` §2 checklist.

---

### BLK-004 — Protocol interface (RS-485 vs RS-485 + CAN-FD)
**Opened:** 2026-04-15 — **Closed:** 2026-04-15 (addendum **2026-04-16**: UART bring-up)  
**Resolution:**  
**Deferred by product decision:** **do not plan elevator fieldbus PHY** (RS-485 / CAN-FD / MCP2518FD) for now. PAL / controller interface remains **abstracted in software**; concrete PHY and connector strategy **TBD** when the product unblocks communications.  
**Addendum — interim link to SoM (Phase 0/1):** use **UART serial console** on the reference board (host ↔ EM3566 v3 debug/UART) to monitor **boot, loaded image behaviour, RAUC, and logs** — **not** a replacement for PAL’s future controller protocol, but the agreed **lab/diagnostic** channel until fieldbus is chosen.  
**Tracked in:** `CLAUDE.md` §1 identity table, §2 checklist, §8 PAL.
