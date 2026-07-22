# BLOCKERS.md — Active Blockers and Questions

**Owner:** A1 (Claude Code)  
**Format:** Open blockers at top. Closed blockers moved to archive at bottom.

---

## Open Blockers

### BLK-014 — LMT101 backlit black with full DRM scanout (software lab closed)
**Opened:** 2026-06-02  
**Severity:** **HIGH** — blocks Phase 1 display gate; no further userspace tests change diagnosis  
**Owner:** A1 / vendor FAE  

**2026-06-13 — VENDOR-CLOCK-MATCH image built (TASK-140 / patch 0019).** Workspace synced to vendor truths: lane rate forced to **420 Mbps** (drop `VIDEO_BURST`, vendor PLL_CLOCK=420 / 5 Jun "rate mismatch") and XRES low pulse **20 ms** (vendor Q1). Init table / porches / FAE page-4 clock / tail / DIAG15 already vendor-matched. WIC `vendor-clock-match` SHA `7dbf72d902a580c05db0d236665b18eaf227309395104257efa075c3ea1217a7`, git `d9565d6`+0019. Bench pending: flash, confirm `420 x 4 Mbps`, BL **9.6 V**, VDDIN/lane scope. Vendor 13 Jun Q2 says LP-at-0x11 not gating → continuous-HS-before-init deferred to scope.


**Symptom:** External **~9 V** backlight illuminates the panel; **no visible pixels** (no pattern from `modetest` tiles @ **60 Hz** page-flip, no change from full **`/dev/fb0`** white fill).

**Software evidence (2026-06-02 bench, TASK-133-class image + jadard patches through **0010**):**

| Layer | Result |
|--------|--------|
| Rails | `vcc3v3_lcd0_n` enable **1**; **gpio-15** hi; **Plan B** ~3.3 V on CON1 **5/6** |
| Reset | **`reset-gpios`** **GPIO0_C6** (**gpio-22**); **`jadard`:** XRES assert/release @ ~3.5 s boot |
| Panel init | **196** cmds **`rc=0`**; SLPOUT/DISON; **`GET_POWER_MODE(0x0A)=0x18`** |
| DSI | **468x4 Mbps**; **`mode_flags=0x203`** (video+burst, 4 lane, RGB888) |
| DRM | **CRTC 112** **800x1280@60**; **plane 96** (**Smart1-win0**) **`fb=192`** **XR24** on **video_port1** |
| Userspace | **`modetest -s 191@112:#0 -P 96@112:800x1280+0+0 -F tiles -v`** -> sustained **`freq: 60.08Hz`**; still no image |

**Conclusion:** Linux/DRM path is **active and scanning**; failure is **downstream of framebuffer** — **MIPI HS video to JD9365 / panel source**, **lane wiring**, or **vendor init vs video mode**. **Not** missing `modetest`, wrong connector id (**191**), or absent plane (**96** is correct; **57** was wrong).

#### ~~Booster-Bit Diagnosis~~ — **SUPERSEDED 2026-06-13 (vendor LCD Mall reply)**

**Was (2026-06-10):** D7=0 in `0x0A` interpreted as dead charge pump; healthy assumed `0x9C`.

**Vendor correction (13 Jun 2026):** This module uses **integrated boost** (JD5001 via `0x11`). **`0x18` (D7=0) is HEALTHY** on their fixture. **`0x9C` indicates external boost fault**, not health. Our reads (`0x18`/`0x1c`, D7=0) match vendor healthy digital state. Black glass is **not** explained by “booster bit never set.”

**Full record:** `diary/STATE-2026-06-13-vendor-reply.md`

#### BUILD B Result (2026-06-10 bench) — **reconciled 2026-06-13**

**Board flashed:** `core-image-minimal-elevator-hmi-em3566.rootfs-20260610170030.wic`, SHA-256 `dd5be78d...`, git `e19ae16` — BUILD B (FAE page-4 clock fix, patches 0011+0013, 0012 commented).

