# BLOCKERS.md — Active Blockers and Questions

**Owner:** A1 (Claude Code)  
**Format:** Open blockers at top. Closed blockers moved to archive at bottom.

---

## Open Blockers

### BLK-014 — LMT101 backlit black with full DRM scanout (software lab closed)
**Opened:** 2026-06-02  
**Severity:** **HIGH** — blocks Phase 1 display gate; no further userspace tests change diagnosis  
**Owner:** A1 / vendor FAE  

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

#### Booster-Bit Diagnosis (adopted 2026-06-10)

**Decisive evidence:** `GET_POWER_MODE(0x0A) = 0x18` means bit 7 (booster / internal charge pump) is **CLEAR**. A healthy JD9365D after init reads **0x9C** (booster 0x80 + sleep-out 0x10 + normal 0x08 + display-on 0x04). Our panel latches sleep-out (0x10) + normal (0x08) but the internal DC/DC (BOOSTM=10, JD5001 charge pump, generating AVDD/AVEE/VGH~+15V/VGL~-11V from the single 3.3V VDDIN) **never starts**. Booster off => TFT array cannot switch => black glass for BOTH SoC video AND internal BIST. One failure explains every symptom, including BIST-black.

**Note on 0x0A = 0x18:** Bit 2 (display-on = 0x04) is also clear despite DISON being sent with rc=0. This is consistent with the booster not starting — the JD9365D may not latch display-on if its internal power state machine has not completed.

#### BUILD B Result (2026-06-10 bench)

**Board flashed:** `core-image-minimal-elevator-hmi-em3566.rootfs-20260610170030.wic`, SHA-256 `dd5be78d...`, git `e19ae16` — BUILD B (FAE page-4 clock fix, patches 0011+0013, 0012 commented).

**`GET_POWER_MODE(0x0A) pre-TE = 0x1c`** — new result vs BIST v1 (`0x18`):

| Bit | Mask | BIST v1 (0x18) | BUILD B (0x1c) | Meaning |
|-----|------|----------------|----------------|---------|
| 7 | 0x80 | 0 | 0 | **Booster (JD5001) OFF** — unchanged |
| 4 | 0x10 | 1 | 1 | Sleep-out executed ✓ |
| 3 | 0x08 | 1 | 1 | Normal mode ✓ |
| **2** | **0x04** | **0** | **1** | **Display-on — NEW: DISON now acknowledged** |

**Interpretation:** The FAE page-4 clock fix had a real effect — the panel now latches DISON (display-on bit set). With BIST v1 (no clock fix), DISON was sent but the panel did not latch it. This proves: (a) MIPI communication is clean enough for DISON to land, (b) the panel IS responding to commands, and (c) the clock fix was necessary for reliable DCS delivery. **However, the booster (0x80) never started in either build.** A healthy panel reads 0x9C (all four bits set). The single remaining failure is the charge pump not starting.

**VDDIN = 3.3V constant on DMM (reported 2026-06-10):** Static rail is confirmed present. **Critical caveat: DMM response time ~250ms is blind to 10-50ms transients.** During JD5001 startup, VDDIN must supply 100-300mA peak for ~10-20ms. On the Plan B bypass wire (thin jumper, unknown contact resistance), a 2Ω total path resistance at 200mA = 0.4V drop → FPC sees 2.9V. JD5001 UVLO is typically 2.8-3.0V. The DMM reads 3.3V before and after, never capturing the sag. **The ammeter test (inline current measurement at SLPOUT moment) is the single definitive H1 kill test.**

#### New Init-Table Observation (2026-06-10)

**Page-1 register `E3` is NOT in the standard vendor init table.** Cross-checking `library/LMT101/LMT101SX006C initial codes.txt` against the 196-command init array: the page-1 (`E0,01`) block writes registers 00,01,03,04,0C,17,18,19,1A,1B,1C,35,37,38-3F,40-45,55,57,59,5A,5B,5D-82. Register **`E3` is absent**. The FAE BIST sequence explicitly writes `E0,01` then `E3,01` ("Enable self-test") after DISON. In JD9365D, page-1 `E3` may have effects beyond BIST — it could enable source/gate output or a power stage. **If `E3,01` is required for booster start and is absent from the standard init, this explains why booster never starts in both BIST v1 and BUILD B.** This is a new H4 sub-hypothesis. It needs the vendor FAE to confirm whether `E3` (page 1) affects the charge pump or only the BIST self-test circuit.

**468 vs 420 Mbps explained:** `dw-mipi-dsi-rockchip` applies a deliberate 10/9 bandwidth margin over pixel-derived rate (70MHz x 24/4 x 10/9 ~ 466.7 -> 468 with PLL granularity). It is the host's intentional burst-mode margin, not a timing bug. Mainline precedent (Ondrej Jirman, 2024): non-burst modes should run hsclock = pclk x bpp/lanes exactly — i.e., dropping VIDEO_BURST is the clean path to exactly 420 Mbps if needed later.

**Spec facts verified (LMT101SX006C spec PDF pages 6/7/10/11/13/14):**

- FPC: pin 5 = RESET; pins 2/3 = VDDIN 3.3V; MIPI D0(8/9), D1(11/12), CLK(14/15), D2(17/18), D3(20/21). Project wiring docs match.
- Backlight: VF typ 9.0V, IF 180mA, 27 LEDs — the external 9V bench supply is CORRECT. Closed permanently.
- Reset timing: spec minimums tRESETL 10us / tRESETH 5ms / tSLPOUT 120ms — our 20ms/120ms over-satisfies. Closed.
- Expected JD9365 ID bytes for read-back: **93 65 04** (DCS 0x04).