**`GET_POWER_MODE(0x0A) pre-TE = 0x1c`** — vs BIST v1 (`0x18`), **only bit 2 (display-on) differs**; D7 booster bit = 0 in both. **Vendor 2026-06-13:** D7=0 is **healthy** for integrated boost (`0x18` reference). The `0x18`→`0x1c` shift is confounded with read timing (~14 ms → ~70 ms post-DISON), not evidence of pump start/failure.

| Bit | Mask | BIST v1 (0x18) | BUILD B (0x1c) | Meaning |
|-----|------|----------------|----------------|---------|
| 7 | 0x80 | 0 | 0 | Booster D7 — **healthy per vendor** (integrated boost) |
| 4 | 0x10 | 1 | 1 | Sleep-out executed ✓ |
| 3 | 0x08 | 1 | 1 | Normal mode ✓ |
| 2 | 0x04 | 0 | 1 | Display-on — read-timing / DISON latch |

**Clock fix effect:** Page-4 clock registers allowed reliable DCS delivery; DISON may latch earlier in the read window. **Not** a charge-pump diagnosis.

**VDDIN static DMM 3.3 V:** Cannot rule out short transients; owner skipped K1/K2 (2026-06-13). Remaining supply check: scope VDDIN @ SLPOUT + **FPC pin-3 DMM** (H1b).

#### ~~New Init-Table Observation (E3)~~ — **CLOSED**

Vendor lit the same `LMT101SX006C initial codes.txt` without `E3` in the production path. H4a bench proved `E3,01` after BIST unlock causes soft-reset (`0x0A=0x08`), not production booster enable. **Do not add E3 to init.**

**468 vs 420 Mbps explained:** `dw-mipi-dsi-rockchip` applies a deliberate 10/9 bandwidth margin over pixel-derived rate (70MHz x 24/4 x 10/9 ~ 466.7 -> 468 with PLL granularity). It is the host's intentional burst-mode margin, not a timing bug. Mainline precedent (Ondrej Jirman, 2024): non-burst modes should run hsclock = pclk x bpp/lanes exactly — i.e., dropping VIDEO_BURST is the clean path to exactly 420 Mbps if needed later.

**Spec facts verified (LMT101SX006C spec PDF pages 6/7/10/11/13/14):**

- FPC: pin 5 = RESET; pins 2/3 = VDDIN 3.3V; MIPI D0(8/9), D1(11/12), CLK(14/15), D2(17/18), D3(20/21). Project wiring docs match.
- Backlight: VF typ 9.0V, IF 180mA, 27 LEDs — the external 9V bench supply is CORRECT. Closed permanently.
- Reset timing: spec minimums tRESETL 10us / tRESETH 5ms / tSLPOUT 120ms — our 20ms/120ms over-satisfies. Closed.
- Expected JD9365 ID bytes for read-back: **93 65 04** (DCS 0x04).

#### DIAG15 Result (patch 0015, 2026-06-10 bench) — **reconciled 2026-06-13**

**Board:** `rootfs-diag15.wic`, SHA `22a40d74…` / reverted WIC `e215a94a…`, git `5e181277…`.

```
GET_POWER_MODE(0x0A) pre-TE = 0x1c          (vendor-healthy: D7=0 + display-on)
DIAG15 ID = 0x93 0x00 0x00                  (JD9365D confirmed)
DIAG15 self-diag = 0xC0                     (registers loaded + IC logic OK — vendor confirms healthy)
DIAG15 scanline = 0x00                      (timing controller not running — analog/video path suspect)
```

**DIAG15 conclusions (updated):**
- `0x0F = 0xC0` + `0x0A = 0x1c` match **vendor healthy digital state** (vendor check 3 **CLOSED**)
- `0x0F` does not prove TFT/analog path — black glass + `0x45=0x00` remain open
- H4b **eliminated** (registers loaded); H6 **not eliminated** (digital OK ≠ sample OK)

#### H4a Test Result (patch 0016, 2026-06-10 bench)

**Board:** `rootfs-h4a.wic`, SHA `0b486efe…`, git `d9efdda`.

Sequence sent after DISON: `F0,55 / F1,AA / E0,01 / E3,01 / E0,00`, then 50ms, then `0x0A` read:

```
GET_POWER_MODE(0x0A) pre-TE = 0x08
```

**`0x08` decoded:**
- Bit 7 (0x80): booster = 0 — **still OFF**
- Bit 4 (0x10): sleep-out = **0 — CLEARED** (was 1 in all previous builds)
- Bit 3 (0x08): normal mode = 1 (hardware default, always set at power-on)
- Bit 2 (0x04): display-on = **0 — CLEARED** (was 1 in BUILD B / DIAG15)

**Interpretation:** `E3,01` after `F0/F1` BIST unlock **triggered a panel internal soft-reset** (display state returned to power-on default: only normal-mode bit survives). The `F0/F1` + `E3` sequence is a BIST preparation command — it reinitializes the display engine for self-test mode, wiping sleep-out and DISON flags as a side effect. The booster does not start in BIST mode either because VDDIN cannot support the inrush (H1), or because BIST mode also has a separate booster path than production display.

**H4a ELIMINATED as formulated.** Sending `E3,01` (page-1 BIST enable) in the middle of a production init sequence cannot start the production booster — it disrupts the panel state instead. If a missing register is the cause (H4b variant), it is a DIFFERENT register than `E3`, and the vendor FAE must identify it.

#### Ranked Hypotheses (updated 2026-06-13 — software EXHAUSTED)

| Priority | ID | Hypothesis | Status | Kill test |
|----------|-----|------------|--------|-----------|
| **PRIME (hw)** | **H5** | Lanes 1–3 / CLK wiring — lane 0 only proven | **LIVE** | Scope CLK + D1–D3 @ `modetest` |
| **HIGH (hw)** | **H1b** | FPC pin-3 voltage trap | **LIVE** | DMM pin 3 (first, 30 s) |
| **scope-gated / LOW** | **H-HSclk** | LP during commands | **scope-gated** | CLK @ SLPOUT |
| **parallel** | **H6** | Damaged sample | **LIVE** | Spare swap |
| ~~H-pkt~~ | Generic vs DCS framing | **DEAD** | TASK-139 identical reads |
| ~~H7~~ / ~~Booster~~ / ~~H-init~~ | — | **DEAD** | — |

**Software investigation: EXHAUSTED** — **19/19** firmware/register vendor lines match (`diary/STATE-2026-06-13-vendor-reply.md` FINAL VENDOR-MATCH RECORD). **Three mismatches:** #14 PLL 468 vs 420, #24 HS@0x11, #25 BL 9.0 vs 9.6 V. **TASK-140** `[BLOCKED]` closes both clock lines. Bench: 9.6 V BL, VDDIN 75 mA/rail scope, CLK+D1–D3 scope (PRIME), pin-3 DMM.

**0x18 vs 0x1c: CLOSED** — `0x1c` = display-on latched + vendor-healthy D7=0; `0x18` was early-read artifact. Do not revisit.

**Gate rule:** No kernel patches until new evidence. Hardware track only.

#### Decision matrix (post-vendor 2026-06-13)

| Evidence | Verdict | Next |
|----------|---------|------|
| `0x0A`/`0x0F` healthy (have) | Digital OK | **Software exhausted** — hardware only |
| DCS-INIT = generic reads | **H-pkt DEAD** | Scope lanes + pin-3 |
| FPC pin 3 ≠ 3.3 V | **H1b CONFIRMED** | Fix routing |
| D1–D3 wrong / no HS bursts | **H5 CONFIRMED** | Wiring / FPC |
| Power + lanes OK, still black | H6 or vendor | Spare panel |
| FPC pin 3 ≠ 3.3 V | **H1b CONFIRMED** | Fix routing — stop |
| D1–D3 wrong polarity / no HS bursts | **H5 CONFIRMED** | Wiring / FPC |
| Pin-3 OK + lanes OK + CLK LP @ SLPOUT only | H-HSclk scope data only | Revisit `HSCLK` patch only if lanes/power clean |
| Spare panel works | **H6** | Replace sample |

**Board currently runs:** DIAG15 reverted build — `core-image-minimal-elevator-hmi-em3566.rootfs-diag15.wic`, SHA-256 `e215a94a…`, git `5e1812775f2e9c5e4d9cbef4ab88f954b4f3136f`. **Result: `0x1c` + `0x0F=0xC0`** — vendor-healthy digital baseline. BIST (0012) and H4a (0016) **commented out** — vendor init + Test 1 clock + DIAG15 only. See `diary/STATE-2026-06-13-vendor-reply.md`.