#### Ranked Hypotheses (updated 2026-06-10 post-BUILD B)

| # | Hypothesis | Status | Kill test |
|---|-----------|--------|-----------|
| H1 | VDDIN sags under booster load (Plan B wire resistance/contact) | **LIVE** — DMM can't see transients | Ammeter inline VDDIN; measure wire resistance (power off, ohmmeter FPC pin2/3 to VCC3V3_SYS tap) |
| H2 | MIPI rate mismatch blocks panel power-up | **PARTIAL** — clock fix allowed DISON to latch (0x18→0x1c); but booster still off; rate may still block booster state machine | BUILD B done; booster still off; send updated vendor email with 0x1c result |
| H4a | Init table missing booster-enable register (page-1 `E3`) | **NEW — PRIMARY** — vendor BIST uses `E3,01` on page 1; standard init does NOT write `E3`; `E3` may enable source driver/power stage | Ask vendor FAE: "does E3 (page 1) only enable BIST or does it also enable source output?" |
| H4b | Other init register wrong for this glass batch | Possible | **DIAG15 (patch 0015):** `0x0F` = `0x40` (reg-load fault) confirms init didn't land; `0x04` ID confirms right IC |
| H3 | HS video masks BIST | Possible but secondary | Rebuild BIST v2 + clock fix combined (new patch) |
| H5 | Lane pair polarity miswired | Low — panel responds to DCS | Only relevant after booster starts |
| H6 | Defective panel sample | Possible | Order 2-3 spares (TASK-137) |

**Key interpretation rule:** ammeter inline VDDIN at boot — **no current step at SLPOUT → panel never attempted booster (software/init domain); spike-then-collapse → supply domain.** This single reading separates H1 from H4.

#### Decision Matrix (updated post-BUILD B)

| VDDIN ammeter | `0x0A` result | BIST v2 glass | Verdict / next action |
|---------------|---------------|---------------|-----------------------|
| Current steps up + holds ~150mA | 0x9C | (any) | Booster OK — debug video path (H5 lane check, non-burst descriptor) |
| Current steps up, then collapses | 0x1c or 0x18 | black | Supply insufficient — fix Plan B wire gauge or bench-supply VDDIN directly |
| NO current step at SLPOUT | 0x1c | black | **Current state** — panel never attempts booster: send vendor email re. `E3`/booster enable; build TASK-136 (0x0A before DISON) |
| NO current step | 0x1c | BIST pattern | Booster starts with BIST `E3,01` but not standard init — confirms H4a (missing page-1 `E3` in normal sequence) |
| 3.3V but FPC pin directly lower | (any) | (any) | Wire resistance sag — fix supply path (H1) |

**Board currently runs:** BUILD B — `core-image-minimal-elevator-hmi-em3566.rootfs-20260610170030.wic`, SHA-256 `dd5be78d...`, git `e19ae16`. **Result: `0x1c`** (DISON acked, booster off). BIST v2 WIC target file is **gone from disk** (symlink `fae-bist-v2.wic` is broken); rebuild required.

**A2 "skip BUILD B" recommendation:** **SUPERSEDED** (2026-06-10). Clock fix was necessary — it allowed DISON to latch. Not sufficient — booster still off. Both tests needed.

#### Patch 0015 — DIAG15 DCS readback (next software gate, 2026-06-10 session 2)

**Patch `0015-drm-panel-jadard-lmt101-diag15-dcs-readback.patch` added to `bbappend`.**

Extends the BUILD B (FAE_CLOCK) post-DISON block with three additional DCS reads:

| Register | Read | Expected | What it tells us |
|----------|------|----------|-----------------|
| `0x04` | Display ID (3 bytes) | `93 65 04` | Confirms JD9365 IC is present and DCS bidirectional link works |
| `0x0F` | Self-Diagnostic Result | `0xC0` | **Most critical** — bit7=reg-load, bit6=func (booster). `0x80` = func fault = booster failed. `0x40` = reg-load fault = init didn't land. `0x00` = dead panel (H6). |
| `0x45` | Scanline (post-TE) | Non-zero | Panel's timing controller running. Persistent `0x00` = display engine dead (booster off). |

Sentinel: `jadard: DIAG15` emitted last. Build + flash this image as next bench step.

`dmesg | grep -i diag15` acceptance pattern:
```
jadard: DIAG15 ID=0x?? 0x?? 0x?? (expect 93 65 04)
jadard: DIAG15 self-diag=0x?? (0xC0=OK 0x80=func-fault 0x40=reg-fault 0x00=dead)
jadard: DIAG15 scanline=0x?? (non-0=timing-ctrl-running)
jadard: DIAG15
```

**`0x0F` result is the single most important new data point.** It is the panel's own self-test verdict and directly discriminates H4a/H1 from H6.

**References:** `docs/VENDOR-SUPPORT-LMT101-BRINGUP.md`, `diary/PROGRESS.md` **2026-06-02**, `docs/FAE-BIST-CLOCK-BUILD.md`, `docs/LMT101-CLOCK-RATE-AUDIT.md`, `docs/LAB-LMT101-TEST-CHEATSHEET.md` Phase L.

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