#### Four Explicitly Superseded Conclusions

1. ~~**H4a** (`E3,01` page-1 enables booster)~~ — **SUPERSEDED 2026-06-10:** On-target test (`0x0A=0x08`) proved `E3,01` causes panel soft-reset, not booster enable. Panel state regressed to power-on default.
2. ~~**H4b** (other init register missing)~~ — **SUPERSEDED 2026-06-10:** `0x0F=0xC0` from DIAG15 confirms all registers loaded correctly and IC logic functional. Digital self-test passes.
3. ~~**H6** (defective panel sample)~~ — **SUPERSEDED 2026-06-10:** `0x0F=0xC0` + `0x04=0x93` confirms JD9365D IC present and functional. Not a dead panel.
4. ~~**A2 "skip BUILD B" recommendation**~~ — **SUPERSEDED 2026-06-10:** BUILD B clock fix moved `0x0A` from `0x18` to `0x1c` (DISON latch); confounded with read timing.
5. ~~**Booster D7=0 = dead pump**~~ — **SUPERSEDED 2026-06-13:** Vendor confirms `0x18` healthy for integrated boost; `0x9C` = fault.
6. ~~**H6 eliminated (0x0F=0xC0)**~~ — **SUPERSEDED 2026-06-13:** Digital OK ≠ analog/TFT OK; H6 back on table.

#### Patch 0015 — DIAG15 DCS readback (active diagnostic)

Post-DISON reads: `0x04` (ID), `0x0F` (self-diag), `0x45` (scanline). Sentinel: `jadard: DIAG15`.

**On-target (vendor-reconciled):** `0x93` / `0xC0` / `0x00` scanline — digital healthy; black glass. **Software exhausted (2026-06-13).** Hardware: **pin-3 DMM → lane scope (PRIME)**.

---


## Closed Blockers

### BLK-006 — JD9365 / LMT101 panel reset (XRES) GPIO mapping
**Opened:** 2026-04-15 — **Closed:** 2026-06-02  
**Severity was:** HIGH  
**Resolution:**  
**Wrong GPIO corrected:** `reset-gpios` was briefly on **GPIO0_C7** (**CON1 pin 13** / `LCD_PWREN_H`) — not the XRES net. **Product DTS** now uses **`GPIO0_C6`** (**CON1 pin 11** / `TOUCH_RST`), **`GPIO_ACTIVE_LOW`**, with **`&spi0` disabled** and **`&gt1x` disabled**. **2026-06-02 bench:** `dmesg` shows **`jadard: reset gpio = gpio-22`**, **XRES assert/release** at boot; **gpio-22** idle **`out hi`**. Software reset path **validated**. **Residual:** glass still **backlit black** with full DRM scanout — tracked under **BLK-014** (not XRES mapping). Owner should still confirm **FPC pin 5 ↔ CON1 pin 11** with scope at **~3.5 s** on cold boot.

---

### BLK-013 — VCC3V3_LCD on EM3566 v3 (`vcc3v3_lcd0_n` / load switch)
**Opened:** 2026-05-18 — **Closed:** 2026-05-21  
**Severity was:** HIGH  

> **SUPERSEDED — 2026-07-22 (owner confirmation):** the "defective load switch"
> diagnosis below was made while the DT drove a **wrong enable pin with inverted
> polarity**. TASK-132 (commit `287374c`) bench-traced the real enable chain —
> PWM0_M0 → R457 → Q18 (NPN) → Q17 (P-FET) → correct enable is **GPIO0_B7,
> ACTIVE-HIGH** — and the current DTS uses it (`enable-active-high`,
> `regulator-always-on`). With the corrected config the switch **works**: 3.3 V
> present at CON1 pins 5/6 through the stock switch path. The Plan B bypass
> jumper has been **removed**; all 2026-07-22 tests (incl. the BIST runs on both
> panels) ran on the proper switch path. The resolution text below is retained
> as history only — do not cite it as current hardware state.

**Resolution (historical, superseded — see note above):**  
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
