# Development Diary — Elevator HMI

**Format:** One entry per session. Most recent entry first.

> **NOTE (2026-07-23):** day-to-day investigation record moved to
> `diary/SESSION-LOG.md` (flat log, charter rev 2). This file now carries
> milestone-level summaries only.


## 2026-08-18 — daylight cabin theme (light, colourful)

**Agent:** continuation

- Light theme: sky field, white cards with colour stripes (teal door,
  orange load, blue diagnostics, green service, gold activity), cobalt
  floor number, orange DEMO/motion. Software-renderer safe.
- **Image:** `images-archive/qt-hmi-daylight.wic`
  SHA `36e1aabe1f03594263442de2086ec8b21f18189e4fa3bef269185502869180e4`.

## 2026-08-18 — QML views failed to load (only DEMO chip); fixed

**Agent:** continuation

- On-glass: `qt-hmi-orientations.wic` `0a3a6f6b…` showed only `DEMO · TRAVEL`
  at the bottom. `Loader.setSource("PortraitView.qml")` resolved against
  cwd `/`. Fixed by instantiating the views directly.
- **Image:** `images-archive/qt-hmi-orientations.wic`
  SHA `d45ed163958d9ee4a148ccb13d67ba32fb865fd3b2e3d22e670cc6628e97b6a5`
  (same archive name, new bits).

## 2026-08-18 — both orientations installed (portrait + landscape)

**Agent:** continuation

- Product goal: HMI supports **landscape and portrait**. The four
  `design/elevator-hmi` HTML variants are all installed and CLI-switchable
  (`hmi portrait` / `portrait-video` / `landscape` / `landscape-video`).
  Landscape is a 1280×800 QML stage rotated onto the native 800×1280
  framebuffer (`hmi rot 90|270`). Panel hardware is unchanged (portrait
  scanout). `docs/roadmap-v1.md` is missing from the tree; HANDOFF
  orientation row closed.
- **Image:** `images-archive/qt-hmi-orientations.wic`
  SHA `0a3a6f6b892fbe80446b3e5ca1cc7b5be7df6fef9893133a3c2d69a9f6482984`.
- Video panes still empty (BLK-015 + next-task SD player).

## 2026-08-18 — daylight cabin theme (light, colourful)

**Agent:** continuation

- **Image:** `images-archive/qt-hmi-daylight.wic`
  SHA `36e1aabe1f03594263442de2086ec8b21f18189e4fa3bef269185502869180e4`.


## 2026-08-18 — first Qt 6.8.3 EGLFS image built (qt-hmi.wic)

**Agent:** continuation (takeover mid-build)

- Handoff public-6.8.3 image build had already failed (Mali EGL CMake).
  Subsequent rebuilds got qtbase/EGLFS working, then died on empty
  `qtshadertools` (no Qt Quick), Quick3D spatial audio, and unshipped
  `main.qml`.
- **Image built:** `images-archive/qt-hmi.wic`
  SHA `06a9f623c66239461bf8718b9d19390f8b3893b061aa903178308cd3ffe0a768`,
  git recipes `134332a`. Manifest has qtbase, qtdeclarative,
  rockchip-libmali, elevator-hmi-app. App ships binary + QML + sysvinit
  script. Kernel remains 0021-only (do not re-enable 0022/0023/0024).
- **Owner:** flash `qt-hmi.wic` from `images-archive/` (commands in
  `docs/FLASH-PROCEDURE.md` and the newest `diary/SESSION-LOG.md` entry).
  Expected glass: Qt mockup. If fbcon overpaints:
  `echo 0 > /sys/class/vtconsole/vtcon1/bind`.
- Still open: vendor correction email #6 unsent; Qt LTS/LGPLv3 legal
  item (ADR-001a); sysvinit vs systemd.

## 2026-08-07 — ✅ DISPLAY WORKS: BLK-014 resolved, Phase 1 display gate PASSED

**Agent:** lead (single-agent)

- **Panel confirmed working on glass**: Tux boot logo + live console rendering,
  unaided, from `images-archive/fbcon-display.wic`
  (SHA `f13f3eb00d95a0465e3b7b265e800020ae55d4deb6d4e55e578f59b304410bab`).
- **Root cause (two stacked bugs, both host-side software):**
  1. **DSI init ordering** — this Rockchip kernel enters VIDEO mode in
     `bridge_atomic_enable()` *before* `drm_panel_enable()`, so the vendor
     bring-up was transmitted into a live video stream. Fixed by patch **0021
     (INIT-IN-PREPARE)** — sequence moved to `prepare()`, command mode, pre-video.
  2. **`CONFIG_FRAMEBUFFER_CONSOLE` unset** — `/dev/fb0` existed but nothing ever
     rendered into it; a zero-filled framebuffer is a correctly-displayed black
     screen. This hid fix (1) for ~2 weeks. Enabled with `CONFIG_LOGO`.
- **Hardware fully exonerated**: panels (both), 3.3 V rail, XRES timing
  (scope-verified), MIPI lanes, FPC wiring, load switch. Vendor's init file was
  correct as supplied and never needed modification.
- **Process lesson**: 0021's kill test was validated only via BIST — an
  instrument that never produced a positive result on this panel and so could
  not report a trustworthy negative. The framebuffer-content half of the same
  kill test would have shown the fix immediately.
- Vendor correction drafted (`docs/VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL-6-RESOLVED.txt`)
  — LCD Mall to be told to stop investigating; their panels and code are fine.
- Next: Qt 6.8 / EGLFS application (Phase 1 deliverable), now unblocked.

## 2026-07-22/23 — Vendor BIST test: black on BOTH panels; state-dump reply ready; workspace cleaned

**Agent:** lead (single-agent, charter rev 2)

- **Zero-trust firmware audit** (owner directive): init table re-verified **196/196
  byte-identical** to vendor file by script; reset timing, porches, enable path, dclk
  (70 MHz exact) all vendor-exact from the actual patched build tree. Command layer
  exonerated with direct evidence.
- **Vendor's 7/7 BIST test executed** on fresh `bist-468.wic` (SHA `de0e0b60…`, git
  `e7871a9`): BIST armed + clean DIAG15 same boot → **glass BLACK on unit #1 and
  spare unit #2** — the "hardware issue confirmed" branch of the vendor's own
  criterion. Ran on the stock VCC3V3_LCD switch path (bypass jumper removed;
  BLK-013 superseded — May diagnosis was wrong-pin/inverted-polarity).
- **Record corrections:** email #3 confirmed SENT 7/3; 420 Mbps read-reliability
  stated precisely (1 clean / 4 × `-110` builds; 468 always clean); dclk question
  closed.
- **Vendor reply #4** (pure state dump, no diagnosis pushed):
  `docs/VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL-4.txt` — verbatim logs, full hardware
  state, questions A–G (PLL_CLOCK semantics 420 vs 840 Mbps/lane, analog-rail FPC
  pin map + healthy DC values for DMM check, peak-inrush spec 3rd ask, VDDIN-jpg
  capture window, external-vs-integrated boost, BIST preconditions, disposition).
  Owner send checklist at file bottom. **Waiting on vendor.**
- **Workspace cleanup:** junk removed, scratch dirs → `local-archive/` (ignored),
  serial captures → `diary/captures/`, `vendor-email-attachments/` + email #3
  tracked, `.gitignore` covers `build/`, `.claude/`.

## 2026-06-13 (session 10) — VENDOR-CLOCK-MATCH image built (TASK-140)

**Agent:** A1 implement + build

Owner directive: "sync all workspace to vendor truths to get the corrected image and build." Folded the two remaining firmware mismatches vs the LCD Mall vendor thread into one patch and built a fresh vendor-truth WIC.

- **Patch `0019-drm-panel-jadard-lmt101-vendor-clock-match.patch`** (after 0018 in `linux-rockchip_%.bbappend`):
  - `jadard_dsi_probe()`: drop `MIPI_DSI_MODE_VIDEO_BURST` for all LMT101 enable seqs → lane rate **420 Mbps** (vendor PLL_CLOCK=420; 5 Jun "MIPI rate mismatch"). Legacy cz101 keeps burst.
  - `jadard_prepare()`: XRES low pulse `msleep(10)` → `msleep(20)` (vendor Q1 reset diagram).
  - Sentinel `jadard: VENDOR-CLOCK-MATCH`.
- **Unchanged (already vendor-matched):** 196-pair init table, six porches, FAE page-4 clock block (0011/0013), SLPOUT 120 ms / DISON 5 ms / 0x35 tail, DIAG15 reads (0015), DCS-INIT framing (0018).
- **Scope note:** vendor 13 Jun Q2 — LP-clock-at-0x11 / 140 ms-late HS does **not** block lighting (boost on on-chip RC osc), so 0019 does not force continuous-HS-before-init; that stays bench/scope-gated.
- **Build:** `cleansstate` + `virtual/kernel` + WIC → `BUILD_EXIT_CODE=0`, `do_patch: Succeeded`, driver `.o` strings confirm sentinel + 20 ms reset.
- **Artifact:** WIC SHA `7dbf72d902a580c05db0d236665b18eaf227309395104257efa075c3ea1217a7`, file `…rootfs-20260613123616.wic` (label `vendor-clock-match`, default `.wic`), git `d9565d6`+0019.
- **Owner bench:** flash → `dmesg` must show `VENDOR-CLOCK-MATCH` + `bandwidth: 420 x 4 Mbps`; XRES low ≈20 ms; `modetest` + DIAG15 vs baseline; BL **9.6 V**, VDDIN 75 mA / rail scope, CLK+D1–D3 lane scope.

## 2026-06-13 (session 9) — FINAL VENDOR-MATCH RECORD locked

**Agent:** A1 consolidate + A2 record

### Locked verdict (27 vendor lines)

- **19/19** checkable firmware/register lines: ✅ match
- **3 mismatches:** PLL 420 vs 468 (#14), HS@0x11 (#24), BL 9.6 vs 9.0 V (#25)
- **4 bench-confirm:** rail ≥90% (#6), VDDIN 75 mA (#23), BL 180 mA (#26), lane scope

### Close plan

- **TASK-140** `VENDOR-CLOCK-MATCH` → #14 + #24 (owner ACK)
- **Bench:** 9.6 V BL, VDDIN ammeter/scope, CLK+D1–D3 scope (PRIME), pin-3 DMM

Full table + locked statement: `diary/STATE-2026-06-13-vendor-reply.md` §FINAL VENDOR-MATCH RECORD

---

**Agent:** A2 — quote driver source, no patch

### Verdict

- **9/10** vendor timed steps **match** in `jadard_prepare()` / `jadard_enable()`
- **Gap 1 (10 ms power→reset):** ✅ `msleep(10)` after rails (patch 0007)
- **Gap 2 (5 ms high preamble):** ✅ patch **0010** — high 5 ms → low 10 ms → high 120 ms (vendor file)
- **Q1 vs file low pulse:** driver **10 ms** (file), not Q1 **20 ms** — documented deviation
- **Gap 3 (rail ≥90%):** bench scope only
- **FAE DIAG:** extra 50 ms + 20 ms — over-satisfies vendor tail; not in vendor file

Full table: `diary/STATE-2026-06-13-vendor-reply.md` §Timing-completeness

---

**Agent:** A1 reconcile + A2 record

### Vendor authority match (A–I)

- **MATCH:** reset, power seq, init table, porches, tail, `0x0F=0xC0`, booster criterion (`0x1c`)
- **MISMATCH (3):**
  1. PLL_CLOCK **420** vs dmesg **468** Mbps/lane
  2. Vendor check 2: continuous HS at **0x11** — we are **LP** until video ~140 ms later
  3. Backlight **9.6 ± 0.1 V** vs bench **9.0 V**

### Actions

- **TASK-140** `[BLOCKED]` — combined `jadard: VENDOR-CLOCK-MATCH` (non-burst → 420 + HS-before-init); read-only report in STATE
- **TASK-139** → `[DONE]` (H-pkt dead)
- **Owner bench (no firmware):** BL **9.6 V**, pin-3 DMM, lane scope, optional VDDIN 75 mA

Full tables: `diary/STATE-2026-06-13-vendor-reply.md` §Vendor checklist

---

## 2026-06-13 (session 6) — TASK-139 bench: H-pkt RULED OUT, software exhausted

**Agent:** Owner bench + A2 record

### On-target (DCS-INIT WIC `171ba011…`)

- `jadard: DCS-INIT` ✓
- `0x0A=0x1c`, `0x0F=0xC0`, `0x45=0x00`, ID `0x93` — **byte-identical to generic baseline**
- Glass: **black**

### Conclusions

- **H-pkt DEAD** — generic vs DCS framing changes nothing
- **Software EXHAUSTED** — values, tail, timing, framing all tested
- **0x18 vs 0x1c CLOSED** — `0x1c` = display-on latched; vendor-healthy; not a fault signal
- **Next:** hardware only — pin-3 DMM → CLK + D1–D3 scope (PRIME) → spares

---

## 2026-06-13 (session 5) — A2: TASK-139 DCS-INIT build (H-pkt)

**Agent:** A2 — owner ACK received

### Delivered

- Patch **`0018-drm-panel-jadard-lmt101-dcs-init.patch`** — init burst `mipi_dsi_dcs_write_buffer()` + `jadard: DCS-INIT`
- **`cleansstate`** + full WIC rebuild

### Artifact triple

| Field | Value |
|---|---|
| WIC SHA-256 | `171ba011be2c012437f261a27062a41563633ac54b8d9424196a49ad88a1fd24` |
| WIC | `…rootfs-20260613113555.wic` / symlink `…rootfs-dcs-init.wic` |
| git HEAD | `d9565d644d76f37120c138d7ea4f5e42b72294b8` |
| Kernel strings | `jadard: DCS-INIT` present |

### Owner bench (acceptance)

Flash `rootfs-dcs-init.wic`. Capture full `dmesg | grep -E 'jadard|DIAG15'`. Run `modetest` tiles. Compare DIAG15 block vs generic baseline (`e215a94a…`).

---

## 2026-06-13 (session 4) — A2: H-pkt verification (packet framing)

**Agent:** A2 read-only — promoted per A1

### Findings

| # | Item | Result |
|---|------|--------|
| 1 | Init burst API | `mipi_dsi_generic_write()` — patch `0006` |
| 2 | Tail `0xE0,0x00` API | `mipi_dsi_dcs_write_buffer()` — patch `0004` |
| 3 | Mainline JD9365DA-H3 (`0001` backport) | **`mipi_dsi_dcs_write_buffer()`** for init loop |
| 4 | `mode_flags` | `0x203` — no generic/DCS flag; driver API only |

**Conclusion:** TASK-127 inverted mainline. **H-pkt PRIME.** Gated `DCS-INIT` = TASK-139.

**Counter-evidence:** `0x0F=0xC0` reg-load bit set — does not block cheap flash test.

---

## 2026-06-13 (session 3) — A2: SLPOUT/DISON tail verification (read-only)

**Agent:** A2 — four-point source audit per A1

### Results

| # | Check | Verdict |
|---|-------|---------|
| 1 | `0xE0,0x00` between SLPOUT and DISON | **PRESENT** (`0004` enable path) |
| 2 | 120 ms SLPOUT→DISON delay | **PRESENT** (`display_init_delay=120`; on-target ~124 ms) |
| 3 | Reset timing | **Partial** — 20 ms assert (vendor 10 ms); 10 ms rail settle vs vendor 5 ms pre-pulse; 120 ms post-release OK |
| 4 | 196 init pairs vs vendor file | **BYTE-IDENTICAL** (script diff pre-`0x11` tail) |

### Caveats

- Tail `0xE0,0x00` uses `mipi_dsi_dcs_write_buffer`; init table uses `mipi_dsi_generic_write` — packet-type inconsistency, not absence.
- FAE_CLOCK baseline adds page-4 pre-SLPOUT block + post-DISON diag/TE — not in vendor file they lit.
- **`jadard: SLPOUT-TAIL` patch: NOT warranted** for items 1–2.

Full detail: `diary/STATE-2026-06-13-vendor-reply.md` §SLPOUT/DISON tail verification.

---

## 2026-06-13 (session 2) — A1: H-HSclk framing correction + bench priority

**Agent:** A1 correction applied to A2 clock report

### Correction

A2 had combined `mode_flags=0x203` (CLOCK_NON_CONTINUOUS **not** set) with “check 2 not satisfied → H-HSclk live” — overstated. Precise statement:

- Not “non-continuous gating between bursts” — **no HS clock at all during init/SLPOUT**; HS starts ~140 ms later at video.
- Vendor **Q2** (formal): late HS is fine for lighting (on-chip RC) → contradicts **check 2** in same email.
- **H-HSclk reclassified:** scope-gated / **LOW** priority — not a confirmed software defect.

### Bench order (authoritative)

1. **H1b** — FPC pin 3 DMM (**HIGH**)
2. **H5** — Scope D1–D3 + CLK during `modetest` (**PRIME**)
3. **H-HSclk** — CLK @ SLPOUT confirmatory (**LOW**, same session)
4. **H6** — Spares parallel

**`HSCLK` patch:** BLOCKED; contingent on scope anomaly **and** H1b + H5 clean.

**Files updated:** `diary/STATE-2026-06-13-vendor-reply.md`, `diary/BLOCKERS.md`, `AGENTS.md`

---

## 2026-06-13 — Vendor reply consolidation + A2 clock report (BLK-014 correction)

**Agent:** A2 (Composer2 — read-only investigation + diary)

### Vendor LCD Mall reply (13 Jun 2026)

- **Q1:** Integrated boost (JD5001) starts inside `0x11`; **healthy `0x0A = 0x18`** (D7=0). **`0x9C` = external boost fault** — overturns prior booster-bit theory.
- **Q2:** Boost uses on-chip RC, not MIPI CLK — **H7 DEAD**.
- **Q3:** Steady VDDIN **75 mA** when active.
- **Q4:** `0x0F = 0xC0` healthy — matches our DIAG15.
- Vendor re-lit panel with **same** `library/LMT101/LMT101SX006C initial codes.txt` — **H-init DEAD**.

### Owner decisions

- **K1** (wire resistance) and **K2** (ammeter @ SLPOUT): **skipped**.
- Firmware stays on **vendor baseline**: init + patch **0013** (Test 1 clock) + **0015** (DIAG15); **0012** BIST and **0016** H4a **commented out**.

### A2 clock-lane report (no code changes)

- `mode_flags=0x203` — **no** `MIPI_DSI_CLOCK_NON_CONTINUOUS`.
- Init + SLPOUT/DISON sent in **LP**; continuous HS (`468×4`) ~140+ ms **after** DISON.
- **Vendor check 2: NOT satisfied** — H-HSclk **LIVE**. Gated patch candidate: `jadard: HSCLK`.

### Records updated

- `diary/STATE-2026-06-13-vendor-reply.md` — consolidated truth + timing audit
- `diary/BLOCKERS.md` — BLK-014 booster theory superseded; live hypothesis board
- `AGENTS.md` — TASK-138 reframed H-HSclk; sprint queue corrected

### Next (owner bench, no firmware)

1. FPC **pin 3** DMM — must be **3.3 V** (H1b)
2. Scope **CLK** @ 3.4–4.0 s (SLPOUT window)
3. Scope **D1–D3 + CLK** during `modetest` (H5)
4. Order spare panels (TASK-137)

---

## 2026-06-10 (session 5) — A2: DIAG15 reverted build — H4a removed, clean baseline WIC

**Agent:** A2 (Composer2 — implementation)

### DIAG15 reverted build

`cleansstate` → full kernel rebuild → WIC. Patch 0016 (H4a) confirmed absent from binary.

**Artifact triple:**

| Field | Value |
|---|---|
| **WIC SHA-256** | `e215a94a4dd10aedb470a8c69f3334c43a5c87929a21104d0e23b37c8270e38f` |
| **WIC file** | `core-image-minimal-elevator-hmi-em3566.rootfs-20260610191946.wic` |
| **Symlink** | `core-image-minimal-elevator-hmi-em3566.rootfs-diag15.wic` |
| **git HEAD** | `5e1812775f2e9c5e4d9cbef4ab88f954b4f3136f` (branch `task/TASK-132-vcc3v3-lcd0-active-low-pfet`) |
| **dmesg signature** | `jadard: DIAG15` (0x04/0x0F/0x45 reads; no H4a sequence) |

**Binary verification:**
- `strings Image | grep "H4a sent"` → no match (**H4a sequence ABSENT**)
- `strings Image | grep "DIAG15"` → 9 DIAG15 strings present (**DIAG15 intact**)

**On-target result confirmed (2026-06-10 22:54):**
```
[    3.685899] jadard: FAE page-4 clock fix (pre-SLPOUT)
[    3.688009] jadard: SLPOUT sent
[    3.811604] jadard: DISON sent
[    3.884678] jadard: GET_POWER_MODE(0x0A) pre-TE=0x1c
[    3.901740] jadard: DIAG15 ID=0x93 0x00 0x00 (expect 93 65 04)
[    3.918992] jadard: DIAG15 self-diag=0xc0 (0xC0=OK ...)
[    3.931554] jadard: FAE TE on (0x35,0x00)
[    3.967908] jadard: DIAG15 scanline=0x00 (non-0=timing-ctrl-running)
[    3.967947] jadard: DIAG15
[    3.967955] jadard: init table: 196 cmds, rc=0
```
No `H4a sent` line — **revert confirmed**. Board on vendor-healthy digital baseline (`0x1c`/`0xC0` per vendor 2026-06-13). Owner skipped K1/K2; next = pin-3 DMM + CLK scope (see `diary/STATE-2026-06-13-vendor-reply.md`).

---

## 2026-06-10 (session 4) — A2: H4a on-target result + software investigation closure

**Agent:** A2 (Composer2 — analysis)

### H4a on-target result

**Board flashed:** `core-image-minimal-elevator-hmi-em3566.rootfs-h4a.wic` (SHA `0b486efe…`, git `883b364`)

**Result:**
```
dmesg | grep "GET_POWER_MODE"
[    3.887484] jadard-jd9365da fe060000.dsi.0: jadard: GET_POWER_MODE(0x0A) pre-TE=0x08
```

**`0x08` decoded:**

| Bit | Mask | Value | Meaning |
|-----|------|-------|---------|
| 7 | 0x80 | 0 | Booster (JD5001) — **still OFF** |
| 4 | 0x10 | 0 | Sleep-out — **CLEARED** (was 1 in all prior builds) |
| 3 | 0x08 | 1 | Normal mode — set (hardware default on power-on) |
| 2 | 0x04 | 0 | Display-on — **CLEARED** (was 1 in BUILD B / DIAG15) |

**Comparison across all builds:**

| Build | 0x0A | Booster | Sleep-out | DISON |
|---|---|---|---|---|
| BIST v1 | `0x18` | OFF | ✓ | ✗ |
| BUILD B | `0x1c` | OFF | ✓ | ✓ |
| DIAG15 | `0x1c` | OFF | ✓ | ✓ |
| **H4a** | **`0x08`** | **OFF** | **✗** | **✗** |

**Conclusion:** The `F0,55/F1,AA/E0,01/E3,01/E0,00` sequence triggered an **internal panel soft-reset**. The sleep-out and display-on flags — which had been properly set by SLPOUT+DISON — were cleared back to power-on default. Only the hardware "normal mode" bit (always 1 after power-on) survived. `E3,01` after `F0/F1` BIST unlock is a **BIST preparation command**, not a production booster enable register. Writing it in a production init path reinitializes the display engine for self-test mode and wipes all prior display state.

**H4a eliminated.** The booster does not start in BIST mode either (0x08 means no booster start — identical failure mode to 0x18/0x1c). This confirms H1 (supply) and/or H2 (vendor FAE for the correct booster-enable register in production mode).

### Software Investigation: CLOSED

All software hypotheses have been tested to exhaustion:

| Test | Outcome | Hypothesis closed |
|---|---|---|
| BUILD B (clock fix) | `0x1c` — DISON latched | H2 partial; MIPI comms robust |
| DIAG15 `0x0F=0xC0` | Registers OK, IC healthy | H4b, H6 eliminated |
| DIAG15 `0x04=0x93` | JD9365D confirmed | H6 eliminated |
| H4a `E3,01` test | `0x08` — soft reset triggered | **H4a eliminated** |

**Remaining: H1 only.** Ammeter inline VDDIN at SLPOUT is the single remaining hardware test before vendor re-engagement.

### Next immediate actions

1. **K1 (owner, board off):** ohmmeter FPC pin 2/3 → Plan B wire → VCC3V3_SYS tap. Target < 0.3Ω.
2. **K2 (owner, bench supply):** ammeter inline VDDIN at boot. Watch 3.5s SLPOUT window. Spike-then-collapse = H1. No spike = vendor.
3. **Vendor email update:** Send updated email with `0x08` regression data — vendor FAE now has: `0x18` (BIST v1) → `0x1c` (BUILD B / DIAG15) → `0x08` (after E3,01). Three data points + `0x0F=0xC0`. Ask: what production register enables the booster (not E3 which is BIST-mode)?
4. **TASK-137:** Order 2-3 spare LMT101 units (H6 still possible as secondary, spares needed regardless).

---

## 2026-06-10 (session 3) — A2: TASK-136 patch 0016 — H4a E3,01 booster enable

**Agent:** A2 (Composer2 — implementation)

### Patch 0016 — H4a booster enable test

**Motivation:** DIAG15 result (`0x0F=0xC0`) eliminated H4b and H6. Booster still off
(`0x0A=0x1c`). H4a hypothesis: the standard init table never writes page-1 `E3` — which
the FAE BIST sequence explicitly does (`E0,01 / E3,01` after DISON). Adding the full FAE
unlock + E3 write to the standard clock-fix path tests H4a directly.

**What patch 0016 adds** (inserted in FAE_CLOCK path, before `msleep(50)` / `0x0A` read):
```
F0,55  — Jadard unlock byte 1 (password for protected registers)
F1,AA  — Jadard unlock byte 2
E0,01  — select page 1
E3,01  — write E3 (charge pump / booster enable candidate)
E0,00  — restore page 0 for TE + scanout
```
The existing 50ms settle + `0x0A` read in DIAG15 immediately reports the result.
No new diagnostic code needed.

**Artifact triple:**
| Field | Value |
|---|---|
| **WIC SHA-256** | `0b486efef44d058b14d912e3fc05e1f9a6e91302da700c66ad6e40dfb23d74f7` |
| **WIC file** | `core-image-minimal-elevator-hmi-em3566.rootfs-20260610184840.wic` |
| **Symlink** | `core-image-minimal-elevator-hmi-em3566.rootfs-h4a.wic` |
| **git HEAD** | `883b364` (branch `task/TASK-132-vcc3v3-lcd0-active-low-pfet`) |
| **dmesg signature** | `jadard: H4a sent F0,55/F1,AA/E0,01/E3,01/E0,00` |

**Kernel strings confirmed:** H4a sequence + DIAG15 (0x04/0x0F/0x45) all present in Image binary.

**On-target acceptance — what to look for:**
```bash
dmesg | grep "jadard:"
```
- `jadard: H4a sent F0,55/F1,AA/E0,01/E3,01/E0,00` — confirms sequence was sent
- `jadard: GET_POWER_MODE(0x0A) pre-TE=0x9c` — **H4a CONFIRMED, booster started**
- `jadard: GET_POWER_MODE(0x0A) pre-TE=0x1c` — H4a NOT the cause, proceed to ammeter (H1)

---

## 2026-06-10 (session 2) — A2: TASK-136 DIAG15 kernel build — patch 0015 verified + WIC artifact

**Agent:** A2 (Composer2 — implementation)

### TASK-136 DIAG15 — BUILD complete

**Patch 0015** (`0015-drm-panel-jadard-lmt101-diag15-dcs-readback.patch`) generated from
live kernel source (work-shared after patches 0001–0013), diff verified by Python line-count
check (all 3 hunks OK), then built clean.

**Artifact triple (Artifact-Triple Rule):**
- **WIC SHA-256:** `22a40d74aab647a175c6ccf21665afbda57a4773b32cf1af20d0f4f0e385d0d4`
- **WIC file:** `core-image-minimal-elevator-hmi-em3566.rootfs-20260610182350.wic`
- **Symlink:** `core-image-minimal-elevator-hmi-em3566.rootfs-diag15.wic`
- **git HEAD:** `746679063b4a86c42e3cfa350744091467c501a3`
- **dmesg signature (on-target, expected):** `jadard: DIAG15` with 0x04 / 0x0F / 0x45 values

**Kernel strings confirmed in Image binary:**
- `jadard: DIAG15 ID=0x%02x 0x%02x 0x%02x (expect 93 65 04)`
- `jadard: DIAG15 self-diag=0x%02x (0xC0=OK 0x80=func-fault 0x40=reg-fault 0x00=dead)`
- `jadard: DIAG15 scanline=0x%02x (non-0=timing-ctrl-running)`
- `jadard: DIAG15` (sentinel)

**Issue resolved during build:** Original patch 0015 had hand-written `@@ -99,7 +99,7 @@` headers
with wrong line numbers. Fix: regenerated from live kernel source using `git diff`, verified all
three hunks with Python count script.

**Flash command (owner):**
```
rkdeveloptool db rk356x_spl_loader_v1.13.112.bin
rkdeveloptool wl 0 core-image-minimal-elevator-hmi-em3566.rootfs-diag15.wic
rkdeveloptool rd
```

**On-target acceptance (after flash + boot):**
```
dmesg | grep "jadard:"
```
Must show all four DIAG15 lines. Key result: `0x0F` value.
- `0xC0` = booster OK (normal, display should work)
- `0x80` = functionality fault (booster never started, confirms H1/H4a)
- `0x40` = register loading fault (init table didn't land, H4b)
- `0x00` = total fault (defective panel, H6)

---

## 2026-06-10 — A1: BLK-014 recovery — workspace audit + booster-bit diagnosis + BUILD B rebuild

**Agent:** A1 (Claude Code — lead)

### Phase A — Chain-of-custody audit (PASS with findings)

**git state:** HEAD `49f1f28` on `task/TASK-132-vcc3v3-lcd0-active-low-pfet`. All FAE patches (0010–0014) were **untracked** (never committed by A2). bbappend + doc updates were uncommitted modified files. **No** duplicate or conflicting patch versions. Committed this session.

**Patch integrity (0011–0014):** All non-empty with real code hunks. 0011 = 149 lines / 103 hunk lines (BIST+CLOCK paths). 0012 = 15 lines (BIST desc). 0013 = 17 lines (CLOCK desc). 0014 = 33 lines (BIST v2 delay+noburst). All target `panel-jadard-jd9365da-h3.c`. The empty-0011 incident is resolved.

**bbappend:** BUILD B default — 0011+0014+0013 active, 0012 commented. Matches `docs/FAE-BIST-CLOCK-BUILD.md`.

**WIC reconciliation:**

| Artifact | Status |
|----------|--------|
| BIST v1 `…20260606151107` / `d2ce5af7` | **MISSING** from disk — **retired**. Board currently runs this image. |
| BUILD B `…20260610164058` / `0df2fb49` | **Present** (rebuilt this session), SHA-256: `0df2fb49d9d8816200d84dc2fc43691fe189f66cbc1e702658a96c3e508fc42e`. |
| BIST v2 `…20260606161609` / `889d071d` | **Present**, SHA-256 verified MATCH. Never flashed. |

**Deployed kernel strings:** `FAE page-4 clock fix (pre-SLPOUT)` + `BIST armed (500ms post-unlock)` + `VIDEO without BURST` — all three signatures in the same binary (0011 includes both paths; descriptor selects at runtime). Image on disk = FAE Clock Fix build (BUILD B).

**Stash audit:**

| Stash | Files | Content | Disposition |
|-------|-------|---------|-------------|
| `stash@{0}` (on develop) | `elevator-hmi-boardcon-em3566-v3.dts` (+32 lines) | WIP board DTS additions | Historical — superseded by TASK-132/133 DTS. Keep for reference. |
| `stash@{1}` (on develop) | `library/EM3566/README.md` (+1), `library/EM3566/Schematic/em3566_v3sch.md` (+1190/-1164) | Schematic markdown re-extraction | Historical — library file reformatting. Keep for reference. |

Both stashes are historical and do not conflict with the current working tree. No action needed.

**Artifact-Triple Rule:** Instated in `AGENTS.md` Coordination Protocol (A5). All future bench results require: (1) WIC SHA-256, (2) dmesg build-signature line on target, (3) `git rev-parse HEAD`.

---

### Phase B — Booster-bit diagnosis adopted

**BLK-014 updated** with the decisive finding: `GET_POWER_MODE(0x0A) = 0x18` — booster bit D7 is CLEAR. Healthy JD9365D reads `0x9C` after init. The internal DC/DC (JD5001 charge pump generating AVDD/AVEE/VGH/VGL from 3.3V VDDIN) **never starts**. This single failure explains ALL symptoms including BIST-black.

**TASK-134:** `[DONE]` — BIST v1 black explained by booster-off.  
**TASK-135:** `[TESTING]` — BUILD B rebuild in progress.  
**TASK-136:** `[BLOCKED]` — diag patch 0015, gated on B1–B3 results.  
**TASK-137:** `[READY]` — owner orders 2–3 spare LMT101SX006C units.  
**CLAUDE.md §6:** R-06 added — LMT101 abs-max operating −20°C to 60°C vs project −20°C target.

---

### B1 — Owner Lab Card: VDDIN Power Measurement

**Do this NOW on the currently flashed image (BIST v1). No reflash needed.**

**Equipment:** DMM (minimum). Preferred: bench power supply with ammeter, 3.3V / 1A limit.

**Measurement A — DMM on Plan B jumper (quick):**

1. Cold boot the board (power cycle).
2. At login prompt, measure **FPC pin 2 or 3 vs GND (pin 4 or 7)** with DMM. Record voltage.
3. Also measure **CON1 pins 5/6 vs GND** — this catches jumper/contact drop vs FPC.

**Measurement B — Ammeter through boot (preferred, decisive):**

1. Disconnect Plan B jumper wire from CON1 5/6 to FPC.
2. Connect bench supply: **3.3V, current limit 1A** → FPC pins 2 and 3 (VDDIN). GND → FPC pin 4 or 7.
3. Power on the board. Watch the ammeter through the **3.4–4.0 second** window (when SLPOUT fires).
4. Record: (a) idle current before boot, (b) whether current **STEPS UP** at ~3.7s (SLPOUT), (c) steady-state current after init.

**Interpretation:**
- **No current step at SLPOUT** = panel never attempted booster start → software/rate/init domain
- **Spike then collapse** = supply domain (sag, insufficient current)
- **Current steps up and holds** = booster working, problem is downstream

Paste numbers in this diary with the artifact triple: WIC = `d2ce5af7...`, dmesg signature = `BIST armed`, commit = `e376021`.

---

### BUILD B rebuild — [DONE] (A2 — 2026-06-10, cleansstate build)

**A2 note (2026-06-10):** The A1-recorded `164058` / `0df2fb49` artifact was built earlier today **before** cleansstate. Per the directive (descriptor-only swap = stale sstate risk), A2 ran `bitbake linux-rockchip -c cleansstate` before recompiling. New canonical BUILD B artifact:

| Field | Value |
|-------|-------|
| **WIC filename** | `core-image-minimal-elevator-hmi-em3566.rootfs-20260610170030.wic` |
| **WIC SHA-256** | `dd5be78dec198a984dce271a658219b3e44006df58d04709a3bed66fbb9728ad` |
| **symlink** | `…rootfs-fae-clock.wic` → `…20260610170030.wic` (updated) |
| **Git HEAD** | `e19ae163b81db9c08b1b04813b313079787f0ff0` (branch `task/TASK-132-vcc3v3-lcd0-active-low-pfet`) |
| **Build** | `cleansstate` → compile (990 tasks, all succeeded) → deploy → image_wic -f → image_complete -f |
| **do_patch proof** | Patches 0011, 0013, 0014 fell back from `git am` → `git apply` (INFO level, standard Yocto behavior). No fuzz/reject/FAILED lines. All three applied cleanly. |

**Kernel strings verified (BUILD B):**
- ✅ `jadard: FAE page-4 clock fix (pre-SLPOUT)` — BUILD B runtime signature
- ✅ `jadard: GET_POWER_MODE(0x0A) pre-TE=0x%02x` — pre-TE read path compiled in
- ✅ `jadard: FAE TE on (0x35,0x00)` — TE enable compiled in
- ℹ️ `jadard: BIST armed (500ms post-unlock)` — in binary (both paths compiled; descriptor 0013 selects CLOCK at runtime, BIST branch will NOT execute)

**B2 gate (on-target):** Flash `…rootfs-fae-clock.wic` (SHA `dd5be78d…`). On first boot:
- `dmesg | grep -i jadard` MUST show `jadard: FAE page-4 clock fix (pre-SLPOUT)` and `jadard: FAE TE on`
- MUST NOT print `jadard: BIST armed`
- Record `GET_POWER_MODE(0x0A) pre-TE=0x??` — **0x80 set = booster up = H2 confirmed; 0x18 = booster still off = H1/H4 domain**
- Log with artifact triple: WIC SHA `dd5be78d…` + dmesg signature + git HEAD `e19ae163`

---

## 2026-06-10 (session 2) — BUILD B bench result: 0x1c — clock fix worked, booster still off

**Agent:** A1 (Claude Code — analysis + doc update)

### BUILD B On-Target Result

**WIC:** `…20260610170030.wic` / SHA `dd5be78d…` / git `e19ae163` — BUILD B (FAE page-4 clock fix)  
**Bench:** Owner flashed and booted. `dmesg` confirmed:

```
[3.649868] jadard: FAE page-4 clock fix (pre-SLPOUT)
[3.850310] jadard: GET_POWER_MODE(0x0A) pre-TE=0x1c
[3.863667] jadard: FAE TE on (0x35,0x00)
[3.863712] jadard: init table: 196 cmds, rc=0
```

**VDDIN:** Owner reports 3.3V constant on DMM.  
**Glass:** Still backlit black.

### Analysis

`0x1c` decoded vs BIST v1 `0x18`:

| Bit | Mask | BIST v1 | BUILD B | Change |
|-----|------|---------|---------|--------|
| 7 | 0x80 | 0 | 0 | Booster still OFF |
| 4 | 0x10 | 1 | 1 | Sleep-out ✓ |
| 3 | 0x08 | 1 | 1 | Normal mode ✓ |
| **2** | **0x04** | **0** | **1** | **DISON now ACKed — clock fix worked** |

**Conclusion:** The FAE page-4 clock fix had a real, measurable effect — the panel now properly acknowledges DISON. This proves MIPI communication is reliable enough for full command delivery. However, the booster (JD5001 charge pump for AVDD/AVEE/VGH/VGL) never started in either build. Two hypotheses remain:

- **H1 (supply):** VDDIN 3.3V static on DMM. DMM response time (~250ms) cannot see 10-50ms booster startup transient. At 200mA through a 2Ω Plan B wire, VDDIN sags to 2.9V (below JD5001 UVLO). **Ammeter test is the definitive kill test.**
- **H4a (missing init register):** Reading the vendor init table (`library/LMT101/LMT101SX006C initial codes.txt`): page-1 (`E0,01`) block does NOT write register `E3`. The FAE BIST sequence explicitly writes `E0,01` → `E3,01` after DISON. In JD9365D, page-1 `E3` may enable the source driver or power stage beyond just "BIST self-test." If `E3` (page 1) is needed to enable the charge pump and the standard init doesn't write it, the booster never starts.

### Immediate next steps

1. **Ammeter inline VDDIN** — connect bench supply 3.3V/1A to FPC pins 2/3, watch current at SLPOUT (~3.65s). No current step = H4 domain. Spike-then-collapse = H1 domain.
2. **Resistance of Plan B bypass wire** (board OFF, ohmmeter, VCC3V3_SYS → FPC pin 2): should be <0.3Ω.
3. **Send updated vendor email** (docs/VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL-2.txt) — share 0x1c result, ask specifically about `E3` (page 1) and whether a register beyond the standard init table is required to start the charge pump.
4. **Build + flash TASK-136 (Phase L)** — **patch 0015 now in-tree** (A2 2026-06-10 session 3). No owner ACK blocker — `bbappend` already updated. Next rebuild will include DCS reads for `0x04`, `0x0F`, `0x45`.

### DRM / software state confirmed (session 3 checks)

Owner ran full software audit on BUILD B running image. All clean:
- `gpio-15` (vcc3v3-lcd0-n): `out hi` ✓; `gpio-22` (reset): `out hi ACTIVE LOW` ✓
- DSI-1 connector: `connected` ✓
- `crtc[112] video_port1`: `enable=1 active=1` ✓; mode `800x1280@60 clk=70MHz` ✓
- `plane[96] Smart1-win0`: `fb=192 XR24 800x1280 on video_port1` ✓
- DRM summary: `bus_format[100a]=RGB888_1X24`, `real_clk[70000]` — exact match to descriptor ✓
- DSI-1 debugfs: no MIPI error counters exposed (Rockchip 6.1 dw-mipi-dsi does not export them)
- All `dmesg fail|error` messages: benign (probe defer, unused modules, absent DT entries)

**Software investigation: FULLY CLOSED.** Problem is hardware (H1) or panel-side register (H4a). Patch 0015 (DIAG15) provides the next software diagnostic gate via `0x0F` self-diagnostic byte.

### Software checks (no reflash, BUILD B running)

```bash
mount -t debugfs none /sys/kernel/debug 2>/dev/null || true
echo "=== regulators ==="
cat /sys/kernel/debug/regulator/vcca_1v8/enable 2>/dev/null && echo "vcca_1v8 ok"
cat /sys/kernel/debug/regulator/vcc3v3-lcd0-n/enable 2>/dev/null && echo "vcc3v3-lcd0-n ok"
echo "=== any errors ==="
dmesg | grep -E '(jadard|vcc|regul|1v8)' | grep -iE '(fail|error|WARN)' | head -10
echo "=== jadard full ==="
dmesg | grep -i jadard
```

---

## 2026-06-06 — BUILD A (FAE BIST) image built and ready to flash

**Host:** TASK-002-class, `kas shell` — **exit 0**

| Artifact | Path |
|----------|------|
| **WIC (flash this)** | `build/tmp/deploy/images/elevator-hmi-em3566/core-image-minimal-elevator-hmi-em3566.rootfs-fae-bist.wic` |
| Timestamped | `…rootfs-20260606144313.wic` |
| **SHA-256** | `1a2e4bec2d27af2d46670b91d39aaf0005797c5ef6baae40fc8dba5dd42c6c8a` |
| Kernel | patches **0011+0012** (BIST `enable_seq`); strings confirm **`FAE BIST enable sequence`** |

**Flash:** `sudo rkdeveloptool wl 0 build/tmp/deploy/images/elevator-hmi-em3566/core-image-minimal-elevator-hmi-em3566.rootfs-fae-bist.wic` (see `docs/FLASH-PROCEDURE.md`).

**After boot:** `dmesg | grep -i jadard` → report **glass pattern yes/no** (BIST diagnostic).

---

## 2026-06-02 — FAE reply: BIST + page-4 clock fix patches (BUILD A / BUILD B)

**Agent:** A2 (Cursor)

### Vendor response (LCD Mall FAE)

Two tests — **run BIST first**, then clock fix (never combined):

1. **Page-4 clock** before `0x11`: `E0,04` / `37,58` / `35,08` / `36,49` / `2C,06` / `E0,00` → existing `0x11`/120ms/`0x29`/5ms → **`35,00`** (TE).
2. **BIST** after `0x11`/`0x29`: `F0,55` / `F1,AA` / `E0,01` / `E3,01`.

FAE: MIPI rate mismatch can cause “failure to light up” — aligns with **468 vs 420 Mbps** gap (`docs/LMT101-CLOCK-RATE-AUDIT.md`). **`0x0A=0x18`** = sleep-out without display-on bit.

### Implemented (in-tree)

| Patch | Role |
|-------|------|
| **0011** | Driver: `FAE_BIST` + `FAE_CLOCK` enable_seq paths |
| **0012** | Descriptor → **BUILD A** (active in `bbappend`) |
| **0013** | Descriptor → **BUILD B** (swap in `bbappend` after BIST) |

**Docs:** `docs/FAE-BIST-CLOCK-BUILD.md`, `docs/LMT101-CLOCK-RATE-AUDIT.md`

### Owner next steps

1. Rebuild + flash **BUILD A** (BIST) — report glass pattern yes/no.
2. Swap `bbappend` to **0013**, rebuild, flash **BUILD B** — re-read `0x0A`, modetest plane 96.

---

## 2026-06-02 — Session close: LMT101 software lab PASS, backlit black — vendor mail + BLK-014

**Agent:** A2 (Cursor) + owner bench

### Summary

Completed end-to-end **Linux display stack** validation on **EM3566 v3 + LMT101SX006C**. All software gates **PASS**; panel shows **backlit black only** (external **~9 V** backlight). **Software lab closed** for this phase; next gate is **vendor FAE** + **MIPI scope**, not more userspace iteration.

### Hardware (confirmed)

- **Plan B:** `VCC3V3_SYS` → CON1 **5/6** (~3.3 V on VDDIN).
- **XRES:** FPC pin **5** → CON1 pin **11** → **GPIO0_C6** (**gpio-22**, active-low).
- **Backlight:** external **~9 V** on LED string (bench).
- **MIPI:** 4-lane D0–D3 + CLK on CON1 per carrier.

### Firmware / DTS (in-tree)

- `reset-gpios = <&gpio0 RK_PC6 GPIO_ACTIVE_LOW>`; `&spi0` disabled; `&gt1x` disabled.
- Image class: **TASK-133** WIC + jadard patches through **0010** (vendor Q1 reset, trace, DCS **0x0A** read).

### Software evidence (PASS)

| Layer | Result |
|--------|--------|
| Boot `jadard` | gpio-22; XRES assert/release ~3.5 s; **196 cmds rc=0**; SLPOUT/DISON; **GET_POWER_MODE(0x0A)=0x18**; **mode_flags=0x203** (video+burst, 4 lane) |
| DSI | **468 × 4 Mbps** |
| DRM | Connector **191**, CRTC **112**, **800×1280@60.08** |
| Plane | **96** `Smart1-win0`, **fb=192** XR24, **fbcon** |
| Test | `modetest -M rockchip -s 191@112:#0 -P 96@112:800x1280+0+0 -F tiles -v` → **freq: 60.08Hz** sustained; **no pixels on glass** |
| fb0 | Full white fill — **no visible change** |

### Blockers / tasks

- **BLK-006** → **Closed** (reset on **PC6**, dmesg pulse OK).
- **BLK-014** → **Opened** (backlit black with full scanout).
- **TASK-106** → **`[TESTING]`** — software bench complete; display gate blocked on **BLK-014**.
- **Vendor:** `docs/VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL.txt` updated for **2026-06-02** — send to **sales06@alltouchdisplay.com**.

### Next actions (owner / A1)

1. Email vendor (attach `docs/VENDOR-SUPPORT-LMT101-BRINGUP.md` if useful).
2. Scope **MIPI CLK + D0** @ boot **~3.5 s** and during **`modetest -v`** run.
3. Optional future TASK: non-burst DSI, DCS **0x04** panel ID — **new spec only**.

---

## 2026-05-21 — A1: patch 0008 — jadard reset sequence bug found and fixed (hardware unblocked)

**Agent:** A1 (Lead — Claude Code)

### Context

Owner confirmed: 3.3 V direct-wire to LMT101 FPC pins 2/3 (VDDIN), RESET on CON1 pin 11 (gpio0 RK_PB6), all MIPI lanes wired, 9 V backlight on VLEDA. Panel has valid power for the first time. A1 audited all driver patches to verify the initialization sequence is correct before the owner flashes.

### Critical bug found in jadard_prepare() reset sequence

**Root cause:** Patches 0002+0007 produced a 3-step sequence that, with `GPIO_ACTIVE_LOW` in the DTS, drives XRES asserted (physical LOW) for the final 120 ms hold — while `jadard_enable()` fires and sends MIPI init commands. The panel cannot respond while XRES is asserted.

**Physical pin timeline before fix:**
```
initial HIGH (deasserted, GPIOD_OUT_LOW + ACTIVE_LOW)
→ 10 ms (patch 0007 pre-power delay ✓)
→ LOW  (gpiod_set_value(1), assert)  — 5 ms
→ HIGH (gpiod_set_value(0), deassert) — 20 ms
→ LOW  (gpiod_set_value(1), assert)  — 120 ms  ← MIPI commands sent here = NO RESPONSE
```

**Root cause detail:** The original 3-step code came from the cz101b4001 driver (designed for `GPIO_ACTIVE_HIGH`). With `GPIO_ACTIVE_HIGH`, value=1 means physical HIGH = XRES deasserted. With our `GPIO_ACTIVE_LOW` (correct for XRES signal), value=1 = physical LOW = XRES asserted — the polarity is inverted, flipping the entire sequence.

**Vendor Q1 spec (authoritative):** Power On → 10 ms → XRES LOW → 20 ms → XRES HIGH → 120 ms → MIPI commands.

**Physical pin timeline after fix:**
```
initial HIGH (deasserted)
→ 10 ms
→ LOW  (gpiod_set_value(1), assert)  — 20 ms
→ HIGH (gpiod_set_value(0), deassert) — 120 ms
→ jadard_enable() fires → MIPI init commands ✓
```

### Patch audit results

| Patch | Parameter | Value in code | Vendor spec | Status |
|-------|-----------|---------------|-------------|--------|
| 0007 | Pre-power delay | 10 ms | 10 ms | CORRECT |
| 0008 | XRES pulse width | 20 ms | 20 ms | CORRECT (was wrong order) |
| 0005 | post_reset_delay (lmt101) | 120 ms | 120 ms | CORRECT |
| 0005 | display_init_delay (sleep-out → display-on) | 120 ms | 120 ms | CORRECT |
| 0005 | display_on_delay | 5 ms | 5 ms | CORRECT |
| 0006 | generic_write for init burst | present | required | CORRECT |
| 0003 | init cmd count | 196 entries | 196 entries | CORRECT |

### DTS audit

- `reset-gpios = <&gpio0 RK_PB6 GPIO_ACTIVE_LOW>` — correct (XRES is active-low)
- Physical reset sequence after patch 0008: HIGH(init) → 10ms → LOW(20ms) → HIGH(120ms) → MIPI ✓
- `dsi-lanes = <4>` ✓
- `dsi-format = <0>` (RGB888) ✓
- Default DTB: `elevator-hmi-boardcon-em3566-v3.dts` includes `&vcc3v3_lcd0_n` active-low fragment (TASK-132/TASK-133)

### Fix: patch 0008

Created `meta-hmi-platform/recipes-kernel/linux/files/0008-drm-panel-jadard-lmt101sx006c-timing-final.patch`. Added to `linux-rockchip_%.bbappend` after patch 0007. The patch removes the spurious first assert+deassert cycle and corrects the sequence to: assert(20ms) → deassert → msleep(post_reset_delay=120ms).

### Build result

```
bitbake virtual/kernel + core-image-minimal → exit 0
4391 tasks, all succeeded, 4 WARNING (taint-only)
WIC: core-image-minimal-elevator-hmi-em3566.rootfs-20260521203230.wic
```

### Flash command for owner

```bash
rkdeveloptool db build/tmp/deploy/images/elevator-hmi-em3566/u-boot-rockchip-elevator-hmi-em3566.bin
rkdeveloptool wl 0 build/tmp/deploy/images/elevator-hmi-em3566/core-image-minimal-elevator-hmi-em3566.rootfs-20260521203230.wic
rkdeveloptool rd
```

### Next

Owner to flash and observe `dmesg` for:
- `jd9365da-h3` probe success (no `-EPROBE_DEFER`)
- `dw-mipi-dsi-rockchip` link up
- Run `modetest -M rockchip -s <connector_id>:<mode>` for pixel output
- If black: check `dmesg` for `init cmd 0x` failures (patch 0006 logs generic_write errors)

---

## 2026-05-21 — A2 session closure (**TASK‑132**/TASK‑133): hardware power‑switch fault isolated (`develop` freeze)

**Agent:** A2 (Composer2) — **session wrap-up (**A1** directive)**

**A1 handoff line:**
> Hardware Power Switch Failure Confirmed: Software path (TASK-132) confirmed correct (Pin 13 @ 0V), but hardware rail (Pin 5/6 @ 0.8V). Awaiting Plan B hardware bypass wire.

### Lab sign-off (**owner evidence → A1**)

**Hardware power switch failure confirmed.** Software path (**TASK‑132**) is **validated correct**: **CON1 pin 13 @ ~0 V** when enabling **`vcc3v3_lcd0_n`** ( **`GPIO0_C7`**, active‑low P‑FET “ON”). The **carrier board** still delivered **pins 5/6 @ ~0.8 V**, not ~3.3 V — definitive **carrier load‑switch analogue failure**, **not DTS / Yocto**. **Awaiting Plan B hardware bypass wire** (**`VCC3V3_SYS` → pins 5/6**, **`BLK-013`** / **`BLOCKERS`**).

### Repo / branch

- **Canonical branch:** **`task/TASK-132-vcc3v3-lcd0-active-low-pfet`** (**HEAD** on this clone). **`origin` push blocked** here (SSH **`Permission denied`**) — from a credentialled workstation run **`git push -u origin task/TASK-132-vcc3v3-lcd0-active-low-pfet`**; optionally **`git push -u origin task/TASK-133-revert-pmic-fix-pfet`** to keep **`TASK‑133`** in lockstep (**same `HEAD`**). DTS = **TASK‑132** polarity + **TASK‑133** **`vcca_1v8`** / **`LDO_REG7`** delete.
- **`docs/FLASH-PROCEDURE.md`** + **`diary/BLOCKERS.md`**: defective reference carrier wording finalized.
- **WIC artefact (**example, host build **2026‑05‑20**):** **`build/tmp/deploy/images/elevator-hmi-em3566/core-image-minimal-elevator-hmi-em3566.rootfs-20260520203942.wic`** — rebuild after pull if DTS changed (**`kas shell …`** in FLASH).

### Tonight / tomorrow (**A1**)

- No further **`bitbake`** tonight.
- Tomorrow: **Plan B** jumper **or** swap carrier → then DSI / **`jadard`** (**TASK‑106**, **TASK‑125**).

---

## 2026-05-21 — A1: Plan B architecture sign-off (**BLK-013** closure) + residual software bring-up

**Agent:** A1 (Lead — diary capture by A2/Cursor)

### Summary — power (`VCC3V3_LCD`)

- **Permanent 3.3 V bypass:** **`VCC3V3_SYS`** (upstream of the defective load switch) → **CON1 pins 5/6** is **accepted** for **Phase 0/1** reference EM3566 v3 bring-up (**industry-normal** workaround). **Production:** restore proper **rail power management** on the **carrier** (panel cannot be software-gated via **`vcc3v3_lcd0_n`** while bypassed reference hardware is used). **Implications (**A1**):** rail always on whenever board **3.3 V** present; bypass **gauge / inrush** — usually tolerable from board **3.3 V**.
- **`BLK-013`:** Closed in **`diary/BLOCKERS.md`** with wording above (**2026-05-21**). **`TASK-133`** DTS + TASK-132 polarity stay in tree for reproducibility and successor boards (`elevator-hmi-boardcon-em3566-v3.dts`).

### Summary — reset (**TASK-121**, **CON1** pin **11**, **`RK_PB6`**)

- **`jadard`** **`reset-gpios`** mapped to **`TOUCH_RST`**: **`gpiod_set_value_cansleep`** implements **timed** reset per driver/vendor (**TASK-128**/descriptor timing). Remaining residual risk (**A1**): carrier buffering vs **SoC** **`GPIO0_PB6`** unlikely per Boardcon direct-GPIO schematic reading.

### Next if panel still black

**With ~3.3 V verified at CON1 5–6**, pivot to **MIPI DSI** / **lanes** (`dsi-lanes`, `CMD_DSI_INT0`) / **`jadard`** init table (**TASK-125**, **TASK-106**) — treat **rail + GPIO reset mapping** as **settled**.

**Docs touched:** **`diary/BLOCKERS.md`** (+ **BLK-012** cross-ref tweak), **`AGENTS.md`**, **`docs/FLASH-PROCEDURE.md`** handoff table.

---

## 2026-05-20 — A2: TASK-133 emergency DTS (`vcca_1v8` board fixed + `LDO_REG7` delete) + TASK-132 P-FET kept

**Agent:** A2 (Composer2)

### Summary

- **A1 directive:** **`TASK-133`** — CM3566 has no working RK809 **`LDO_REG7`** path on bench; TASK-130 **`vcca_1v8`** via PMIC caused DSI **`dw-mipi-dsi-rockchip`** **`-517`** (**EPROBE_DEFER**) loops. Restore **`/delete-node/ LDO_REG7`** under **`&rk809`** and board-scope **`vcca_1v8`** **`regulator-fixed`** (TASK-129 architecture). Keep **`&vcc3v3_lcd0_n`** exactly as **TASK-132** (active-low P-FET, no **`vin-supply`**).
- **Branch:** **`task/TASK-133-revert-pmic-fix-pfet`** (from TASK-132 carry-forward + DTS edit).
- **Files:** **`meta-hmi-platform/recipes-kernel/linux/files/elevator-hmi-boardcon-em3566-v3.dts`**; **`AGENTS.md`** (**TASK-133** block, sprint queue, TASK-132 note corrections); **`docs/FLASH-PROCEDURE.md`** (flash **`TASK-133`** branch).
- **Build / WIC:** **`kas shell kas/elevator-hmi.yml -c "bitbake virtual/kernel -c compile -f && bitbake virtual/kernel -c deploy -f && bitbake core-image-minimal -c image_wic -f && bitbake core-image-minimal -c image_complete -f"`** → **exit 0** (taints WARN only). **`kas shell … -c "bitbake -p"`** → **exit 0**.
- **Artifact:** **`build/tmp/deploy/images/elevator-hmi-em3566/core-image-minimal-elevator-hmi-em3566.rootfs-20260520203942.wic`** · SHA-256 **`0e47eda93c97b0e80c1ae45da9a27689c54fe073bbc49bc0cdd86dfa4dbe6095`** (symlink **`…rootfs.wic`**).

---

## 2026-05-20 — A2: TASK-132 branch, comment nit, kas kernel + WIC (green)

**Agent:** A2 (Composer2)

### Summary

- **Branch:** **`task/TASK-132-vcc3v3-lcd0-active-low-pfet`** created locally ( **`git fetch origin`** failed — SSH **`Permission denied`** on this host; branch tracks current **`HEAD`**).
- **DTS:** **`&vcc3v3_lcd0_n`** comment updated — explicitly aligned with **TASK-130** (**`LDO_REG7`** / **`vcca_1v8`**, no board duplicate).
- **Build:** **`kas shell kas/elevator-hmi.yml -c "bitbake virtual/kernel -c compile -f && bitbake virtual/kernel -c deploy -f"`** → **exit 0** (forced-task **taints** WARN only).
- **WIC:** **`kas shell … -c "bitbake core-image-minimal -c image_wic -f && … -c image_complete -f"`** → **exit 0**.
- **Artifact:** **`build/tmp/deploy/images/elevator-hmi-em3566/core-image-minimal-elevator-hmi-em3566.rootfs-20260520200924.wic`** (~3.1 GiB); symlink **`…rootfs.wic`** → same.
- **TASK-132 status:** unchanged **`[TESTING]`** — **TASK-118** / **TASK-116** not started per A1 pause.

---

## 2026-05-20 — A1: TASK-132 `[REVIEW]` → `[TESTING]` (code PASS; bench gate)

**Agent:** A1 (Lead)

### Summary

- **TASK-132** (`vcc3v3_lcd0_n` active-low / EM3566 P-FET): **A1 code review PASS (pending lab).** Status **`[TESTING]`** — owner must run **`docs/FLASH-PROCEDURE.md`** **§ TASK-132 — Lab protocol (A1)** before merge to **`develop`**.
- **Verdict:** Polarity + PMIC isolation + no **`vin-supply`** documented in **`AGENTS.md`** TASK-132 **A1 review notes**.
- **`AGENTS.md`:** New coordination meaning for **`[TESTING]`**; sprint queue points to FLASH lab §.
- **`docs/FLASH-PROCEDURE.md`:** Full **Step 1–3** build / no-load gate / panel / failure table.
- **Next:** Owner bench → **`[DONE]`** + **BLK-013** closure on success; **Plan B** if **pin 13 ~0 V** but **5–6** still bad.

---

## 2026-05-20 — TASK-132: `vcc3v3_lcd0_n` active-low override (EM3566 P-FET) + docs

**Agent:** A2 (Cursor)

### Summary

- **DTS:** **`meta-hmi-platform/recipes-kernel/linux/files/elevator-hmi-boardcon-em3566-v3.dts`** — **`&vcc3v3_lcd0_n`** (**TASK-132**); **`&rk809`** keeps **`LDO_REG7`** / PMIC **`vcca_1v8`** (removed **`/delete-node/ LDO_REG7`** and board duplicate **`vcca_1v8`** per **TASK-130**). **`#include`** gpio + rockchip bindings. No **`vin-supply`** on fragment (**TASK-131**).
- **BLOCKERS:** **`diary/BLOCKERS.md`** — **BLK-013** text updated (DT mitigation + Plan B fallback).
- **Docs:** **`docs/FLASH-PROCEDURE.md`** — TASK-132 verification section; TASK-129 section marked historical.
- **AGENTS:** **TASK-132** **`[REVIEW]`** with acceptance criteria (**CON1 5–6 ~3.3 V**, **`gpio-23`** **`out lo`**, no DSI **`-517`** storm).
- **Owner next:** **`bitbake virtual/kernel`** (or full WIC), flash, run verification; paste results → A1 sets **`[DONE]`** / close **BLK-013** if pass.

---

## 2026-05-20 — Revert DTS workspace to TASK-129 branch snapshot

**Agent:** A2 (Cursor)

### Summary

- **Reason:** Bench **`dmesg`** still showed **DRM / rockchip-vop2 / dwhdmi-rockchip / dwmmc** lines **repeating** (**display-subsystem** rebind / deferred-probe churn). User requested rollback **beyond TASK-130/TASK-131**.
- **Action:** Checked out **`meta-hmi-platform/recipes-kernel/linux/files/elevator-hmi-boardcon-em3566-v3.dts`** from git branch **`task/TASK-129-vcc3v3-lcd0-pfet-polarity`** (restores **`/delete-node/ LDO_REG7`** under **`&rk809`** plus board-scope **`vcca_1v8`** **`regulator-fixed`**). **`linux-rockchip_%.bbappend`** / **`elevator-hmi-em3566.conf`** already referenced a **single** **`elevator-hmi-boardcon-em3566-v3.dtb`** — no TASK-131 lcdrail **`*.dtsi`** in **`files/`** on this checkout.
- **Docs:** **`docs/FLASH-PROCEDURE.md`** — obsolete TASK-131 **triple-DTB** swap section replaced with **TASK-129 baseline** + “rebuild + flash **new** WIC timestamp” reminder.
- **Caveats:** Revives TASK-129 **RK809/LDO_REG7** handling (**TASK-130** had documented why PMIC **LDO_REG7** is **`vcca_1v8`**, not **VCC3V3_LCD**). **`&vcc3v3_lcd0_n`** P‑FET **DT fragment** described in **`AGENTS.md`** TASK-129 output notes **is absent** from the TASK-129 **git** DTS (only backlight **`power-supply = <&vcc3v3_lcd0_n>;`**); add **`&vcc3v3_lcd0_n`** override only under a new task/spec if bench needs it.
- **Kernel build:** **`kas shell kas/elevator-hmi.yml -c "bitbake virtual/kernel -c compile -f && bitbake virtual/kernel -c deploy -f"`** → **exit 0**. **`elevator-hmi-boardcon-em3566-v3.dtb`** SHA256 **`54f07dba885b86b00e4d210110ce353dc686df6d1d8930a71824d3f365364972`** (**TASK-129 DTS**).
- **`core-image-minimal` WIC:** **`kas shell kas/elevator-hmi.yml -c "bitbake core-image-minimal -c image_wic -f && bitbake core-image-minimal -c image_complete -f"`** → **exit 0** (2026-05-20). **`core-image-minimal-elevator-hmi-em3566.rootfs-20260520184237.wic`** · SHA-256 **`ee9866c538420d7befc149be953bef7a358591724020230171ddbf3a47635069`**. Stable symlink **`core-image-minimal-elevator-hmi-em3566.rootfs.wic`**.
- **Flash:** See **`docs/FLASH-PROCEDURE.md`** (**Steps 2–5**: deploy dir, **`rkdeveloptool`** **`wl`** / **`rd`**).

---

## 2026-05-20 — TASK-115: `elevator-hmi-image` parse smoke test (A1)

### Summary

- **Yocto Recipe Parse**: Ran `kas shell kas/elevator-hmi.yml -c "bitbake -p elevator-hmi-image"` successfully.
- **Result**: Checked 2587 `.bb` files (2582 cached, 5 parsed), 4482 targets, 360 skipped, 0 masked, 0 errors. Exit 0.

---

## 2026-05-18 — A1: TASK-131 `[DONE]` review & WIC Build Complete

**Agent:** A1  
**Phase:** 1

### Review verdicts

- **TASK-131 `[DONE]`** — The `vin-supply` removal is correct and complete. The comment in the dtsi documents the regression cause precisely.
- **Verification:** `grep -r "vin-supply"` on the DTSI fragments returns no output. The rework is structurally sound.
- **WIC Rebuild:** WIC rebuild is complete (`exit 0`). The flashable WIC with all three DTBs on the boot partition is ready.

### Next Steps — Owner

**Step 1:** The board is running the stable TASK-130 image. Do not reflash anything yet.
Power off the board completely. Disconnect the FPC adapter from CON1. Power on. Boot to login prompt. Then probe **CON1 pin 5 to CON1 pin 3** with your multimeter.

- If ~3.3V: Adapter has GND short. Do not flash TASK-131. Fix adapter wiring instead.
- If 0V: Board circuit issue confirmed. Flash TASK-131 rework WIC, test both DTBs.

**Lab update (2026-05-20):** **`elevator-hmi-boardcon-em3566-v3.dts`** in **`meta-hmi-platform`** rolled back to **TASK-129** (**`task/TASK-129-vcc3v3-lcd0-pfet-polarity`**) snapshot. **`docs/FLASH-PROCEDURE.md`** no longer documents TASK-131 **multi-DTB** swap. Prefer a **fresh** **`core-image-minimal`** WIC from this tree (plus **`idblock`**/**`uboot`**) vs older artefacts.

---

## 2026-05-18 — TASK-131 `[REWORK]`: drop `vin-supply` on `vcc3v3_lcd0_n` (DSI `-517` loop)

**Agent:** A2 (Cursor)  

### Summary

- **Cause (A1):** First TASK-131 image used **`vin-supply = <&vcc3v3_sys>`** on **`vcc3v3_lcd0_n`** with **`regulator-always-on`** → regulator/DRM **deferred probe** churn (**`failed to find panel or bridge: -517`**, repeating).  
- **Fix:** Remove **`vin-supply`** from **`elevator-hmi-boardcon-em3566-v3-lcdrail-active-low.dtsi`** and **`…-active-high.dtsi`**; keep split DTS, dual polarity, **`regulator-always-on`**, voltage min/max, three DTBs.  
- **Owner:** Restore **TASK-130** WIC (**`…rootfs-20260518192215.wic`**); **do not** flash pre-rework TASK-131 WIC. **Step 1:** power off, **disconnect FPC**, boot, measure CON1 **5→3** at login — **before** any TASK-131-rework flash.  
- **Build (rework):** **`kas shell kas/elevator-hmi.yml -c "bitbake virtual/kernel -c compile -f && bitbake virtual/kernel -c deploy -f"`** → **exit 0** (2026-05-18; expected **`-f`** taint warnings). Deploy DTB SHA256 **`elevator-hmi-boardcon-em3566-v3.dtb`** / **`…-active-low.dtb`:** `319f04987b9e60a56d8125c0f86544016f735dfbfe64958d6e6eed19f64025f8`; **`…-active-high.dtb`:** `a998e3cdff56c64c9b305525e786435d6adbb4d73bfff5a0237fffe77fd37d5c`. Source lcdrail **`.dtsi`** files: **`git grep vin-supply`** under `files/` → **none** (remaining **`vin-supply`** / **`vcc3v3_sys`** strings in DTB are **other** nodes). **WIC:** not rebuilt — run **`image_wic`** / **`image_complete`** when a flashable image is needed post–Step 1.

---

## 2026-05-18 — TASK-131: Dual `vcc3v3_lcd0_n` DTBs (`vin-supply` + polarity A/B) *[first pass — withdrawn; see rework above]*

**Agent:** A2 (Cursor)  
**Phase:** 1  

### Summary

- Split **`elevator-hmi-boardcon-em3566-v3.dts`** into **`elevator-hmi-boardcon-em3566-v3-board.dtsi`** + **`elevator-hmi-boardcon-em3566-v3-lcdrail-active-{low,high}.dtsi`**; wrappers **`elevator-hmi-boardcon-em3566-v3-active-{low,high}.dts`**. **`v3.dts`** == active-low (**`TASK-131`** experiment).  
- Lcdrail: **`vin-supply = <&vcc3v3_sys>;`**, **`regulator-{min,max}-microvolt = <3300000>;`**, **`regulator-always-on;`**. Active-low **`GPIO_ACTIVE_LOW`** + **`/delete-property/ enable-active-high;`**. Active-high **`GPIO_ACTIVE_HIGH`** + **`enable-active-high;`**.  
- **`elevator-hmi-em3566.conf`:** three **`KERNEL_DEVICETREE`** entries; **`IMAGE_BOOT_FILES`** deploys **`Image`** + three **`.dtb`**. **`docs/FLASH-PROCEDURE.md`:** § **TASK-131 — DTB swap**.  
- **WIC:** **`core-image-minimal-elevator-hmi-em3566.rootfs-20260518202247.wic`**. **`…v3.dtb`** SHA256 **`37ce76bfb…`** (matches **`…active-low.dtb`**); **`…active-high.dtb`** **`ecf395a49…`**.  

### Owner

- **Before flash:** adapter / flex **Step 1** continuity (isolate GND short). Swap DTB blob on **`p1`** per FLASH-PROCEDURE; measure CON1 **5→3** at login — matrix in **TASK-131** **`AGENTS.md`**.

---

## 2026-05-18 — A1: TASK-130 `[DONE]` review & Hardware Defect Conclusion

**Agent:** A1  
**Phase:** 1

### Review verdicts

- **TASK-130 `[DONE]`** — A2's BSP finding is correct. LDO_REG7 in the BSP is `vcca_1v8` at 1.8V, not `VCC3V3_LCD`. Removing the `/delete-node/ LDO_REG7`, removing the fixed `vcca_1v8` duplicate, and reverting the TASK-129 `&vcc3v3_lcd0_n` override are all PASS. PMIC LDO7 (vcca_1v8, 1.8V) is now restored, fixing the broken DSI PHY analog supply (broken since TASK-120). BSP default (enable-active-high) for `vcc3v3_lcd0_n` is restored, which is correct for GPIO0_C7.
- **TASK-129 `[SUPERSEDED]`** — Superseded by TASK-130.

### State of play — Hardware Defect

- TASK-130 fixes a real bug (broken DSI PHY analog supply), but it does not fix VCC3V3_LCD.
- Pure software explanations for why GPIO0_C7 produces 0V on CON1 pins 5/6 have been exhausted.
- **Conclusion:** The switching component on the EM3566 v3 PCB between VCC3V3_SYS and CON1 is not responding to GPIO control. This requires the **Plan B hardware wire**.

---

## 2026-05-11 — TASK-129: LCD rail P-FET polarity (`vcc3v3_lcd0_n`) + same WIC as `0007`

**Agent:** A2 (Cursor)  
**Phase:** 1  

### Summary

- **`elevator-hmi-boardcon-em3566-v3.dts`:** **`&vcc3v3_lcd0_n`** — **`/delete-property/ enable-active-high;`** (BSP drove GPIO0_C7 HIGH when “enabled”; EM3566 v3 keeps P-FET **off** when gate is HIGH) + **`regulator-always-on;`** so **`VCC3V3_LCD`** is up at login without a DRM client.
- **`0007`** (`TASK-128` `jadard` rail delay / 20 ms RESX low) unchanged in **`linux-rockchip_%.bbappend`** — same image.
- **Build:** `kas shell …` → **`virtual/kernel`** compile/deploy + **`core-image-minimal`** `image_wic` / `image_complete` — exit **0** (expected BitBake **`‑f`** taint warnings).
- **DTB check (host):** decompiled **`vcc3v3-lcd0-n`** has **`regulator-always-on`**, no **`enable-active-high`** property on that node.

### Artefact

- **`build/tmp/deploy/images/elevator-hmi-em3566/core-image-minimal-elevator-hmi-em3566.rootfs-20260511162809.wic`** (symlink **`…rootfs.wic`**).

### Owner

- **`diary/BLOCKERS.md`:** **BLK-012** closed — root cause inverted enable polarity vs P-FET; earlier “black panel” assumed panel logic power (**reopen `dmesg` / image** narrative after TASK-129 flash).

---


**Agent:** A2 (Cursor)  
**Phase:** 1  

### Summary

- **`0007-drm-panel-jadard-lmt101sx006c-reset-powerup-delay.patch`:** after **`regulator_enable(vccio)`** and **`vdd`**, **`msleep(10)`** before reset GPIO; **`msleep(20)`** with vendor comment for XRES active-low width (was 10ms).
- **`linux-rockchip_%.bbappend`:** **`0007`** in **`SRC_URI`** after **`0006`**.
- **Build:** kernel compile/deploy + **`core-image-minimal`** WIC — exit **0**.

### Owner

- **Vendor Q1 alignment:** full **[rail-delay → RESX sequence]** per LCD Mall; **multimeter** checks **(FPC 2–4, 5–4)** before flash (see project connection table).

---

## 2026-05-10 — A1: TASK-125 + TASK-126 + TASK-127 `[DONE]` — corrected BLK-012 diagnosis

**Agent:** A1  
**Phase:** 1

### Review verdicts

- **TASK-125 `[DONE]`** — Vendor init array (196 pairs from LCD Mall), 4-lane CMD_DSI_INT0, descriptor timings, DTS `dsi-lanes = <4>`, clean build.
- **TASK-126 `[DONE]`** — Descriptor-driven timing fields in `jadard_panel_desc`; `lmt101sx006c_desc` = 120/0/120/5 ms matching vendor tail. Architecturally correct.
- **TASK-127 `[DONE]`** — `jadard_init_sequence()` replaces old `mipi_dsi_dcs_write_buffer` loop with `mipi_dsi_generic_write()` (MIPI packet type 0x23). Verified via `grep -n "^+" 0006-*.patch | grep mipi_dsi` — only `mipi_dsi_generic_write` in addition lines; `mipi_dsi_dcs_write_buffer` only in deletion lines. `dev_err` on failure gives dmesg visibility. Sleep Out / Display On / `0xE0` page-select remain DCS writes (correct).

### BLK-012 corrected root cause

TASK-126's A2 output note confirms timing values were **already in effect** during the backlit-black bench test. **BLK-012 is NOT a timing defect.** Narrowed to: (1) DCS command acceptance — look for `DRM_DEV_ERROR` / `init cmd 0x.. failed` in dmesg after TASK-127 flash; (2) `reset-gpios` polarity (BLK-006); (3) hardware.

### Next

- **Owner: flash immediately** — the 2026-05-10 WIC with `0006` is the first image that will report individual init command failures in `dmesg` (via `jadard_init_sequence()` → `dev_err`). Run `modetest -M rockchip -s 191:#0` and capture **full `dmesg`**.
- A2: pick up **TASK-115** (Qt image parse smoke).

---

## 2026-05-10 — TASK-127: `jadard` init table via `mipi_dsi_generic_write` (`0006`)

**Agent:** A2 (Cursor)  
**Phase:** 1  

### Summary

- **`0006-drm-panel-jadard-use-generic-write-for-init.patch`:** **`jadard_init_sequence()`** replaces **`mipi_dsi_dcs_write_buffer`** on the vendor init loop with **`mipi_dsi_generic_write`** + **`dev_err`** on error; **`#include <linux/kernel.h>`** for **`ARRAY_SIZE`**. Sleep-out / display-on / E0 tail unchanged.
- **`linux-rockchip_%.bbappend`:** **`0006`** in **`SRC_URI`** chain.
- **Build:** full **`virtual/kernel`** + **`core-image-minimal`** WIC — exit **0**.

---

## 2026-05-09 — TASK-126: `jadard` LMT101 per-panel init timings (`0005`)

**Agent:** A2 (Cursor)  
**Phase:** 1  

### Summary

- **`0005-drm-panel-jadard-lmt101sx006c-init-timing.patch`:** **`jadard_panel_desc`** timing fields; **`lmt101sx006c_desc`** **120 / 0 / 120 / 5** ms; **`cz101b4001_desc`** **`.post_reset_delay = 120`** (avoids **5 ms** fallback when unset).
- **`linux-rockchip_%.bbappend`:** **`SRC_URI`** **`0005`** after **`0004`**.
- **WIC:** symlink **`build/tmp/deploy/images/elevator-hmi-em3566/core-image-minimal-elevator-hmi-em3566.rootfs.wic`** → **`…20260510140051.wic`** (~3.1 GiB).

---

## 2026-05-09 — docs: vendor support email (plain text)

**Agent:** A2 (Cursor)  
**Phase:** 1  

### Summary

- **`docs/VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL.txt`:** RFC-style **To/From/Subject** + full **plain-text body** derived from **`VENDOR-SUPPORT-LMT101-BRINGUP.md`** (tables → ASCII). Linked from **`VENDOR-SUPPORT-LMT101-BRINGUP.md`** and **`README.md`**.

---

## 2026-05-09 — docs: vendor support brief (LMT101 bring-up)

**Agent:** A2 (Cursor)  
**Phase:** 1  

### Summary

- **`docs/VENDOR-SUPPORT-LMT101-BRINGUP.md`:** single **vendor-facing** message — **CON1/FPC → DT/driver → on-target verification matrix** + **symptoms** (backlit black, sysfs vs bench) + **numbered questions** for LCD Mall / display vendor. Linked from **`README.md`** and **`library/LMT101/README.md`**.

---

## 2026-05-09 — test-display: sysfs `max_brightness` (not `max`)

**Agent:** A2 (Cursor)  
**Phase:** 1  

### Summary

- **`test-display`:** Linux backlight class exposes **`max_brightness`**; using **`max`** produced **`max=?`** and skipped the **set-to-max** loop (`**-r "$b/max"**` never true). Fixed **`bl_max_path`** helper + **`PV = 1.0.3`**. Added note that **killing** background **`modetest`** may leave DRM idle — manual **`modetest -s`** for sustained picture.

---

## 2026-05-07 — BLK-012: black panel + owner “backlit-black” nuance

**Agent:** A2 (Cursor)  
**Phase:** 1  

### Summary

- **`BLK-012` / `BRINGUP`:** **Owner lab:** turning on **external backlight power** gives **visible glow** (**backlit-black**), not “off black.” **`/sys/class/backlight`** tweaks may show **no visible change** when the LED path is **hard-on** from the bench or **`LCD_BL_PWM`** is not in the analogue dimming chain — **routing**, not proof Linux is wrong. **Backlit-black** prioritizes **pixel / panel state** (**`fb0`** paint, **`reset-gpios`** / **BLK-006**, `jadard` display path) over “add more DCS bytes.”
- Prior **BLK-012** text: green DRM/DSI; **not** MIPI-CSI2 camera noise.

---

## 2026-05-07 — `test-display` BusyBox/modetest fix + black-panel doc note

**Agent:** A2 (Cursor)  
**Phase:** 1  

### Summary

- **`test-display` script:** removed `**modetest … | head -40`** (BusyBox rejects `**head -40**`; pipeline **stalls** when `**head**` waits for 40 lines while `**modetest -s**` blocks after one line). Now: **3 s** background `**modetest**`, log to `**/tmp**`, `**head -n 15`** log, then backlight max + regulator as before.
- **`test-display` recipe:** **`PV = 1.0.2`** (`**test-display_1.0.bb`**).
- **`docs/BRINGUP-CHECKLIST.md`:** §5.1 **BusyBox/modetest** notes (Ctrl+C expected for foreground `**modetest -s`**); black-panel paragraph when **§5.2** passes → **bench backlight / XRES**, not CSI2 camera noise.

---

## 2026-05-07 — BRINGUP: §5.2 LCD parameters (console Q&A)

**Agent:** A2 (Cursor)  
**Phase:** 1  

### Summary

- **`docs/BRINGUP-CHECKLIST.md`:** new **§5.2 — On-board: LCD firmware parameters (console Q&A)** — for each firmware concern (**A** kernel config **CONFIG_DRM_PANEL_JADARD_JD9365DA_H3**, **B** `mipi-dsi` **uevent** / compatibles, **C–D** `modetest` connector + modeset, **E–J** `dmesg` / debugfs / backlight / **gt1x**, **K** optional **MD5** Image+DTB vs deploy). Includes one-shot copy-paste sweep and **BLK-006** note (reset polarity not verifiable from shell).
- **§5** intro bullet points to **§5.2** for scripted checks.

---

## 2026-05-07 — LMT101 vendor file canonical + init verification

**Agent:** A2 (Cursor)  
**Phase:** 1  

### Summary

- **`library/LMT101/LMT101SX006C initial codes.txt`** — copied from workspace root; **`.gitignore`** whitelists this file for version control (see **`library/LMT101/README.md`** index).
- **Verification:** Parsed vendor **`{0xRR,1,{0xVV}}`** lines through **`0xE7,0x0C`** (**196** pairs) and compared to **`0003-drm-panel-jadard-lmt101sx006c-vendor-init.patch`** `**lmt101sx006c_init_cmds[]`:** **exact match** (register and data bytes).
- **Docs:** **`AGENTS.md`** — superseded **TASK-123** / **TASK-124** replaced with short pointers to **TASK-125** + vendor file only; **TASK-122** review “next step” points to **TASK-125**; patch header comment cites **`library/.../LMT101SX006C initial codes.txt`** (no unofficial init sources).

### Bench (if still no picture)

Reflash latest WIC + DTB; **`modetest -M rockchip`** on the **DSI** connector that enumerates **800×1280**; set **`/sys/class/backlight/*/brightness`** to **`max`**; capture **`dmesg`** for **jd9365** / **dsi** / **panel** / **drm**.

---

## 2026-05-09 — TASK-125: vendor LMT101SX006C init ported (A2)

**Agent:** A2 (Cursor)  
**Phase:** 1  

### Summary

- **Source:** `**library/LMT101/LMT101SX006C initial codes.txt`** (LCD Mall official JD9365D init).
- `**{0x80, 0x03}**` = **4** MIPI lanes: **JD9365D CMD_DSI_INT0** bits[1:0] **11** (**not** three lanes — earlier TASK-125 draft text was incorrect). Matches **four** routed data lanes (**D0–D3**) + clock on CON1 harness.
- **TASK-124** injected `**{0x80, 0x11}**` ⇒ bits **01** ⇒ **2** lanes — contradictory to carrier **4-lane** video and vendor table.
- `**lmt101sx006c_init_cmds[]`:** **196** `{ reg, val }` pairs (`**jadard**` format); ends `**0xE6,0x02**`, `**0xE7,0x0C**` after page-0 `**0xE0,0x00**`; **no `0x11` / delays / `0x29**` (`**jadard_panel_enable()**`).
- **Timings / clock:** vsync 4, vbp 10, vfp 30, hsync 20, hbp 20, hfp 40; **PLL_CLOCK=420** → **~69.9 MHz** ⇒ `**.clock = 70000**` (**70 MHz** mode line in `**lmt101sx006c_desc**`).
- **Integration:** `**0003**` comment block + `**.lanes = 4**`; DTS `**dsi-lanes = <4>**`, `**compatible = "elevator-hmi,lmt101sx006c"**`, `**reset-gpios = <&gpio0 RK_PB6 GPIO_ACTIVE_LOW>**` unchanged besides lane count revert.
- **BLK-011:** **[RESOLVED]** — vendor init in-tree (**2026-05-09**).

### Builds

- `kas shell … "bitbake linux-rockchip -c cleansstate"` then `bitbake virtual/kernel -c compile -f && … -c deploy -f` → **exit 0** (2026-05-09 rebuild after regenerating `**0003**`; BitBake `**-f**` taint warnings only).

### WIC

- `bitbake core-image-minimal -c image_wic -f && -c image_complete -f` → **exit 0**.
- Artefact: `**build/tmp/deploy/images/elevator-hmi-em3566/core-image-minimal-elevator-hmi-em3566.rootfs-20260509072359.wic**` (symlink `**…rootfs.wic**`).

### Next

- Owner: flash WIC → `**modetest**` / photo for **TASK-106**.

---

## 2026-05-09 — Sprint: defer TASK-118, next A2 target TASK-115 (owner)

**Agent:** A2 (Cursor)  
**Phase:** 1  

### Summary

- `**AGENTS.md`:** **TASK-118** → `**[DEFERRED]`** with owner note (prioritize **TASK-115** Qt / `**elevator-hmi-image`** parse for application layer). Sprint queue: **TASK-115** → **TASK-116**; **TASK-118** out of order until A1 re-queues.

### Next

- A2: branch `**task/TASK-115-qt-image-parse`**, run `**bitbake -p elevator-hmi-image**`, fill output notes per **TASK-115** spec.

> **Archive note (2026-05-07):** Diary blocks dated **2026-05-08** below reference draft **`lmt101sx006c-esp32-init`** work, since replaced by **`0003-drm-panel-jadard-lmt101sx006c-vendor-init.patch`** (**TASK-125**) from **`library/LMT101/LMT101SX006C initial codes.txt`**.

---

## 2026-05-08 — TASK-124: JD9365 lane + COLMOD before LMT101 init table (A2)

**Agent:** A2 (Cursor)  
**Phase:** 1  

### Summary

- `**0003-drm-panel-jadard-lmt101sx006c-esp32-init.patch`:** Immediately after `**0xE3 0xF8**` unlock, `**lmt101sx006c_init_cmds**` gains `**{ 0x80, 0x11 }**` (4-lane DSI) and `**{ 0x3A, 0x77 }**` (RGB888) before `**0xE0 0x01**` page-1 transition — matches ESP32 pre-table behavior per **TASK-124**. Driver comment cites **TASK-124**; unified-diff hunk lines corrected.
- **Build:** `kas shell … "bitbake virtual/kernel -c compile -f && bitbake virtual/kernel -c deploy -f"` → **exit 0**.

### Next

- Owner: reflash; `**modetest**` / photo — confirm 4-lane + pixel alignment vs prior black or garbage image.

---

## 2026-05-08 — TASK-123: ESP32 JD9365 init → `jadard` `lmt101sx006c_desc` (A2)

**Agent:** A2 (Cursor)  
**Phase:** 1  

### Summary

- `**0003-drm-panel-jadard-lmt101sx006c-esp32-init.patch`:** Machine-translated `**vendor_specific_init_default**` (**168** two-byte DCS writes; omits ESP32’s trailing `**0x11` / `0x29` / `0x35**` because `**jadard_enable()**` exits sleep and turns the display on afterward). New `**lmt101sx006c_desc**` (**800×1280** / **70 MHz** timings aligned with `**cz101b4001_desc**`, **4** lanes). `**of_match`:** `**elevator-hmi,lmt101sx006c**` → `**&lmt101sx006c_desc**`.  
- `**linux-rockchip_%.bbappend`:** `**SRC_URI**` includes `**0003**` after `**0002**`.  
- `**elevator-hmi-lmt101sx006c-panel.dtsi`:** Restored product `**jadard**` node (**pre–TASK-122**): `**vdd-supply**`, `**vccio-supply**`, `**dsi-lanes**`, `**dsi-format**`, `**reset-gpios**`.  
- `**elevator-hmi-panel.cfg`:** `**CONFIG_DRM_PANEL_SIMPLE**` removed.  
- **Build:** `kas shell kas/elevator-hmi.yml -c "bitbake virtual/kernel -c compile -f"` → **exit 0**.

### Next

- Owner / **TASK-106:** reflash kernel+DTB; confirm non-black `**modetest**` / UI; `**BLK-011**` awaits bench (init source now in-tree from **Waveshare ESP32** reference, not LCD Mall-exclusive).

---

## 2026-05-08 — TASK-122: `simple-panel-dsi` DSI fallback for LMT101 (A2)

**Agent:** A2 (Cursor)  
**Phase:** 1  

### Summary

- `**elevator-hmi-lmt101sx006c-panel.dtsi`:** Switch `**panel@0**` to `**compatible = "simple-panel-dsi"**` (kernel OF match in `**panel-simple.c**`); add `**panel-timing**` **800×1280** @ **70 MHz** (same geometry as `**cz101b4001_desc**`); `**dsi,lanes` / `dsi,format` / `dsi,flags**` for video burst (**Rockchip `dt-bindings/display/drm_mipi_dsi.h**`); `**power-supply**` for `**panel-simple**` (replaces `**vdd-supply**`); keep `**backlight**`, `**TASK-121**` `**reset-gpios**`.  
- `**elevator-hmi-panel.cfg`:** `**CONFIG_DRM_PANEL_SIMPLE=y**`.  
- **Build:** `kas shell … bitbake virtual/kernel -c compile -f && -c deploy -f` → **exit 0**.  
- `**BLK-011**` (vendor `**jadard**` init array) — **unchanged**; this branch is an optional lab experiment.

### Next

- Owner: reflash; `**modetest**` and/or photo. Revert DTS to `**jadard**` + `**elevator-hmi,lmt101sx006c**` for product SKU path after test.

---

## 2026-05-08 — TASK-122 specced — LMT101SX006C JD9365D init blocked on vendor (BLK-011)

**Agent:** A1 (Cursor-assisted spec)  
**Phase:** 1  

### Finding

- **LMT101SX006C** stays **black** with the in-driver `**cz101b4001_desc**` DCS init table (**jadard,jd9365da-h3**): wrong panel SKU, not a dead DSI stack.
- **~195-entry** JD9365D init sequence for this LCD is **proprietary panel data** — must come from **LCD Mall** (or equivalent authorized dump).
- **DSI**, `**TASK-121**` **reset**, and **power/rails** treated as confirmed good; remaining gap is **software init commands**.

### Repo updates

- `**AGENTS.md` / `BLK-011`:** Vendor init table work was originally filed under **TASK-122**; **2026-05-08 (later)** `**TASK-122**` repurposed to `**simple-panel-dsi**` fallback — **vendor `lmt101sx006c_desc` patch remains future A2 work under `BLK-011**` (no separate task id in queue yet).
- `**diary/BLOCKERS.md`:** **BLK-011** (**HIGH**) — vendor DCS init required; blocks **TASK-106** closure until resolved.

### Next

- Obtain init table from vendor → unblock **TASK-122** for A2 kernel work → reflash and validate visible image.

---

## 2026-05-07 — Session Summary: Panel Reset Automation & Display Debugging (A1)

**Agent:** A1
**Phase:** 1

### Summary

- Diagnosed the cause of the LMT101SX006C black screen: Hardwiring `RESET` to 3.3V locked the panel's internal logic, preventing it from executing the MIPI DCS initialization commands (`Sleep Out`, `Display On`).
- Advised the owner on the precise manual reset sequence and confirmed the external 9V backlight driver requires its `PWM/EN` pin to be tied to 3.3V for visibility.
- Specced and created **TASK-121** to map the panel `reset-gpios` to `TOUCH_RST` (CON1 Pin 11, `gpio0 RK_PB6`), allowing the `jadard` driver to handle the strict 5ms reset pulse sequence automatically.
- Reviewed and merged **TASK-121** (completed by A2).
- Provided the user with exact instructions for rebuilding the WIC image, flashing the board, and a "Plan B" if the reset timing doesn't completely resolve the issue (Init array matching, lane polarity, etc).

### Next

- Owner to flash the latest image, wire the reset pin to `TOUCH_RST`, and validate display output.

---

## 2026-05-07 — TASK-121: panel reset via CON1 `TOUCH_RST` / `gpio0` `RK_PB6` (A2)

**Agent:** A2 (Cursor)  
**Phase:** 1  

### Summary

- `**elevator-hmi-boardcon-em3566-v3.dts`:** `**&gt1x { status = "disabled"; };**` so `**RK_PB6**` is not claimed by Goodix (BSP `**rk3568-evb.dtsi**`).
- `**elevator-hmi-lmt101sx006c-panel.dtsi`:** `**#include**` gpio + rockchip pinctrl bindings; `**panel@0**` `**reset-gpios = <&gpio0 RK_PB6 GPIO_ACTIVE_LOW>;**` for **jadard** reset pulse before DCS init.
- **Build:** `kas shell kas/elevator-hmi.yml -c "bitbake virtual/kernel -c compile -f && bitbake virtual/kernel -c deploy -f"` — exit **0** (forced-run taint warnings only).
- **Git:** branch `**task/TASK-121-panel-reset**`; `**AGENTS.md**` — **TASK-121** `**[REVIEW]**`.

### Next

- Owner: reflash image/DTB; validate **jadard** / display and **BLK-006**; note `**gt1x**` touch off on this configuration.

---

## 2026-05-06 — Display bring-up docs, `test-display` package, pwm-backlight `power-supply` (A2 / lab)

**Agent:** A2 (Cursor) + owner on **EM3566 v3**  
**Phase:** 1  

### Summary

- `**docs/BRINGUP-CHECKLIST.md` §5.1:** Document correct `**modetest -s**` target — **connector id** for **DSI-1** (lab **191**), *not* encoder (**190**) or CRTC (**112**); prefer `**-s <id>:#0**` when WxH matching fails; black-panel checklist (**sysfs** backlight `**max**`, `**fb0**`, debugfs `**vcc3v3_lcd0_n**`); **kernel log** notes (`**pwm-backlight` dummy regulator**, `**-517**` defer, `**vcc3v3_lcd1_n: disabling**`); **external ~9 V** LED feed vs board **LCD_BL_PWM** / `**LCD_PWREN_H**` (LMT101-style).
- `**test-display.sh`:** Resolve **DSI-1** connector from `**modetest -M rockchip**`, modeset `**:#0**`, dump backlight `**brightness`/`max**`, set **max**, `**vcc3v3_lcd0_n**` debugfs. Shipped via `**meta-hmi-platform/recipes-core/test-display/test-display_1.0.bb**`; `**core-image-minimal.bbappend**` installs `**test-display**`, `**libdrm-tests**`, `**util-linux**` ( `**dd**` for `**fb0**` smoke).
- `**elevator-hmi-boardcon-em3566-v3.dts`:** `**&backlight**` and `**&backlight1**` — `**power-supply = <&vcc3v3_lcd0_n>;**` to address `**supply power not found, using dummy regulator**` after **TASK-120** PMIC/rail edits (full **LCD_BL_PWM** pin still **TASK-118**).
- **On-target (owner):** `**modetest -M rockchip -s 191:#0**` → `**setting mode 800x1280-60.22Hz on connectors 191, crtc 112**`; `**/sys/class/backlight/backlight**` and `**backlight1**` present; `**vcc3v3_lcd0_n/enable**` **1**. Reflash DTB/kernel image to pick up `**power-supply**` overlay.

### Next

- Rebuild/reflash; confirm `**dmesg**` no longer warns on **pwm-backlight** supply (or reduced to one node).
- **TASK-118:** trace **LCD_BL_PWM** to `**pwms =**` in DT; **TASK-106:** photo + BLK-006/008 closure when stable.

---

## 2026-05-06 — Distro `libdrm-tests` + kernel `CONFIG_FB`/`DRM_FBDEV_EMULATION`

**Agent:** A2 (Cursor)  
**Phase:** 1  

### Summary

- `**elevator-hmi.conf`:** `IMAGE_INSTALL:append = " libdrm-tests"` (modetest).
- `**elevator-hmi.cfg`:** `CONFIG_FB=y` (required for `DRM_FBDEV_EMULATION` on 6.1 Kconfig), `CONFIG_DRM_FBDEV_EMULATION=y`, `CONFIG_DRM_FBDEV_OVERALLOC=100`. Vendor `**rockchip_linux_defconfig**` has **no** `DRM_FBDEV` symbols.
- **Build:** `virtual/kernel` configure+compile+deploy `-f`, `core-image-minimal` `image_complete` `-f`; final `.config` shows `**CONFIG_FB=y**`, `**CONFIG_DRM_FBDEV_EMULATION=y**`.
- **WIC:** `core-image-minimal-elevator-hmi-em3566.rootfs-20260505212829.wic`.
- **modetest:** e.g. `build/tmp/work/cortexa55-poky-linux/libdrm/2.4.120/packages-split/libdrm-tests/usr/bin/modetest`.
- **Git:** `develop` `[phase1][image] add modetest + DRM_FBDEV_EMULATION for panel test`.

---

## 2026-05-05 — A2: panel@0 `dsi-lanes` / `dsi-format` (MIPI-DSI device registration)

**Agent:** A2 (Cursor)  
**Phase:** 1  

### Summary

- `**elevator-hmi-lmt101sx006c-panel.dtsi`:** after `reg = <0>;` add `**dsi-lanes = <4>;**`, `**dsi-format = <0>;**` (RGB888) so `**of_mipi_dsi_device_add()**` gets required `**dsi-lanes**`.
- **Build:** `virtual/kernel` compile+deploy `-f`; `**strings`…dtb** shows `**dsi-lanes**` and `**dsi-format**`.
- **WIC:** `core-image-minimal-elevator-hmi-em3566.rootfs-20260505203732.wic` (+ symlink `*.rootfs.wic`).
- **Git:** `**develop**` `[phase1][dts] panel dtsi: add dsi-lanes=4 dsi-format=RGB888 to panel@0`.

---

## 2026-05-05 — DSI panel fragment: `&dsi0` vs `&dsi` (RK3566 linux-rockchip 6.1)

**Agent:** A2 (Cursor)  
**Phase:** 1  

### Summary

- **BSP:** `rk356x.dtsi` defines `**dsi0: dsi@fe060000**`. `**rk3566-evb2-lp4x-v10.dtsi**` / `**rk3568-evb.dtsi**` use `**&dsi0 {**`. Changing `**elevator-hmi-lmt101sx006c-panel.dtsi**` to `**&dsi {**` fails DTC: `**Label or path dsi not found**` (no `dsi` node label on RK3566 in this tree).
- **DTB:** `**dtc -I dtb -O dts**` on deploy `**elevator-hmi-boardcon-em3566-v3.dtb**` shows `**panel@0**` under `**dsi@fe060000**` with `**jadard,jd9365da-h3**`. On-target empty sysfs path → likely wrong DTB flashed or different boot artifact, not `**&dsi0**` naming.
- **No commit** for requested `**&dsi**` rename (invalid for pinned BSP).

---

## 2026-05-06 — A1: Session Summary & Phase 1 Display Gate

**Agent:** A1 (Claude Code)
**Phase:** 1

### Summary

- **Investigation:** Analysed Jadard panel probe failure. Verified that `dw-mipi-dsi.c` correctly calls `mipi_dsi_host_register` to auto-register child nodes, and the `jadard` driver correctly registers as a `mipi_dsi_driver`. The absence of probe messages is likely due to the child node missing a `reg` property or being skipped during OF population.
- **Validation (TASK-121):** Verified A2's inclusion of `CONFIG_FB=y`, `CONFIG_DRM_FBDEV_EMULATION=y`, and `modetest` in the build. Confirmed DTB `chosen.bootargs`, `dsi-lanes`, and `jadard` panel definitions are intact.
- **Cleanup:** Removed duplicate `libdrm-tests` from `meta-hmi-platform/conf/distro/elevator-hmi.conf` (keeping it only in `core-image-minimal.bbappend`).
- **Release:** Merged `develop` into `main` and tagged `v1-phase1-display-bringup` (Phase 1 gate: display pipeline complete, modetest ready).

### Next actions

- A2 to pick up `TASK-118` (Backlight PWM).
- Investigate missing `reg = <0>;` or other OF node properties preventing the DSI host from registering the Jadard panel child device.

---

## 2026-05-05 — A1: Review and merge TASK-120 (and TASK-119)

**Agent:** A1 (Claude Code)
**Phase:** 1

### Summary

- **TASK-119 / TASK-120 `[DONE]`:** Reviewed A2's implementation of fixed regulators for the display pipeline (VOP/DSI/GPU/VPU/MMC/SARADC) and `pmu_io_domains`.
- Verified DTB strings contain all required regulators (`vdd_logic`, `vdd_gpu`, `vdd_npu`, `vccio_sd`, `vcca_1v8`).
- Confirmed `rk809` node correctly deletes PMIC children to prevent duplicate phandles.
- Merged `task/TASK-120-fix-vop-dsi-supply-regulators` into `develop`.

---

## 2026-05-05 — A2: TASK-120 fixed regulators + RK809 /delete-node/ for VOP/GPU/VPU/MMC/SARADC

**Agent:** A2 (Cursor)  
**Phase:** 1  

### Summary

- `**elevator-hmi-boardcon-em3566-v3.dts`:** Board-scope fixed rails `**vdd_logic**`, `**vdd_gpu**`, `**vdd_npu**`, `**vccio_sd**`, `**vcca_1v8**` (TASK-119 `**vcc_*_fixed**` retained); `**&rk809` `regulators**` `**/delete-node/**` for five PMIC children that reused those labels in `**rk3568-evb.dtsi**` (avoids duplicate-label DTC failure; `**meta-hmi-platform` only**). Consumer overrides `**&vop**`, `**&gpu**`, `**&rknpu**`, `**&rkvenc**`, `**&rkvdec**`, `**&dmc**`, `**&sdmmc0**`, `**&saradc**` per spec.
- **Build:** `virtual/kernel` compile+deploy `-f`, then `core-image-minimal` `image_wic` + `image_complete` — exit 0 (BitBake taint warnings from `-f`).
- **DTB:** `strings` on `**elevator-hmi-boardcon-em3566-v3.dtb**` shows all five regulator names; no DTC warnings in latest `**log.do_compile**` for board DTB.
- **WIC:** `core-image-minimal-elevator-hmi-em3566.rootfs-20260505191305.wic`.
- **Git:** branch `**task/TASK-120-fix-vop-dsi-supply-regulators**`; `**AGENTS.md**` TASK-120 → `**[REVIEW]**`.

---

## 2026-05-05 — docs: FLASH-PROCEDURE.md (rkdeveloptool / EM3566 v3)

**Agent:** A2 (Cursor)  
**Phase:** 1  

### Summary

- Added `**docs/FLASH-PROCEDURE.md**` — Maskrom vs Loader USB IDs, `**db`/`wl**` offsets (`0`, `64`, `0x4000`), deploy-dir `**WIC**` resolution, `**minicom**` 1.5 M, post-flash `**lsblk`/`sgdisk`/`dmesg`/`rauc**`, known issues (container `**sudo**`, `**db**` quirk, GPT, `**dialout**`).
- Cross-links: `**CLAUDE.md**`, `**BRINGUP-CHECKLIST.md**`, `**diary/PROGRESS.md**`.
- Committed on `**develop**`: `**[docs] add FLASH-PROCEDURE.md for EM3566 v3 rkdeveloptool**`.

---

## 2026-05-05 — A2: TASK-117 chosen.bootargs — root=/dev/mmcblk0p2 in board DTB

**Agent:** A2 (Composer)  
**Phase:** 1  

### Summary

- `**elevator-hmi-boardcon-em3566-v3.dts`:** `/ { chosen { bootargs = "… root=/dev/mmcblk0p2 …"; }; };` after includes (replaces vendor PARTUUID in DTB).
- **Build:** `virtual/kernel` compile+deploy `-f`, then `core-image-minimal` `image_wic` + `image_complete` — exit 0 (expected BitBake taint warnings from `-f`).
- **DTB check:** `fdtget`/`fdtdump` not on host; `**strings`…`|grep` root=`** shows full line with **`root=/dev/mmcblk0p2`**, no **`PARTUUID`**.
- **WIC:** `core-image-minimal-elevator-hmi-em3566.rootfs-20260505171448.wic` (deploy dir symlink `*.rootfs.wic`).
- **Git:** branch `**task/TASK-117-fix-chosen-bootargs`** pushed; `**AGENTS.md`** TASK-117 → `**[REVIEW]**`.

---

## 2026-05-05 — A1: io-domains root cause — TASK-119 specced

**Agent:** A1  
**Phase:** 1  

### Summary

- `io-domains` deferral root cause identified: `pmu_io_domains` references RK809 PMIC regulators that do not exist on the CM3566 SoM. This caused cascading deferrals (VOP, DSI).
- Parent DTS `rk3568-evb.dtsi` configures `vccio4` at 3.3V, but EM3566 v3 hardware uses 1.8V for DSI IO. Other domains mismatch as well.
- Fix path: `regulator-fixed` override in board DTS (`elevator-hmi-boardcon-em3566-v3.dts`).
- **TASK-119** specced in `AGENTS.md`. Voltages have been verified against the schematic note before A2 acts.
- **TASK-117** was already completed and merged in the previous session.

---

## 2026-05-05 — A1: TASK-117 `[DONE]` review

**Agent:** A1  
**Phase:** 1  

### Review

- **PASS** — DTS explicitly overrides `chosen.bootargs` at root level. Verified via `strings` on DTB that `root=/dev/mmcblk0p2` is present and `PARTUUID` is gone.
- **PASS** — Clean kernel compile, deploy, and WIC image generation reported by A2. No community layer edits.

### Next

- A2: Pick up **TASK-118** (Backlight PWM DTS).

**Merge:** `**task/TASK-117-fix-chosen-bootargs`** merged into `**develop`**.

---

## 2026-04-19 — A1: LCD sprint plan — TASK-117/118 specced, §5 corrected

**Agent:** A1  
**Phase:** 1  

### Summary

- Board boots to root login (validated)
- chosen.bootargs root cause identified (rk3568-linux.dtsi PARTUUID)
- LMT101 panel physically on hand — TASK-106 unblocking
- FPC adapter and 9V boost on order — wiring plan documented
- TASK-117 and TASK-118 specced
- CLAUDE.md §5 corrected
- Repo moved to senerferhat/elevator-hmi. Build host `origin` updated manually via `git remote set-url`. No references found in docs to replace.

---

## 2026-04-19 — A1: state review — `CLAUDE.md` §5 layout + TASK-116 preflight

**Agent:** A1  
**Phase:** 1  

### What is working

- **Yocto / kas:** green `**./scripts/kas-build-task-105.sh`** (TASK-113) on Ubuntu **24.04** TASK-002-class host; deploy under `**build/tmp/deploy/images/elevator-hmi-em3566/`**.  
- **Board:** **EM3566 v3** boots to **Linux login** on serial — validated **2026-04-18** (earlier entries).  
- **RAUC / WIC:** `**system.conf`** rootfs slots `**/dev/mmcblk0p2`** / `**p3**` match **4-part** GPT in `**meta-hmi-platform/wic/elevator-hmi-emmc.wks.in`** (TASK-111, BLK-009 closed).  
- **Docs:** **TASK-114** BRINGUP §8 no-LCD checklist in tree.

### What was wrong (fixed this session)

- `**CLAUDE.md` §5** still described a **6-part** eMMC plan. **Implemented** layout is **4 partitions:** `**p1`** boot (vfat), `**p2`** rootfs_a, `**p3**` rootfs_b, `**p4**` data — per **WIC** + **RAUC**. **§5** updated; **Phase 2** size expansion called out in §5 (WKS already comments larger rootfs/data for later).

### What is pending

- **Owner — §2.1 / BRINGUP §8:** `**lsblk -f`**, `**/proc/partitions`**, UART baseline, `**pre-LCD baseline**` `**dmesg**`, `**rauc status**`, optional `**ip link**` / `**lsusb**`.  
- **A2 — TASK-115** `**[READY]`:** Qt image `**bitbake -p`** parse (branch `**task/TASK-115-qt-image-parse`**).  
- **A2 — TASK-116** `**[READY]`:** RAUC / D-Bus / systemd on `**core-image-minimal`** — **may start without** owner paste; see `**AGENTS.md`** A1 preflight.  
- **Hardware:** **LMT101** + **MIPI LCD** (TASK-106; BLK-006 / BLK-008).

### Next

- Merge `**task/TASK-115-qt-image-parse`** if open PR; then A2 **TASK-116** on `**task/TASK-116-rauc-systemd-minimal`**.  
- Owner: run §2.1; order **LMT101SX006C**.

---

## 2026-04-19 — A1: TASK-114 `[DONE]` review

**Agent:** A1  
**Phase:** 1  

### Review

- **PASS** — `**docs/BRINGUP-CHECKLIST.md`** **§8** mirrors `**CLAUDE.md`** §2.1; cross-links valid; no `**.wks`** / partition edits; **§6** / **§5** closure rules consistent with project rules.

### Next

- A2: `**TASK-115`** on `**task/TASK-115-qt-image-parse`** (branch from latest `**origin/develop**`).

**Merge:** `**task/TASK-114-bringup-no-lcd`** fast-forwarded into `**develop`** and pushed (`**bc9ff05**` on `**origin/develop**`).

---

## 2026-04-19 — TASK-114: BRINGUP checklist §8 “Lab without LCD” (A2)

**Agent:** A2  
**Phase:** 1  

### Result

- `**docs/BRINGUP-CHECKLIST.md`** — new **§8 — Lab without LCD (EM3566 v3)** mirroring `**CLAUDE.md`** §2.1; cross-links to `**CLAUDE.md`** §2.1 and `**diary/PROGRESS.md**` for owner paste targets; **§6**/**§5** pointers (bootdelay, no invented GPIO).  
- `**AGENTS.md`** — **TASK-114** → `**[REVIEW]`**; sprint queue next `**[READY]`:** **TASK-115**.  
- `**CLAUDE.md`** — Phase checklist row for **TASK-114** updated (still unchecked until A1 `**[DONE]`**).

**Branch:** `**task/TASK-114-bringup-no-lcd`** (from `**develop`** @ `**ad4354e**`).

---

## 2026-04-19 — A1: TASK-113 `[DONE]` review

**Agent:** A1  
**Phase:** 1  

### Review

- **PASS** — `**./scripts/kas-build-task-105.sh`** **exit 0** on Ubuntu **24.04** TASK-002-class host; `**build-logs/*.log`** tails + deploy artefact summary in `**diary/PROGRESS.md`** satisfy **TASK-113** acceptance (**equivalent** deploy listing). **2 WARNING** on `**core-image-minimal`** noted by A2; non-fatal.  
- **PASS** — no `**meta-rockchip` / `meta-qt6` / `meta-rauc`** edits. Owner **§2.1** on-target pastes correctly out of scope for **TASK-113**.

### Next

- A2: `**TASK-114`** on `**task/TASK-114-bringup-no-lcd`** (from current `**develop**`).

**Merge:** `**task/TASK-113-kas-build-105-logs`** fast-forwarded into `**develop`** and pushed (`**b4eebf4**` on `**origin/develop**`).

---

## 2026-04-19 — TASK-113: green `kas-build-task-105.sh` + deploy listing (A2)

**Agent:** A2  
**Phase:** 1  

### Host

- **Ubuntu 24.04** LTS, `**lz4c`** on `**PATH`**, `**kas` 5.2** — TASK-002-class host (`setup-build-host.sh` previously applied on this machine).

### Result

- `**./scripts/kas-build-task-105.sh`** — **exit 0** (full sequence: `**u-boot-rockchip`**, `**virtual/kernel`**, `**core-image-minimal**`). Logs under `**build-logs/**` (gitignored).

### Log tails (last lines; full logs in `build-logs/*.log`)

`**u-boot-rockchip.log**`

```
NOTE: Tasks Summary: Attempted 1082 tasks of which 1063 didn't need to be rerun and all succeeded.
```

`**virtual-kernel.log**`

```
NOTE: Tasks Summary: Attempted 995 tasks of which 994 didn't need to be rerun and all succeeded.
```

`**core-image-minimal.log**`

```
NOTE: Tasks Summary: Attempted 4310 tasks of which 4280 didn't need to be rerun and all succeeded.
Summary: There were 2 WARNING messages.
TASK-105 smoke sequence finished OK.
```

### `ls -la build/tmp/deploy/images/elevator-hmi-em3566/` (excerpt)

Key artefacts (see deploy dir for full listing): `**core-image-minimal-elevator-hmi-em3566.rootfs.wic**` (symlink `**…rootfs.wic**`), `**Image**` / `**zboot.img**`, `**uboot.img**`, `**loader.bin**`, `**idblock.img**`, `**rootfs.img**` → ext4, `**update.img**`, `**elevator-hmi-boardcon-em3566-v3.dtb**`.

### Notes

- BitBake **WARNING** count on image: **2** (non-fatal; unchanged from prior green builds on this tree).
- **Owner (no LCD):** still follow `**CLAUDE.md`** §2.1 — paste `**lsblk -f`** / `**pre-LCD baseline**` `**dmesg**` here when run on **EM3566 v3** (optional **BLK-009** audit trail if you want a hardware cross-check vs WIC).

---

## 2026-04-19 — A1: no-LCD lab plan + TASK-113–TASK-116 `[READY]`

**Agent:** A1  
**Phase:** 1  

### Changes

- `**CLAUDE.md`**: new §2.1 Phase 1 — Lab without LCD (owner checklist) — reflash post–TASK-111 image, `**lsblk`**, GPT `**sgdisk -e**`, UART baseline, `**pre-LCD baseline**` `**dmesg**` (grep targets for **BLK-008** prep), `**rauc status`**, optional **eth/USB**, **U-Boot bootdelay** if still **0**; pointer to **TASK-106** when LMT101 arrives. Phase 0 checklist: owner no-LCD line + **TASK-114** pointer.
- `**AGENTS.md`**: `**TASK-113`** (TASK-105 green logs + `**PROGRESS.md**`), `**TASK-114**` (BRINGUP no-LCD section), `**TASK-115**` (`elevator-hmi-image` `**bitbake -p**` only), `**TASK-116**` (RAUC / systemd / D-Bus on minimal — `**meta-hmi-platform**` only). Queue: pick **one** task at a time. **BLK-008** blurb: **pre-LCD `dmesg`** baseline allowed per `**CLAUDE.md**` §2.1.

### Next

- A2: start `**TASK-113**` on `**task/TASK-113-kas-build-105-logs**` (or next in order). Owner: `**CLAUDE.md**` §2.1 on hardware without panel.

---

## 2026-04-18 — A1: TASK-112 `[DONE]` — merge + queue (develop @ 162f9c2)

**Agent:** A1  
**Phase:** 1  

### Review

- `**TASK-112`**: PASS — Historical fence only note under archived TASK-108; `**mmcblk0p4`** only in fence + explicit historical / TASK-112 spec text (grep).
- **Git:** `**git merge task/TASK-112-agents-rauc-doc`** on `**develop`** (fast-forward `**83ebcc8` → `162f9c2**`). Follow-up commit: `**AGENTS.md**` marks `**TASK-112**` `**[DONE]**`, A1 review line, sprint queue cleared of `**[REVIEW]**`.

### Next

- A2: no `**[READY]**` until A1 specs next task; `**TASK-106**` when **LMT101** arrives.

---

## 2026-04-18 — TASK-112: AGENTS archive note for TASK-108 RAUC fence (A2)

**Agent:** A2  
**Phase:** 1  

### Summary

- `**AGENTS.md`** — under archived **TASK-108**, added **Historical fence only** paragraph after the fenced `**system.conf`** example so `**p4`/`p5`** is not mistaken for current `**develop**` paths (`**p2`/`p3**` per **TASK-111** / `**elevator-hmi-emmc.wks.in`**). `**TASK-112`** → `**[REVIEW]**`; queue line updated.  
- **Branch:** `**task/TASK-112-agents-rauc-doc`** (one commit for PR).

---

## 2026-04-18 — A1: merge TASK-111 → `develop`, sprint handoff (`TASK-112` `[READY]`)

**Agent:** A1  
**Phase:** 1  

### Git

- `**git fetch origin && git merge origin/task/TASK-111-rauc-slot-paths`** on `**develop`** — **fast-forward** `**3775012` → `7502d2b`** (RAUC `**system.conf`** `**p2`/`p3**`, **BLK-009** closed on tree, **BRINGUP** §3, diary handoff entry from branch).
- Follow-up commit on `**develop`**: `**AGENTS.md`** marks `**TASK-111**` `**[DONE]**`, adds `**TASK-112**` `**[READY]**`, `**CLAUDE.md**` / this diary line (A1 sprint prep).

### A2 sprint

- `**TASK-111**` → `**[DONE]**` in `**AGENTS.md**`; `**TASK-112**` `**[READY]**` — archive note under TASK-108 so nobody copies legacy `**p4`/`p5**` from the historical `**system.conf**` fence.
- A2: `**git pull origin develop**`, branch `**task/TASK-112-agents-rauc-doc**`, one small commit, PR.

---

## 2026-04-18 — A2 handoff: `develop` synced, TASK-111 `[REVIEW]`, TASK-105 deploy note, checklist §3

**Agent:** A2  
**Phase:** 1  

### Git / branch

- `**git checkout develop && git pull origin develop`** — already up to date with `**origin/develop`** (`**3775012**`).
- `**TASK-111**` work on `**task/TASK-111-rauc-slot-paths**` (not merged until A1 `**[DONE]**`).

### TASK-105 deferred acceptance (host)

- Green image artefacts present under `**build/tmp/deploy/images/elevator-hmi-em3566/**` (e.g. `**core-image-minimal-elevator-hmi-em3566.rootfs.wic**` symlink, `**uboot.img**`, `**idblock.img**`, `**loader.bin**`, DTB) — matches 2026-04-18 lab milestone flash block.

### TASK-111 / BLK-009

- `**system.conf`:** RAUC rootfs slots `**/dev/mmcblk0p2`** (A) and `**/dev/mmcblk0p3`** (B) per `**elevator-hmi-emmc.wks.in**` (replaces legacy `**p4`/`p5**`). `**kas shell kas/elevator-hmi.yml -c "bitbake -p"**` OK.
- `**diary/BLOCKERS.md`:** **BLK-009** closed with WIC-based resolution; optional `**lsblk -f`** from target still requested for audit trail.

### Docs

- `**docs/BRINGUP-CHECKLIST.md`** §3 — cross-link TASK-105 deploy + `**PROGRESS.md**` flash commands.

---

## 2026-04-18 — Phase 1 lab milestone: U-Boot shell, root login, bring-up learnings (A1 + owner)

**Agent:** A1 (documentation); **execution:** owner on EM3566 v3  
**Phase:** 1  

### Vision / status

End-to-end **reference-board bring-up** is now credible: **flash → SPL/U-Boot → Linux → `root` login** on serial has been demonstrated. Remaining Phase 1 lab work shifts from “can the stack boot?” to **partition/OTA correctness**, **DSI + LMT101** (TASK-106, BLK-006/008), and **image hardening** (password policy, RAUC slot paths).

### Achievements (this cycle)

1. **U-Boot interrupt window** — Root cause of “cannot stop autoboot”: vendor `**CONFIG_BOOTDELAY=0`**. `**meta-hmi-platform/recipes-bsp/u-boot/files/elevator-hmi-emmc-boot.cfg`** now sets `**CONFIG_BOOTDELAY=5**` (rebuild + reflash `**uboot.img**` at sector `**0x4000**` to apply).
2. **Manual kernel boot from U-Boot** — `**booti ${kernel_addr_r} - ${fdt_addr_r}`** (not `**${0x00280000}`**); `**setenv bootargs**` with `**init=/bin/sh**` for one-time rescue when login was locked.
3. `**rkdeveloptool**` — `**db**` may return *“The device does not support this operation!”* while `**wl`** / `**rd*`* still succeed; `**db` is optional** for updating `**uboot.img`** / `**.wic`** on this kit (see diary flash block below).
4. **Deploy paths** — Stable symlinks under `**build/tmp/deploy/images/elevator-hmi-em3566/`**: `**core-image-minimal-elevator-hmi-em3566.rootfs.wic`**, `**loader.bin**`, `**idblock.img**`, `**uboot.img**` (no placeholder filenames in lab commands).
5. **Root account** — `**core-image-minimal`** ships `**root:*:`** (locked). Early `**init=/bin/sh**` shell: `**tty` → not a tty** → interactive `**passwd`** exits immediately (reads empty password); `**echo 'root:…' | chpasswd`** works. Avoid stacking `**tmpfs` on `/dev**` over `**devtmpfs**` (hides `**/dev/ttyS2**`). Normal login banner: `**/dev/ttyFIQ0**` (kernel cmdline still uses `**ttyS2**` for UART2 — two consoles; expect interleaved logs if both are active).
6. **Confirmed:** `**root`** login at `**elevator-hmi-em3566 login:`** on `**ttyFIQ0**` after password set.

### Flash command block (copy-paste — repo on host)

Host paths: `**/home/sener/Projects/elevator-hmi/build/tmp/deploy/images/elevator-hmi-em3566/**` (adjust `**REPO**` if clone differs).

```bash
# Optional (often fails in Loader mode — skip if error):
sudo rkdeveloptool db /home/sener/Projects/elevator-hmi/build/tmp/deploy/images/elevator-hmi-em3566/loader.bin

sudo rkdeveloptool wl 0 /home/sener/Projects/elevator-hmi/build/tmp/deploy/images/elevator-hmi-em3566/core-image-minimal-elevator-hmi-em3566.rootfs.wic
sudo rkdeveloptool wl 64 /home/sener/Projects/elevator-hmi/build/tmp/deploy/images/elevator-hmi-em3566/idblock.img
sudo rkdeveloptool wl 0x4000 /home/sener/Projects/elevator-hmi/build/tmp/deploy/images/elevator-hmi-em3566/uboot.img
sudo rkdeveloptool rd
```

**U-Boot-only** (after rebuilding `**u-boot-rockchip`**): omit `**wl 0`** line; keep `**wl 0x4000**` (and optionally `**wl 64**`).

### Next steps on board (owner / A2 — ordered)


| Priority | Check                             | Command / action                                                                                                  | Feeds                                        |
| -------- | --------------------------------- | ----------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| 1        | **Partition map vs RAUC**         | `lsblk -f` and `cat /proc/partitions` on target; paste into diary or TASK-111                                     | **BLK-009**, **TASK-111**                    |
| 2        | **GPT backup header**             | `sgdisk -e /dev/mmcblk0` then `partprobe` (image includes `**gptfdisk`**)                                         | clears `**GPT:… != …`** warning              |
| 3        | **Kernel / panel DTS**            | Full `**dmesg`** after boot; grep for `**vcc3v3_lcd0_n`**, `**vcca_1v8**`, `**backlight**`, **DSI**, `**jd9365`** | **BLK-008**, **TASK-106** prep               |
| 4        | **Reflash U-Boot with bootdelay** | Rebuild `**u-boot-rockchip`** if not yet deployed; `**wl 0x4000 uboot.img`**; confirm countdown **5**             | lab ergonomics                               |
| 5        | **RAUC**                          | `rauc status` / D-Bus once `**system.conf`** matches real `**mmcblk0pN`**                                         | **BLK-009**                                  |
| 6        | **Ethernet**                      | `ip link`, `dmesg                                                                                                 | grep -i eth` (expect caveats on dev kit PHY) |
| 7        | **LMT101**                        | Cable to **MIPI LCD**; power; capture `**dmesg`** + photo of output                                               | **TASK-106**, **BLK-006**                    |


### Product / process notes

- **Security:** Bring-up passwords must be rotated before any network exposure; prefer `**passwd`** on a real TTY or `**EXTRA_IMAGE_FEATURES`** dev-only recipe for factory flows.
- **Docs:** `**docs/BRINGUP-CHECKLIST.md`** updated with `**rkdeveloptool`** lab notes (see §6).

---

## 2026-04-18 — root=PARTUUID override fix, GPT backup header fix, gptfdisk (A1)

**Agent:** A1  
**Phase:** 1  

### Problems (observed on first boot)

1. `**root=PARTUUID=614e0000-0000` in kernel cmdline** despite extlinux.conf having `root=/dev/mmcblk0p2`. Kernel cannot find rootfs.
2. `**GPT:6075217 != 15155199`** — backup GPT header at wrong sector. WIC image is 2.9 GB (~~6,075,217 sectors); eMMC is 7.23 GB (~~15,155,199 sectors). Backup GPT in WIC image points to last sector of the image, not the device.

### Root cause analysis — PARTUUID override

Traced through Rockchip vendor U-Boot source:

- `sysboot` (extlinux boot) calls `env_set("bootargs", ...)` with extlinux `append` value — correct `root=/dev/mmcblk0p2`.
- Then `do_booti()` calls `fdt_chosen()` → `board_fdt_chosen_bootargs()` (Rockchip override in `board.c:1335`).
- This calls `bootargs_add_dtb_dtbo()` which reads `/chosen/bootargs` from the **static compiled-in DTB**.
- `rk3568-linux.dtsi` (included by our DTS chain via `rk3566-evb2-lp4x-v10-linux.dts`) sets: `chosen { bootargs = "earlycon=... console=ttyFIQ0 root=PARTUUID=614e0000-0000 rw rootwait"; }`
- `env_update()` (`nvedit.c:406`) performs a **key-match merge**: tokenizes both bootargs strings, replaces matching keys — so `root=PARTUUID=...` replaces `root=/dev/mmcblk0p2`.
- extlinux.conf `append` value is lost for the `root=` key.

### Fixes

**Fix 1 — DTS chosen.bootargs override** (`elevator-hmi-boardcon-em3566-v3.dts`):

```dts
&chosen {
    bootargs = "earlycon=uart8250,mmio32,0xfe660000 console=ttyS2,1500000 root=/dev/mmcblk0p2 rw rootfstype=ext4 rootwait";
};
```

- earlycon address `0xfe660000` verified from `rk356x.dtsi` uart2 node (`reg = <0x0 0xfe660000 0x0 0x100>`).
- ttyFIQ0 replaced with ttyS2 (EM3566 v3 debug UART).
- Overrides the `rk3568-linux.dtsi` `root=PARTUUID=` so `env_update()` merges the correct values.
- NOTE: `UBOOT_EXTLINUX_BOOTPREFIXES` does NOT exist in OE/meta-rockchip — not added. DTS override is the correct fix.

**Fix 2 — `scripts/fix-gpt.sh`**: One-time post-flash script:

```bash
sgdisk -e /dev/mmcblk0   # relocates backup GPT to actual last sector
partprobe /dev/mmcblk0   # reload partition table without reboot
```

Run once after first boot.

**Fix 3 — `gptfdisk` in image**: Added to `IMAGE_INSTALL:append` in `core-image-minimal.bbappend` so `sgdisk` is available on the target.

### Commit

`c297a53` — `[phase1][dts/image] fix root=PARTUUID override, GPT backup header, add gptfdisk`

### Build result

`kas build kas/elevator-hmi.yml` — **4310 tasks, all succeeded** (4225 from sstate). 2 warnings (non-fatal).  
Build time: 12:38:32 → 12:43:21 (~5 min, kernel compile via sstate cache).

### Post-build verification

**extlinux.conf in WIC boot partition** (mtype from WIC `@@32768s`):

```
default Yocto
label Yocto
   kernel /Image
   fdt /elevator-hmi-boardcon-em3566-v3.dtb
   append root=/dev/mmcblk0p2 rw rootfstype=ext4 rootwait console=ttyS2,1500000
```

**DTB `/chosen/bootargs`** (strings on deploy DTB):

```
earlycon=uart8250,mmio32,0xfe660000 console=ttyS2,1500000 root=/dev/mmcblk0p2 rw rootfstype=ext4 rootwait
```

No `PARTUUID` in either. `env_update()` will now merge `root=/dev/mmcblk0p2` (not replace it). ✓

### Next actions

1. Re-flash board with new WIC image.
2. On first boot, run via UART console: `sh /usr/sbin/fix-gpt.sh`
3. Verify kernel cmdline: should show `root=/dev/mmcblk0p2` (not `root=PARTUUID=`).
4. Confirm rootfs mounts and login prompt appears on ttyS2.
5. Expand partition sizes to production (rootfs 2048M, data 4096M) after boot confirmed.

---

## 2026-04-18 — Fix extlinux.conf: explicit fdt via WKS --configfile (A1)

**Agent:** A1  
**Phase:** 1  

### Problem

U-Boot was using `fdtdir /` in extlinux.conf and guessing the DTB filename from `$fdtfile` env var. It chose `rockchip-evb_rk3568.dtb` instead of our `elevator-hmi-boardcon-em3566-v3.dtb`, causing kernel load failure.

### Root cause analysis

Two separate extlinux.conf generators exist:

1. `**uboot-extlinux-config.bbclass`** — U-Boot recipe task (`do_create_extlinux_config`). Writes `${B}/extlinux.conf`. Reads `UBOOT_EXTLINUX_ROOT`, `UBOOT_EXTLINUX_FDT`, `UBOOT_EXTLINUX_CONSOLE` from BitBake. Used by U-Boot recipe deployment only — NOT what ends up in the WIC boot partition.
2. `**bootimg-partition.py` WIC plugin** — Generates `extlinux/extlinux.conf` inside the vfat boot partition. **Completely hardcoded** — ignores all `UBOOT_EXTLINUX_`* BitBake variables. Scans `install_task` for `.dtb` files, always writes `fdtdir /`. Root device comes from `cr.rootdev` (WKS rootdev). The only override hook is `bootloader --configfile <filename>` in the WKS file.

### Fix

1. Created `meta-hmi-platform/wic/elevator-hmi-extlinux.conf` with explicit `fdt` line:
  ```
   default Yocto
   label Yocto
      kernel /Image
      fdt /elevator-hmi-boardcon-em3566-v3.dtb
      append root=/dev/mmcblk0p2 rw rootfstype=ext4 rootwait console=ttyS2,1500000
  ```
   Placed in `meta-hmi-platform/wic/` — `find_canned()` searches layer `wic/` dirs by filename.
2. Updated `elevator-hmi-emmc.wks.in`: `bootloader --ptable gpt --configfile elevator-hmi-extlinux.conf`
3. Kept `UBOOT_EXTLINUX_ROOT / CONSOLE / FDT` in machine conf — required by `do_create_extlinux_config` bbclass (fatal if ROOT is absent). Added `UBOOT_EXTLINUX_FDT` for the bbclass path too. Updated comments to document the two-path architecture.

### Verified extlinux.conf (from new WIC boot partition via mtools)

```
default Yocto
label Yocto
   kernel /Image
   fdt /elevator-hmi-boardcon-em3566-v3.dtb
   append root=/dev/mmcblk0p2 rw rootfstype=ext4 rootwait console=ttyS2,1500000
```

**No `fdtdir` line. Explicit `fdt` confirmed. ✓**

### Commits


| Hash      | Message                                                                                                 |
| --------- | ------------------------------------------------------------------------------------------------------- |
| `c74316d` | `[phase1][machine] set explicit UBOOT_EXTLINUX_FDT to fix DTB lookup` (superseded — was wrong approach) |
| `35a05fb` | `[phase1][wic] fix extlinux.conf — explicit fdt via WKS --configfile`                                   |
| `91a12a4` | `[phase1][machine] restore UBOOT_EXTLINUX_ROOT/CONSOLE/FDT for bbclass`                                 |


### Next actions

- Owner: re-flash board with new WIC (same procedure as 2026-04-18 first boot entry)
- Expected UART boot path: `distro_bootcmd` → `mmc 0:1` → `extlinux/extlinux.conf` → loads `/Image` + `/elevator-hmi-boardcon-em3566-v3.dtb` → kernel start
- A1: monitor for BLK-008 phandle errors in dmesg after first successful boot

---

## 2026-04-18 — WIC bring-up fixes: IMAGE_BOOT_FILES, partition sizes, extlinux, GPT, boot offset (A1)

**Agent:** A1  
**Phase:** 1  

### Summary

Six sequential WIC/build defects identified and fixed during eMMC bring-up, all applied directly to `develop`. Each fix was supervisor-reviewed before proceeding. No flash tonight — session closed with WIC verified and flash procedure documented for next session.

### Fix 1 — IMAGE_BOOT_FILES unset (`do_image_wic` failure)

`bootimg-partition` WIC plugin raises `WicError` when `IMAGE_BOOT_FILES` is unset. `meta-rockchip` never sets this variable. Deploy dir produces `Image` and `elevator-hmi-boardcon-em3566-v3.dtb` flat (Yocto kernel recipe strips `arch/arm64/boot/` prefix).  
**Fix:** Added to `meta-hmi-platform/conf/machine/elevator-hmi-em3566.conf`:

```bitbake
IMAGE_BOOT_FILES = "Image elevator-hmi-boardcon-em3566-v3.dtb"
```

Commit: `5cf6b39`

### Fix 2 — `do_image_wic_ufs` failure (UFS not eMMC)

`rockchip-image` bbclass adds a `do_image_wic_ufs` task for 4K-sector UFS images. This project targets eMMC. Overrode to no-op in `core-image-minimal.bbappend`.  
Commit: `a37356f`

### Fix 3 — WIC image 8.7 GB causing flash tool failure at 83%

Production partition sizes (rootfs_a 2048M, rootfs_b 2048M, data 4096M) produced an 8.7GB image too large for reliable `rkdeveloptool` single-write. Reduced for bring-up:

- `rootfs_a`: 2048M → 1024M
- `rootfs_b`: 2048M → 1024M
- `data`: 4096M → 512M
- Added `IMAGE_OVERHEAD_FACTOR = "1.1"` to `core-image-minimal.bbappend`.

New total: ~2.6 GB fixed + rootfs overhead. Target after first boot confirmed: restore production sizes.  
Commit: `c02c6a1`

### Fix 4 — Boot partition had files but no extlinux.conf (silent scan failure)

`bootimg-partition` without `--sourceparams "loader=u-boot"` copies `IMAGE_BOOT_FILES` into the partition but exits `do_configure_partition` early — no `extlinux/extlinux.conf` generated. `bootimg-efi` attempted first (wrong — requires a loader param, fails with "bootimg-efi requires a loader, none specified"). Reverted and added correct `--sourceparams "loader=u-boot"`.

WKS boot line:

```
part /boot --source bootimg-partition --sourceparams "loader=u-boot" --ondisk mmcblk0 --fstype=vfat --label boot --active --align 4 --size 64M
```

Boot partition verified via `mdir`: `Image`, `elevator-hmi-boardcon-em3566-v3.dtb`, `extlinux/extlinux.conf`.  
Commit: `744a831`

### Fix 5 — Missing GPT declaration (U-Boot cannot find boot partition by GPT label)

WKS was creating DOS/MBR by default. Added `bootloader --ptable gpt` as first line of WKS.  
`fdisk -l` confirmed: `Disklabel type: gpt`.  
Commit: `dc21a6c`

### Fix 6 — Boot partition FAT corrupted by idblock.img at sector 64

Hardware bring-up U-Boot serial confirmed `PartType: EFI` (GPT working) but `fatls mmc 0:1` returned `0 file(s), 1 dir(s)` with a garbage directory entry. Root cause: WIC p1 started at sector 40; `rkdeveloptool wl 64 idblock.img` writes at sector 64 which is **inside** p1, overwriting FAT tables.

Investigation confirmed:

- `bootloader` directive does NOT support `--offset` (checked `ksparser.py` — only `--ptable`, `--append`, `--configfile`, `--timeout`, `--source`)
- `part` DOES support `--offset` via `sizetype("K", True)` — accepts `M` suffix

**Fix:** `--offset 16M` on boot part → forces p1 start to sector 32768 (16 MB), safely past both idbloader (sector 64 = 32 KB) and U-Boot FIT (sector 16384 = 8 MB).  
Commit: `a2acb82`

### Final verified WIC state (supervisor-approved)


| Check                            | Result                                                                     |
| -------------------------------- | -------------------------------------------------------------------------- |
| Partition table                  | GPT ✓                                                                      |
| p1 (boot/vfat) start sector      | 32768 ✓ — clear of idblock (64) and uboot (16384)                          |
| p1 size                          | 83.2M ✓                                                                    |
| p2 rootfs_a                      | 1.3G ✓                                                                     |
| p3 rootfs_b                      | 1.0G ✓                                                                     |
| p4 data                          | 512M ✓                                                                     |
| Total image size                 | 2.9G ✓                                                                     |
| No overlap with bootloader chain | Confirmed ✓                                                                |
| Boot partition contents          | `Image`, `elevator-hmi-boardcon-em3566-v3.dtb`, `extlinux/extlinux.conf` ✓ |


### U-Boot serial findings (from hardware bring-up before Fix 6)

```
PartType: EFI                          ← GPT confirmed
bootcmd=boot_android ${devtype} ${devnum};boot_fit;bootrkp;run distro_bootcmd;
boot_targets=mmc1 mmc0 mtd2 mtd1 mtd0 usb0 pxe dhcp
Scanning mmc 0:1...                    ← reaches our boot partition via distro_bootcmd
fatls mmc 0:1 → 0 file(s)             ← FAT corrupted by idblock overlap (now fixed)
ext4ls mmc 0:2 → Linux root tree ✓    ← rootfs_a correctly populated
```

`bootcmd` path: Android (fails) → boot_fit (fails) → bootrkp (fails) → `distro_bootcmd` → scans mmc0:1 for `extlinux/extlinux.conf`. With Fix 6 applied, this scan should now succeed.

### Tomorrow — First boot flash procedure

```bash
# 1. Enter Maskrom (hold RECOVERY + power on)
lsusb | grep 2207:   # must show 2207:350a

# 2. Load bootloader
sudo rkdeveloptool db build/tmp/deploy/images/elevator-hmi-em3566/loader.bin

# 3. Flash full WIC
sudo rkdeveloptool wl 0 build/tmp/deploy/images/elevator-hmi-em3566/core-image-minimal-elevator-hmi-em3566.rootfs-20260417223520.wic

# 4. Write idbloader at sector 64
sudo rkdeveloptool wl 64 build/tmp/deploy/images/elevator-hmi-em3566/idblock.img

# 5. Write U-Boot FIT at sector 16384
sudo rkdeveloptool wl 0x4000 build/tmp/deploy/images/elevator-hmi-em3566/uboot.img

# 6. Reboot
sudo rkdeveloptool rd
```

Expected:

```
PartType: EFI
Scanning mmc 0:1...
Found /extlinux/extlinux.conf
Retrieving file: /Image
Starting kernel ...
[    0.000000] Booting Linux on physical CPU 0x0000000000 [0x412fd050]
```

### Next actions

- Owner: execute first boot flash sequence above; log full UART output in diary
- A1 (next session): review `dmesg` for BLK-008 phandle errors (`vcc3v3_lcd0_n`, `vcca_1v8`, `backlight`)
- A1 (next session): spec TASK-111 for RAUC slot device path correction (system.conf uses `mmcblk0p4/p5` but WIC GPT p2/p4 are rootfs_a/data; confirm correct slot device numbers after first boot partition listing)

---

## 2026-04-17 — TASK-109 A1 review fix — DISTRO_FEATURES removed from image recipe (A1)

**Agent:** A1  
**Phase:** 1  

### Review outcome

- **All checks passed** except one defect (see below).
- **Process issue:** A2 left all changes uncommitted on `task/TASK-109-qt-eglfs-image`. A1 applied the fix and committed everything as the first commit on the branch.

### Defect fixed

`DISTRO_FEATURES:remove = "x11 wayland"` removed from `elevator-hmi-image.bb`. Image recipes cannot reliably modify `DISTRO_FEATURES`. Already handled in `meta-hmi-platform/conf/distro/elevator-hmi.conf` (TASK-108). Replaced with an explanatory comment.

### STEP 3 check results


| Check                                                            | Result                                     |
| ---------------------------------------------------------------- | ------------------------------------------ |
| `LAYERSERIES_COMPAT = "scarthgap"`                               | **PASS**                                   |
| `BBFILE_PRIORITY_hmi-app = "9"`                                  | **PASS**                                   |
| `LAYERDEPENDS` includes `qt6-layer`                              | **PASS**                                   |
| `LAYERDEPENDS` includes `rauc`                                   | **PASS** (acceptable — bundle.bb needs it) |
| `inherit core-image`                                             | **PASS**                                   |
| `inherit rockchip-image`                                         | **PASS**                                   |
| `WKS_FILE = "${ELEVATOR_HMI_EMMC_WKS}"`                          | **PASS**                                   |
| No X11/Wayland in `IMAGE_INSTALL`                                | **PASS**                                   |
| `QT_QPA_PLATFORM=eglfs` via profile.d + environment.d            | **PASS**                                   |
| `packagegroup-qt6-essentials` (not minimal — documented)         | **PASS**                                   |
| `elevator-hmi-app` in `IMAGE_INSTALL`                            | **PASS**                                   |
| `gstreamer1.0` + `gstreamer1.0-plugins-base`                     | **PASS**                                   |
| `inherit qt6-cmake`                                              | **PASS**                                   |
| `DEPENDS = "qtbase qtdeclarative"`                               | **PASS**                                   |
| Installs to `/usr/bin/elevator-hmi` (via `CMAKE_INSTALL_BINDIR`) | **PASS**                                   |
| `LICENSE` set                                                    | **PASS**                                   |
| QML: `import QtQuick` (not Qt5 compat)                           | **PASS**                                   |
| QML: `Window` with visible element                               | **PASS**                                   |
| `bitbake -p elevator-hmi-image` — exit 0, 0 errors               | **PASS**                                   |


---

## 2026-04-17 — TASK-109 Qt EGLFS image + placeholder app (A2)

**Agent:** A2  
**Phase:** 1  

Implemented **TASK-109** on branch `**task/TASK-109-qt-eglfs-image`**: `**meta-hmi-app`** layer priority 9; `**elevator-hmi-image**` (`core-image` + `**rockchip-image**` + project `**WKS_FILE**`); `**packagegroup-qt6-essentials**` (substitution for non-existent `**packagegroup-qt6-minimal**` in pinned meta-qt6); `**QT_QPA_PLATFORM=eglfs**` via `**profile.d**` + `**environment.d**`; `**elevator-hmi-app**` stub (CMake + QML `**Window**` / `**elevator-hmi**` text) → `**/usr/bin/elevator-hmi**`. `**AGENTS.md**` TASK-109 → `**[REVIEW]**` with output notes.

**Smoke:** `kas shell kas/elevator-hmi.yml -c "bitbake -p elevator-hmi-image"` — exit **0**, **0** parse errors; `**bitbake-layers`** shows `**hmi-app`** at priority **9**.

**Next:** A1 review → `**[DONE]`** / merge; full image `**kas build elevator-hmi-image`** on TASK-002 host when ready.

---

## 2026-04-16 — TASK-108 merged [DONE], TASK-109 released to A2 (A1)

**Agent:** A1  
**Phase:** 1  

### TASK-108 — [DONE]

RAUC skeleton merged to `develop` (supervisor-approved after DISTRO_FEATURES fix). Deliverables:

- `meta-hmi-platform/conf/distro/elevator-hmi.conf` — project distro conf; `DISTRO_FEATURES:append = " rauc"` and `DISTRO_FEATURES:remove = "x11 wayland"` placed here (not in machine conf).
- `meta-hmi-platform/recipes-images/files/system.conf` — `compatible=elevator-hmi`; slots rootfs_a/b on `/dev/mmcblk0p4` / `p5`; `bootloader=u-boot`.
- `meta-hmi-platform/recipes-images/elevator-hmi-rauc-system-conf/elevator-hmi-rauc-system-conf.bb` — installs `system.conf` to `/etc/rauc/`.
- `meta-hmi-platform/conf/layer.conf` — `LAYERDEPENDS` includes `rauc`.
- `meta-hmi-platform/recipes-core/images/core-image-minimal.bbappend` — `rauc` and `elevator-hmi-rauc-system-conf` added to `IMAGE_INSTALL`.
- `scripts/rauc-gen-keys.sh` + `certs/README.md` — dev key generation script (gitignored certs).
- `meta-hmi-app/recipes-images/elevator-hmi-bundle.bb` — RAUC bundle stub (`inherit bundle`, `RAUC_BUNDLE_COMPATIBLE`), PLACEHOLDER comment.
- `kas/elevator-hmi.yml` — `distro: elevator-hmi`; `local_conf_header` block.

**Note:** `local_conf_header` DISTRO line is redundant with kas top-level `distro:` setting. Harmless. Clean up when kas manifest is next touched.

Branch `task/TASK-108-rauc-skeleton` deleted local and remote after merge.

### TASK-109 released to A2

Queue header updated: "TASK-109 `[READY]` — A2 pick up now." A2 should branch `task/TASK-109-qt-eglfs-image` from `develop`.

### Next actions

- A2: pick up **TASK-109** (branch `task/TASK-109-qt-eglfs-image` from `develop`).
- Owner: order LMT101SX006C panel (TASK-106 / BLK-006 unblock).
- Owner: run `./scripts/kas-build-task-105.sh` on TASK-002 host for deferred TASK-105 acceptance.

---

## 2026-04-16 — TASK-108: RAUC skeleton (A2)

**Agent:** A2  
**Phase:** 1  

### Summary

- `**meta-hmi-platform/recipes-images/files/system.conf`** + `**elevator-hmi-rauc-system-conf.bb`** → `**/etc/rauc/system.conf**`; `**LAYERDEPENDS**` `**rauc**`; `**core-image-minimal.bbappend**` installs `**rauc**` + config package; `**elevator-hmi-em3566.conf**` `**DISTRO_FEATURES:append = " rauc"**` (meta-rauc README).  
- `**scripts/rauc-gen-keys.sh**` + `**certs/README.md**`; `**.gitignore**` explicit `**certs/*.pem**`, `**certs/*.key**`; verified `**git add -A**` does not stage ignored key material.  
- `**meta-hmi-app/recipes-images/elevator-hmi-bundle.bb**` stub (`**inherit bundle**`, `**RAUC_BUNDLE_COMPATIBLE**`); `**meta-hmi-app/conf/layer.conf**` `**LAYERDEPENDS**` `**rauc**` + `**BBFILES**` for `**recipes-images/*.bb**`.  
- **Smoke:** `**kas shell … bitbake -p`** — 0 errors; `**IMAGE_INSTALL`** includes `**rauc**` `**elevator-hmi-rauc-system-conf**`. **Branch:** `**task/TASK-108-rauc-skeleton`**. `**AGENTS.md`** TASK-108 → `**[REVIEW]**`.

### Next

- A1: review TASK-108; then TASK-109 per queue (**after** 108 `**[DONE]`**).

---

## 2026-04-16 — TASK-110 merged, TASK-108 released to A2, BLK-008 logged (A1)

**Agent:** A1  
**Phase:** 1  

### TASK-110 — [DONE]

Supervisor-approved bbappend fixes merged to `develop` and synced to `main`:

1. `KERNEL_CONFIG:append` removed; replaced with `elevator-hmi-panel.cfg` fragment in `SRC_URI:append` — correct Yocto mechanism for kernel config options via `kernel_configme`.
2. `do_configure:append()` added to `install -m 0644` both DTS/DTSI files from `WORKDIR` into `${S}/arch/arm64/boot/dts/rockchip/` — required because non-patch `SRC_URI` files land in WORKDIR, not the kernel source tree.

Branch `task/TASK-110-bbappend-fix` deleted local and remote after merge.

### TASK-108 released to A2

A2 queue header updated: "TASK-108 `[READY]` — A2 pick up now. TASK-109 depends on TASK-108 done."
TASK-110 added to completed tasks table in AGENTS.md.

### BLK-007 numbering note

BLK-007 was already used (closed 2026-04-15 — Noble `libegl1-mesa`). New phandle validation blocker logged as **BLK-008**.

### BLK-008 logged

New open blocker: DTS phandle validation at bench — `vcc3v3_lcd0_n`, `vcca_1v8`, `backlight` assumed from BSP EVB2 tree. Must verify no `-ENOENT` errors in first-boot `dmesg`. Owner: A1 at TASK-106.

### Next actions

- A2: pick up **TASK-108** (branch `task/TASK-108-rauc-skeleton` from `develop`).
- Owner: order LMT101SX006C panel (TASK-106 / BLK-006 unblock).
- Owner: run `./scripts/kas-build-task-105.sh` on TASK-002 host for deferred TASK-105 acceptance.

---

## 2026-04-16 — Morning audit: branch cleanup, main sync, R-05, TASK-108/109 queued (A1)

**Agent:** A1  
**Phase:** 0 → 1  

### AUDIT-1 — Stale remote branch cleanup

All 5 merged task branches confirmed **FULLY_MERGED** into `develop` (zero unmerged commits):

- `task/TASK-101-lmt101-dts` — deleted local + remote
- `task/TASK-102-uboot-emmc` — deleted local + remote
- `task/TASK-103-core-image-minimal` — deleted local + remote
- `task/TASK-104-boardcon-machine-dts` — deleted local + remote
- `task/TASK-105-107-lab-handoff` — deleted local + remote

### AUDIT-2 — TASK-104 status

TASK-104 (`boardcon-machine-dts`) is `**[DONE]`** in `AGENTS.md` (archived, A1-reviewed 2026-04-15). My session-start report listed it implicitly under "TASK-101 through TASK-105 `[DONE]`" — terminology was not explicit enough. No action required.

### AUDIT-3 — develop / main sync

`develop` was 10 commits ahead of `main` (all from Phase 1 work: TASK-101 through TASK-107 merges and diary commits). Merged `develop` → `main` via `--no-ff`; pushed to `origin/main`. Both branches now at same commit.

### AUDIT-4 — R-04 checkbox closed

`CLAUDE.md` §2 Phase 0 checklist: R-04 checkbox **closed**. Line updated to: "Accepted — adaptive backlight dimming scheduled for Phase 3 (TASK-3xx). LED lifetime risk documented in R-04."

### BLK-006 → R-05

BLK-006 (JD9365D XRES reset line not mapped on EM3566 v3 CON1) escalated to **R-05** in `CLAUDE.md` §6 open risks table. Risk severity: **Medium**. Status: **OPEN** — bench validation required when LMT101 panel arrives. BLK-006 entry in `diary/BLOCKERS.md` remains unchanged (resolution criteria unchanged).

### TASK-108 and TASK-109 queued

- **TASK-108** `[READY]` — RAUC skeleton: `system.conf` (`compatible=elevator-hmi`, slots rootfs_a/b on mmcblk0p4/p5), `scripts/rauc-gen-keys.sh`, `certs/README.md`, `.gitignore` cert exclusions, `meta-hmi-app` bundle recipe stub, `rauc` added to image install.
- **TASK-109** `[READY]` — Qt/EGLFS image skeleton: `meta-hmi-app/conf/layer.conf` (BBFILE_PRIORITY 9, scarthgap, qt6-layer dep), `elevator-hmi-image.bb` (core-image + Qt 6 packages, EGLFS, no X11/Wayland), placeholder app recipe (`elevator-hmi-app_0.1.bb`). **Depends on TASK-108 `[DONE]`** — A2 must not start TASK-109 until TASK-108 is merged.

### Next actions

- A2: pick up **TASK-108** (branch `task/TASK-108-rauc-skeleton` from `develop`).
- Owner: order LMT101SX006C panel to unblock TASK-106.
- Owner: run `./scripts/kas-build-task-105.sh` on TASK-002 host and record green output here (deferred TASK-105 acceptance).

---

## 2026-04-15 — Session end summary (A2)

**Agent:** A2  
**Phase:** 0 / 1  

### Host / TASK-002

- **Ubuntu 24.04.4 LTS** (`schone`) confirmed as lab build host; repo text and `**scripts/setup-build-host.sh`** now allow `**VERSION_ID`** **22.04** or **24.04** with the same Scarthgap-oriented package list.
- **Noble package drift:** `**libegl1-mesa`** is not in Ubuntu **24.04** archives → script installs `**libegl1`** + `**libegl-mesa0`** on **24.04**, keeps `**libegl1-mesa`** on **22.04**.
- `**setup-build-host.sh`** run completed on owner host; `**command -v lz4c`** → `**/usr/bin/lz4c**`; `**kas --version**` → **5.2** (HOSTTOOLS / `**lz4c`** path unblocked).

### Kas smoke / TASK-105 / TASK-102

- `**kas dump kas/elevator-hmi.yml`**: **exit 0** (machine `**elevator-hmi-em3566`**, pinned layers).
- **Recipe append fix:** `**u-boot-rockchip_%.bbappend`** did not bind to `**u-boot-rockchip.bb`** → renamed `**meta-hmi-platform/recipes-bsp/u-boot/u-boot-rockchip.bbappend**`.
- **Smoke target fix:** Rockchip `**PREFERRED_PROVIDER_virtual/bootloader = u-boot-rockchip`** — `**scripts/kas-build-task-105.sh`**, `**docs/BRINGUP-CHECKLIST.md**`, `**scripts/README.md**` now use `**--target u-boot-rockchip**` and tee `**build-logs/u-boot-rockchip.log**` (not `**u-boot**`).
- **Still open for this host:** let `**kas build … --target u-boot-rockchip`** / full `**./scripts/kas-build-task-105.sh`** finish; then append **exit 0** evidence + `**ls -la build/tmp/deploy/images/elevator-hmi-em3566/`** (expect `**.wic`** after `**core-image-minimal**`) to a new diary line when done.

### Repo / diary / coordination

- `**README.md**`, `**CLAUDE.md**`, `**AGENTS.md**`, `**diary/BLOCKERS.md**` (new closed **BLK-007**) updated in this session.
- **Git:** session changes committed with `**[diary] 2026-04-15 session summary`**.

---

## 2026-04-15 — Phase B (TASK-105): `kas dump` OK; smoke script + U-Boot bbappend fixes (A2)

**Agent:** A2  
**Phase:** 1  
**Host:** Ubuntu 24.04.4 LTS (`schone`), `**lz4c`** + `**kas 5.2`** after `**setup-build-host.sh**`.

### Done

- **B1 / B2:** Repo root `**/home/sener/Projects/elevator-hmi`**; `**kas dump kas/elevator-hmi.yml`** exit 0 (machine `**elevator-hmi-em3566**`, layers as manifest).
- **B3 blockers fixed (repo):**
  1. `**u-boot-rockchip_%.bbappend`** did not apply to `**u-boot-rockchip.bb`** (unversioned recipe filename) → renamed to `**meta-hmi-platform/recipes-bsp/u-boot/u-boot-rockchip.bbappend**`.
  2. `**kas build --target u-boot**` invalid when `**PREFERRED_PROVIDER_virtual/bootloader = u-boot-rockchip**` → `**scripts/kas-build-task-105.sh**`, `**docs/BRINGUP-CHECKLIST.md**`, `**scripts/README.md**` now use `**--target u-boot-rockchip**` and log `**build-logs/u-boot-rockchip.log**`.
- **Docs:** `**README.md`**, `**CLAUDE.md`**, `**AGENTS.md**`, `**diary/PROGRESS.md**` references updated from `**u-boot-rockchip_%.bbappend**` to `**u-boot-rockchip.bbappend**`.

### In progress / next

- `**kas build kas/elevator-hmi.yml --target u-boot-rockchip**` was started to validate fixes (log: `**build-logs/u-boot-rockchip-smoke.log**`); first-from-scratch graph ~**1082** tasks — expect a long run. When it finishes, run `**./scripts/kas-build-task-105.sh`** for the full **u-boot-rockchip → virtual/kernel → core-image-minimal** sequence.
- **B4:** `**.wic`** appears under `**build/tmp/deploy/images/elevator-hmi-em3566/`** only after `**core-image-minimal**` succeeds — append `**ls -la**` of that dir + final log tail here when green.

---

## 2026-04-15 — Build host guidance: Ubuntu 24.04 LTS + script allow-list (A2)

**Agent:** A2  
**Phase:** 1  

### Summary

- Owner PC is **Ubuntu 24.04.4 LTS** with Yocto/poky minimal builds; repo copy still read as **22.04-only** after TASK-002.
- `**scripts/setup-build-host.sh`**: `**VERSION_ID`** may be 22.04 or 24.04 (same package list). `**lz4c**` / **HOSTTOOLS** failure on the earlier agent run was **missing `liblz4-tool`**, not an OS ceiling.
- Docs updated: `**README.md**`, `**scripts/README.md**`, `**docs/BRINGUP-CHECKLIST.md**`, `**CLAUDE.md**`, `**AGENTS.md**` (TASK-105 archive clarification), `**scripts/kas-build-task-105.sh**` header comment.

### Next

- On **24.04**: run `**./scripts/setup-build-host.sh`** once if deps are not pinned, then `**./scripts/kas-build-task-105.sh`**; append green `**exit 0**` + deploy listing to this diary when available.

---

## 2026-04-15 — TASK-105 / TASK-107 A1 review [DONE], merge to `develop` (A1)

**Agent:** A1  
**Phase:** 1  

### Review

- **TASK-107** `**[DONE]`** — `**docs/BRINGUP-CHECKLIST.md`** meets spec; `**README.md**` + `**library/EM3566/README.md**` links; in-repo citation paths verified.  
- **TASK-105** `**[DONE]`** — `**scripts/kas-build-task-105.sh`** + `**scripts/README.md**`; `**lz4c**` / HOSTTOOLS failure on **24.04** documented — **green build** still for owner on **TASK-002 22.04** (append success to `**diary/PROGRESS.md`**).  
- **Process:** combined branch `**task/TASK-105-107-lab-handoff`** — noted in `**AGENTS.md`**; prefer one task per branch later.

### Git

- Committed on task branch; `**develop**` merged (`--no-ff`); pushed `**origin/develop**`.

---

## 2026-04-15 — TASK-105 + TASK-107: kas smoke script + bring-up checklist (A2)

**Agent:** A2  
**Phase:** 1  

### Summary

- **TASK-105:** `**scripts/kas-build-task-105.sh`** + `**scripts/README.md`** section — sequential `**kas build**` (`**u-boot**`, `**virtual/kernel**`, `**core-image-minimal**`) with logs under `**build-logs/**` (gitignored). Ran three builds on Composer host → **HOSTTOOLS** failure (`**lz4c`** missing); logs captured. **Green image acceptance** remains for **Ubuntu 22.04 TASK-002** host. `**AGENTS.md`** TASK-105 → `**[REVIEW]`** with log excerpts.  
- **TASK-107:** `**docs/BRINGUP-CHECKLIST.md`** — TASK-002, kas commands, deploy dir, UART (`**EM3566_hardware_manual.md`** §2.14), **MIPI LCD**, flash doc pointers (**no** invented `**rkdeveloptool`** offsets). `**README.md`** + `**library/EM3566/README.md**` link to checklist. `**AGENTS.md**` TASK-107 → `**[REVIEW]**`.  
- **Branch:** `**task/TASK-105-107-lab-handoff`** (both tasks one linear branch; split commits if preferred).

### Next

- **Owner / TASK-002 host:** `**./scripts/kas-build-task-105.sh`** → confirm **exit 0**; paste deploy paths + log tails into `**AGENTS.md`** TASK-105 output notes (or new session).  
- **A1:** Review TASK-105 / TASK-107; `**[DONE]`** when satisfied.

---

## 2026-04-15 — A1 queue: TASK-105/107 READY, TASK-106 blocked (A1)

**Agent:** A1  
**Phase:** 1  

### Plan (next on roadmap after TASK-101–103)

1. **TASK-105** `**[READY]`** — On a **TASK-002** build host, run a **green `kas build`** (image + optional `**u-boot**` / `**virtual/kernel**`) and save **logs** under `**build-logs/`**; prove the Yocto stack end-to-end.
2. **TASK-107** `**[READY]`** — Single **bring-up checklist** doc (flash + UART + kas), linked from `**README.md`**, no guessed flash offsets.
3. **TASK-106** `**[BLOCKED]`** until **LMT101** is on hand — **DSI / BLK-006** bench and `**dmesg`** evidence.

### Later (not yet `[READY]` in queue)

- RAUC signing / bundle recipe (**keys** — new A1 task spec before A2).  
- Qt / EGLFS image + `**meta-hmi-app`** (roadmap Phase 2+).  
- `**main`** promotion vs `**develop**` (owner).

### Git

- `**AGENTS.md**` updated with **TASK-105**, **TASK-106**, **TASK-107** definitions.

---

## 2026-04-15 — TASK-103 A1 review [DONE], merge to `develop`, push (A1)

**Agent:** A1  
**Phase:** 1  

### Review

- **TASK-103** approved: `**core-image-minimal.bbappend`** inherits `**rockchip-image`** and sets `**WKS_FILE**` to `**ELEVATOR_HMI_EMMC_WKS**` (TASK-003); `**kas dump**` smoke OK; full `**kas build**` deferred to TASK-002 host (`lz4c` / BitBake), same as TASK-102/104.

### Git

- Committed on `**task/TASK-103-core-image-minimal**`, pushed; `**develop**` merged (`--no-ff`) and pushed.

### Optional — kas build logs (when a proper build host exists)

- On Ubuntu **22.04** after `**scripts/setup-build-host.sh`**, run e.g.  
`kas build kas/elevator-hmi.yml --target u-boot 2>&1 | tee build-logs/u-boot.log`  
`kas build kas/elevator-hmi.yml --target virtual/kernel 2>&1 | tee build-logs/kernel.log`  
`kas build kas/elevator-hmi.yml 2>&1 | tee build-logs/core-image-minimal.log`  
- Store under `**build-logs/`** (gitignored) or attach excerpts to `**diary/PROGRESS.md**` — not required for TASK-103 `**[DONE]**` sign-off.

### Next

- **A1:** Add next `**[READY]`** tasks in `**AGENTS.md`** (bench validation, image flash doc, RAUC, Qt, etc.).  
- **Owner / lab:** green `**kas build`** + first eMMC flash on **EM3566 v3**.

---

## 2026-04-15 — TASK-103: core-image-minimal + rockchip-image / project WIC (A2)

**Agent:** A2  
**Phase:** 1  

### Summary

- `**meta-hmi-platform/recipes-core/images/core-image-minimal.bbappend`**: `**inherit rockchip-image`** (Rockchip ext4 + WIC + kernel image layout per `**meta-rockchip**` class) and `**WKS_FILE = "${ELEVATOR_HMI_EMMC_WKS}"**` so images use `**wic/elevator-hmi-emmc.wks.in**` (TASK-003) instead of BSP default `**generic-gptdisk.wks.in**`.  
- **Branch:** `task/TASK-103-core-image-minimal` (from `**develop`**). `**AGENTS.md`**: TASK-103 → `**[REVIEW]**` with output notes.  
- **Smoke:** `**kas dump kas/elevator-hmi.yml`** succeeded. `**kas build`** not executed here — `**lz4c**` not on `**PATH**`; install `**liblz4-tool**` / TASK-002 host deps before BitBake (same as TASK-102/104 deferred smoke).

### Next

- A1: review TASK-103; on TASK-002 host run `**kas build kas/elevator-hmi.yml**` (+ optional `**virtual/kernel**` / `**u-boot**` targets).

---

## 2026-04-15 — TASK-102 A1 review [DONE], merge to `develop`, push (A1)

**Agent:** A1  
**Phase:** 1  

### Review

- **TASK-102** approved: `meta-hmi-platform/recipes-bsp/u-boot/` bbappend + `***.cfg`** fragment merged via Poky `**u-boot-configure.inc`** / `**merge_config.sh**`; `**UBOOT_LOCALVERSION**`; machine comments only. No community-layer edits. `**kas build … u-boot**` not proven on review host (`lz4c`) — deferred to TASK-002 / **TASK-103**.

### Git

- Committed on `**task/TASK-102-uboot-emmc`**, pushed; `**develop`** merged (`--no-ff`) and pushed.

### Next

- **A2:** `**TASK-103`** only in queue — branch from `**develop`**, then `**[REVIEW]**` for A1.

---

## 2026-04-15 — TASK-102: U-Boot eMMC Kconfig fragment + bbappend (A2)

**Agent:** A2  
**Phase:** 1  

### Summary

- `**meta-hmi-platform/recipes-bsp/u-boot/u-boot-rockchip.bbappend`** + `**files/elevator-hmi-emmc-boot.cfg`** — merge MMC / GPT / DW MMC / raw-partition options (aligned with vendor `rk3568_defconfig` at `SRCREV a93658f8…`); `UBOOT_LOCALVERSION = "-elevator-hmi-emmc"`.  
- `**elevator-hmi-em3566.conf**` — comments on eMMC bring-up, WIC, inherited `rk3568_defconfig`.  
- **Smoke:** `kas build kas/elevator-hmi.yml --target u-boot` — **failed** before BitBake (`**lz4c`** / HOSTTOOLS on review host).  
- **Branch:** `task/TASK-102-uboot-emmc`.

---

## 2026-04-15 — TASK-104 A1 review [DONE], merge to `develop`, push (A1)

**Agent:** A1  
**Phase:** 1  

### Review

- **TASK-104** approved: `meta-hmi-platform` machine + board DTS + DSI0 panel overlay + kas machine; community layers untouched. `**kas build … virtual/kernel`** not proven on review host (`lz4c`) — deferred to TASK-002 host / **TASK-103** acceptance.

### Git

- `**task/TASK-104-boardcon-machine-dts`:** A1 status commit (`AGENTS` / `CLAUDE` / `PROGRESS`); **pushed** to `origin`.  
- `**develop`:** merged task branch (`--no-ff`); **pushed** to `origin`.

### Next for A2 / owner

- `**git checkout develop && git pull`**, then **TASK-102** or **TASK-103** (one at a time).  
- Run `**scripts/setup-build-host.sh`** on the build machine, then `**kas build kas/elevator-hmi.yml --target virtual/kernel`** to close smoke.  
- Bench: **EM3566 v3 + LMT101** on **MIPI LCD** for **BLK-006** / DSI0 caveat.

### Next A1 session (prep)

- **Review queue:** When A2 submits `**[REVIEW]`**, run the same gate: community layers read-only, Scarthgap syntax, acceptance vs spec.  
- **TASK-104 follow-up:** Log a green `**kas build … virtual/kernel`** (or attach CI) when available; no new task unless DTS changes after bench.  
- **Specs:** Tighten **TASK-102** / **TASK-103** acceptance in `AGENTS.md` if A2 needs clearer U-Boot vs image boundaries (optional before pick-up).  
- **Product:** `**main`** promotion / release tagging remains **owner** decision; `develop` is now integration head through TASK-104.

---

## 2026-04-15 — TASK-104: A2 verification + commit on task branch (A2)

**Agent:** A2  
**Phase:** 1  

### Verification (against TASK-104 spec)

- **meta-hmi-platform only:** machine `elevator-hmi-em3566.conf`, board DTS include chain, panel `.dtsi` on `**&dsi0`** with BSP phandles, `linux-rockchip_%.bbappend` `SRC_URI`, `kas/elevator-hmi.yml` machine — matches task report.  
- **Community layers:** no `meta-rockchip` / `meta-qt6` / `meta-rauc` diffs in working tree.  
- **Smoke:** not green on review host (no `lz4c`); documented in `AGENTS.md` TASK-104 output notes.  
- **Hygiene:** fixed wrong script path in TASK-103 note (`scripts/setup-build-host.sh`).

### Git

- Committed all TASK-104 changes on `**task/TASK-104-boardcon-machine-dts`** for A1 review (later `**[DONE]`** on 2026-04-15).

---

## 2026-04-15 — Git: TASK-101 commits + merge to `develop` + push (A1)

**Agent:** A1  
**Phase:** 1 prep  

### Actions taken

- On `**task/TASK-101-lmt101-dts`:** three commits — `[phase1][kernel]` TASK-101 artifacts, `[docs]` `library/EM3566/README.md`, `[diary]` queue/blocker/CLAUDE/PROGRESS/BLOCKERS state.  
- `**develop`:** merged task branch (`--no-ff`); `**git push origin develop`**.  
- `**task/TASK-101-lmt101-dts`:** pushed to `origin` for archive. **A2** should `**git checkout develop` && `git pull`** before starting **TASK-104** (or any new task branch from current `develop`).

---

## 2026-04-15 — EM3566 v3 dev kit on hand; TASK-102/103 unblocked (A1 / owner)

**Agent:** A1 (state update — owner input)  
**Phase:** 1  

### Recorded

- Owner confirms **Boardcon EM3566 v3** (**CM3566**) dev kit **on hand**.  
- `**AGENTS.md`:** **TASK-102** and **TASK-103** set to `**[READY]`**; phase gate note updated; suggested A2 order **TASK-104 → TASK-102 → TASK-103**.  
- `**CLAUDE.md`:** Phase checklist — dev kit item checked **on hand**; `bitbake core-image-minimal` line clarified (panel + TASK-103 path).

---

## 2026-04-15 — TASK-101 reviewed [DONE]; TASK-104 queued; BLK-005 closed (A1)

**Agent:** A1 (Claude Code)  
**Phase:** 0 / Phase 1 prep  

### Actions taken

- **TASK-101** (branch `task/TASK-101-lmt101-dts`): A1 code review — **APPROVED → `[DONE]`**.  
  - **0002** patch: optional `reset-gpios`, `devm_gpiod_get_optional`, null-safe `prepare`/`unprepare`, 135 ms rail-delay path — matches **BLK-006** rationale; applies after **0001**.  
  - `**elevator-hmi-lmt101sx006c-panel.dtsi`:** `&dsi` / panel graph + merge guidance for existing `ports`; documents phandle placeholders.  
  - `**linux-rockchip_%.bbappend`:** Scarthgap `SRC_URI` / `KERNEL_CONFIG:append`; no community-layer edits.  
  - **Caveat recorded:** `elevator-hmi,lmt101sx006c` uses `cz101b4001_desc` until LMT101-specific timings are validated on silicon.  
  - **Reminder:** Commit `0002`, `.dtsi`, and `bbappend` on the task branch before owner merges to `main`/`develop` (working tree had uncommitted artifacts at review time).
- `**AGENTS.md`:** TASK-101 marked done; **TASK-104** `[READY]` — Boardcon machine DTS + `KERNEL_DEVICETREE` + kas/bitbake kernel smoke (spec in queue). TASK-102/103 remain blocked on dev kit + validated build.  
- `**CLAUDE.md`:** Phase 0 checklist — TASK-101 completion + TASK-104 pointer.  
- `**diary/BLOCKERS.md`:** **BLK-005** closed as *not in project scope* (OV13850). **BLK-006** remains open until bench.

### Next actions

- A2: branch `task/TASK-104-boardcon-machine-dts` (or similar), implement TASK-104 when BSP path is known.  
- Owner: commit/merge TASK-101 branch after verifying git state; EM3566 v3 + LMT101 bench for BLK-006.

---

## 2026-04-15 — TASK-102: U-Boot eMMC Kconfig fragment + bbappend (A2)

**Agent:** A2  
**Phase:** 1  

### Summary

- `**meta-hmi-platform/recipes-bsp/u-boot/u-boot-rockchip.bbappend`** + `**files/elevator-hmi-emmc-boot.cfg`** — merge MMC/GPT/raw-partition options aligned with vendor `**rk3568_defconfig**`; `**UBOOT_LOCALVERSION**`.  
- `**elevator-hmi-em3566.conf**` — eMMC / WIC / U-Boot inheritance comments.  
- `**kas build … --target u-boot`:** blocked on host `**lz4c`** (TASK-002 host setup).  
- **Branch:** `task/TASK-102-uboot-emmc`.

---

## 2026-04-15 — TASK-104: Boardcon EM3566 machine + LMT101 on DSI0 (A2)

**Agent:** A2  
**Phase:** 1  

### Summary

- Added `**meta-hmi-platform/conf/machine/elevator-hmi-em3566.conf`** (`require rockchip-rk3566-evb.conf`, `KERNEL_DEVICETREE = rockchip/elevator-hmi-boardcon-em3566-v3.dtb`).  
- Added `**elevator-hmi-boardcon-em3566-v3.dts`** including `**rk3566-evb2-lp4x-v10-linux.dts**` + rewrote `**elevator-hmi-lmt101sx006c-panel.dtsi**` as `**&dsi0**` overlay: `/delete-node/` stock EVB `panel@0` and `ports/port@1`, jadard `panel@0`, phandles `**vcc3v3_lcd0_n**`, `**vcca_1v8**`, `**backlight**` (from pinned `linux-rockchip_6.1` BSP DTS at `SRCREV ea9e2a93…`).  
- `**kas/elevator-hmi.yml`:** default `machine: elevator-hmi-em3566`. `**linux-rockchip_%.bbappend`:** `SRC_URI` for new `.dts`.  
- **Smoke:** `kas build … --target virtual/kernel` failed on this host — missing `**lz4c`** (`HOSTTOOLS`); document install + re-run.  
- **Branch:** `task/TASK-104-boardcon-machine-dts`.

---

## 2026-04-15 — `library/EM3566/README.md` (lab + compliance index)

**Agent:** A2  
**Phase:** 0 / 1  

Added `[library/EM3566/README.md](../library/EM3566/README.md)`: folder map, **EM3566 v3 + LMT101 / MIPI LCD** bring-up steps tied to **BLK-006**, in-repo doc pointers, and **owner-only** product/compliance notes (**R-01** / closed **BLK-001**, dev kit vs production carrier).

---

## 2026-04-15 — TASK-101: LMT101 / JD9365 DSI fragment + kernel follow-up patch (A2)

**Agent:** A2 (Composer)  
**Phase:** 1 prep  

### Summary

- Picked up **TASK-101** (DTS for JD9365 / LMT101SX006C). Delivered reference `**elevator-hmi-lmt101sx006c-panel.dtsi`** under `meta-hmi-platform/recipes-kernel/linux/files/` and `**0002-drm-panel-jadard-lmt101sx006c-compatible-optional-reset.patch`** (product `compatible`, optional `reset-gpios` in binding + `devm_gpiod_get_optional` in driver).  
- **Rationale:** EM3566 CON1 / in-tree schematic do not document **JD9365 XRES** → **RK3566 GPIO**; **BLK-006** opened. Patch 0002 avoids inventing a reset line while still allowing a valid DT node.  
- Extended `**linux-rockchip_%.bbappend`** with patch 0002, dtsi in `SRC_URI`, and `CONFIG_DRM_PANEL_JADARD_JD9365DA_H3=y`.  
- **Follow-up:** Boardcon machine DTS must `#include` the fragment (or merge `&dsi` content), align regulator/backlight labels, resolve `ports` merge if VOP `port@0` already exists; bench-validate on EM3566 v3 + LMT101.  
- Work on git branch `**task/TASK-101-lmt101-dts`**.

---

## 2026-04-16 — Interim SoM link: UART serial console (A1)

**Agent:** A1 (documentation)  
**Phase:** 0 / 1 prep  

### Decision captured

- While **elevator fieldbus** (RS-485 / CAN-FD) stays **deferred** (BLK-004), **Phase 0/1 “communication” to the SoM** is **UART serial** from a **host PC** to the board (**EM3566 v3** debug / UART headers per `library/EM3566/`) for **boot trace, image behaviour, systemd, RAUC**, and early logging.
- `CLAUDE.md` §1 **Protocol** row and §8 **PAL** bullets updated; **BLK-004** addendum in `diary/BLOCKERS.md`. Typical Rockchip BSP console **115200 8N1** noted as “confirm in BSP” — not a hardware spec from unverified GPIO numbers.

---

## 2026-04-16 — Reference hardware: EM3566 v3 carrier + MIPI LCD connector (A1)

**Agent:** A1 (documentation)  
**Phase:** 0 / 1 prep  

### Recorded in repo

- **Boardcon EM3566 v3** documented as the **reference development kit / carrier** for CM3566 (sources: `library/EM3566/` schematic, manuals, block diagram).
- Expert / board summary incorporated: multiple display paths (HDMI, LVDS, **MIPI LCD**, eDP, BT656); **LMT101 bench wiring** → **EM3566 v3 `MIPI LCD`** connector; underlying signals remain SoM **muxed LVDS/MIPI TX** (also routed to optional LVDS OUT).
- `CLAUDE.md` identity table + R-02; `diary/BLOCKERS.md` BLK-002 addendum; `AGENTS.md` gate note; **TASK-101** set to `**[READY]`** (R-02 mitigated; dependency is dev kit + panel in hand).

---

## 2026-04-15 — BLK-001–004 closed from owner/vendor inputs (A1)

**Agent:** A1 (documentation)  
**Phase:** 0  

### Blocker resolutions (see `diary/BLOCKERS.md`)

- **BLK-001 / R-01:** Vendor confirms CM3566 **operated 4 h @ −20°C ±2°C** in reliability testing; datasheet **recommended** range remains **0°C–70°C** — closed as **mitigated with documented caveat** (formal acceptance before production still advised).
- **BLK-002 / R-02:** Hardware manual: display lanes on SoM are **MIPI-DSI / LVDS multiplexed** (pins 25–34); FPC is on **carrier** — not “MIPI-only” at module. Closed with action: **carrier must select MIPI-DSI** for LMT101; schematic review on target carrier before layout lock.
- **BLK-003:** Backlight boost IC pick **deferred** — constant backlight acceptable for current LCD path.
- **BLK-004:** RS-485 vs CAN-FD **deferred** — no comms PHY planning for now; `CLAUDE.md` identity + PAL notes updated.

`CLAUDE.md` §2 checklist, §6 risks, and `AGENTS.md` Phase 0 gate note updated. **BLK-005** (OV13850 PDF) remains open, low severity.

---

## 2026-04-15 — TASK-002/003/004 reviewed and merged — Phase 0 A2 queue complete (A1)

**Agent:** A1 (Claude Code / product lead)  
**Phase:** 0 — Foundation & Risk Mitigation  
**Week:** 1  

### Reviews

#### TASK-004 — JD9365D backport patch — APPROVED


| Check                                                                                                        | Result |
| ------------------------------------------------------------------------------------------------------------ | ------ |
| Patch non-empty (588 lines), contains panel-jadard-jd9365da-h3.c driver                                      | PASS   |
| DT binding YAML (jadard,jd9365da-h3.yaml) included                                                           | PASS   |
| Makefile + Kconfig hunks present                                                                             | PASS   |
| No 6.2+ specific APIs (`drm_panel_init`, `drm_panel_of_backlight`, `mipi_dsi_`* DCS helpers — all in 6.1.99) | PASS   |
| `FILESEXTRAPATHS:prepend` uses colon syntax                                                                  | PASS   |
| `SRC_URI +=` appends patch with correct filename                                                             | PASS   |
| A2 confirmed `git apply --check` on clean 6.1.99 tree: OK                                                    | PASS   |


**Backport compatibility note:** Driver uses only standard DRM panel and MIPI DSI APIs present in 6.1.99. No 6.2-specific symbols identified. R-03 closed.

#### TASK-003 — WKS partition layout — APPROVED (with A1 fix)


| Check                                                             | Result                   |
| ----------------------------------------------------------------- | ------------------------ |
| Boot (64M vfat), rootfs_a (2048M), rootfs_b (2048M), data (4096M) | PASS                     |
| Total 8256M (~8.06 GB) within 16 GB eMMC                          | PASS                     |
| A/B RAUC intent documented in comments                            | PASS                     |
| `WICVARS:append` colon syntax, `ELEVATOR_HMI_EMMC_WKS` defined    | PASS                     |
| **Duplicate WICVARS block in layer.conf**                         | FIXED by A1 before merge |


A1 removed duplicate `WICVARS:append` + `ELEVATOR_HMI_EMMC_WKS` block that appeared twice in `layer.conf` (copy-paste error). Committed fix on branch before merge.

#### TASK-002 — Build host setup script — APPROVED


| Check                                                                                | Result |
| ------------------------------------------------------------------------------------ | ------ |
| `set -euo pipefail` at top                                                           | PASS   |
| Ubuntu 22.04 version check via `/etc/os-release`, clear error on wrong version       | PASS   |
| `liblz4-tool` in package list                                                        | PASS   |
| `kas` installed (apt universe + pip upgrade fallback), verified with `kas --version` | PASS   |
| `bitbake --version` verified via shallow poky clone + `oe-init-build-env`            | PASS   |
| Idempotent: apt `-y`, poky clone guard, pip `--upgrade`                              | PASS   |
| `scripts/README.md` documents usage and PATH note                                    | PASS   |


### Phase 0 queue state


| Task             | Status                              |
| ---------------- | ----------------------------------- |
| TASK-001         | `[DONE]`                            |
| TASK-002         | `[DONE]`                            |
| TASK-003         | `[DONE]`                            |
| TASK-004         | `[DONE]`                            |
| TASK-005         | `[DONE]`                            |
| TASK-101/102/103 | `[BLOCKED]` — human action required |


**All A2 Phase 0 tasks are complete.** Phase 0 gate is now blocked only on human-action items.

### Phase 0 gate — remaining human actions

- **BLK-001** (HIGH): Contact CM3566 vendor — confirm −20°C operating temp or decide on enclosure heater
- **BLK-002** (HIGH): Confirm MIPI-DSI routing on CM3566 carrier board display connector
- **BLK-003** (MEDIUM): Select backlight boost IC from candidates (TPS61187, RT4813, MP3309)
- **BLK-004** (MEDIUM): Decide protocol interface: RS-485 only vs RS-485 + CAN-FD

Phase 1 (BSP bring-up) cannot begin until BLK-001 and BLK-002 are resolved.

### Next actions

- Project owner: contact CM3566 vendor on BLK-001 and BLK-002 — these are the critical path items
- No new A2 tasks until Phase 1 gate opens

---

## 2026-04-15 — TASK-002, TASK-003, TASK-004 (A2, separate branches)

**Agent:** A2 (Composer2 / Cursor)  
**Phase:** 0  

### Summary

- **TASK-002** on `task/TASK-002-yocto-build-host`: `scripts/setup-build-host.sh` + `scripts/README.md` (Ubuntu 22.04, Scarthgap host deps, `kas`, cached shallow `poky` `yocto-5.0.16` for `bitbake --version` check). `AGENTS.md`: A2 branch reminder + TASK-002 → `[REVIEW]`.
- **TASK-003** on `task/TASK-003-partition-wks`: `meta-hmi-platform/wic/elevator-hmi-emmc.wks.in` + `WICVARS` / `ELEVATOR_HMI_EMMC_WKS` in `layer.conf`. Kickstart syntax checked with poky `wic.ksparser.KickStart` (not `wic ls` on a built image). TASK-003 → `[REVIEW]`.
- **TASK-004** on `task/TASK-004-jd9365d-kernel-backport`: unified patch from Linux v6.2 sources (`panel-jadard-jd9365da-h3.c`, binding YAML, Makefile/Kconfig); `git apply --check` on **v6.1.99** (`github.com/gregkh/linux`, tag `v6.1.99`, commit `cac15753b8ceb505a3c646f83a86dccbab9e33a3`) OK. `linux-rockchip_%.bbappend` applies patch. TASK-004 → `[REVIEW]`. `CLAUDE.md` §7 branching bullet tightened.

### Merge note for A1

Three branches from `main`; merge in any order, but expect sequential conflict resolution in `AGENTS.md` (each branch updates different task blocks — should merge cleanly).

---

## 2026-04-15 — TASK-001 reviewed [DONE], queue advanced (A1)

**Agent:** A1 (Claude Code / product lead)  
**Phase:** 0 — Foundation & Risk Mitigation  
**Week:** 1  

### TASK-001 Review — APPROVED

Reviewed `kas/elevator-hmi.yml`, both `layer.conf` files, sentinel recipes, README, and `.gitignore`.


| Check                                                                                  | Result |
| -------------------------------------------------------------------------------------- | ------ |
| All 5 external SHAs are 40-char (no floating branches)                                 | PASS   |
| meta-openembedded present (required by meta-rockchip)                                  | PASS   |
| `LAYERSERIES_COMPAT = "scarthgap"` in both layers                                      | PASS   |
| `machine: rockchip-rk3566-evb` (correct RK3566 target)                                 | PASS   |
| `build/conf/` in `.gitignore`                                                          | PASS   |
| `kas dump kas/elevator-hmi.yml` exits 0 — kas 5.2 verified all repos at pinned commits | PASS   |


No separate task branch existed (A2 committed on cursor branch, already in develop/main). No merge needed. TASK-001 → `[DONE]`.

Note: A branch naming rule added to AGENTS.md — A2 must use `task/TASK-NNN-`* branches going forward.

### TASK-005 — Already complete

44/45 PDFs converted (run in prior session). All `.md` files committed and pushed. See prior diary entry.

### Queue state after this session


| Task     | Status                                               |
| -------- | ---------------------------------------------------- |
| TASK-001 | `[DONE]`                                             |
| TASK-002 | `[READY]` — A2 can pick up                           |
| TASK-003 | `[READY]` — A2 can pick up (independent of TASK-002) |
| TASK-004 | `[READY]` — A2 can pick up (independent)             |
| TASK-005 | `[DONE]`                                             |


TASK-002 and TASK-004 are independent — A2 may work them sequentially in any order.

### Next actions

- A2: pick up TASK-002 (build host script), TASK-003 (WKS file), or TASK-004 (JD9365D patch) — one at a time
- Human: contact CM3566 vendor on BLK-001 (R-01 temp) and BLK-002 (R-02 MIPI routing)
- Human: set branch protection on main at github.com/DeodexLabs/elevator-hmi

---

## 2026-04-15 — Git remote initialized, all branches pushed

**Agent:** A1 (Claude Code)
**Phase:** 0 — Foundation

### Actions taken

- Replaced passphrase-protected `id_ed25519` with new passphrase-free ed25519 key (comment: [deodexlabs@gmail.com](mailto:deodexlabs@gmail.com))
- New public key registered to DeodexLabs GitHub account
- Remote `origin` added: `git@github.com:DeodexLabs/elevator-hmi.git`
- All branches pushed: `main`, `develop`
- Stray `cursor/phase0-workspace-scaffolding` branch deleted; wrong author `Your Name <you@example.com>` rewritten via filter-branch
- SSH connectivity confirmed: `Hi DeodexLabs!`

### Remote URL

[git@github.com](mailto:git@github.com):DeodexLabs/elevator-hmi.git

### SSH public key fingerprint

SHA256:58mjShl6zipVVJLIfQZb7HF/RF6C0Id3h4azKh9iJmk (ED25519, no passphrase)

---

## 2026-04-15 — TASK-005: Vendor PDF library converted to Markdown (A1)

**Agent:** A1 (Claude Code / product lead)  
**Phase:** 0 — Foundation & Risk Mitigation  
**Week:** 1  

### Actions taken

- Created `scripts/convert-library.sh` — converts all PDFs in `library/` recursively using `markitdown[pdf]`
- Moved script from repo root to `scripts/` (correct location per task spec)
- Fixed initial 45/45 failure: `markitdown` had been installed without PDF extras (`markitdown[pdf]` required)
- Updated `.gitignore`: changed `library/`** (excluded everything) to `library/**/*.pdf` (exclude only PDFs, track `.md` files)
- Ran conversion: **44/45 PDFs converted successfully**
- Added TASK-005 to AGENTS.md, marked `[DONE]`; added BLK-005 for the one failed file

### Conversion results


| Result       | Count |
| ------------ | ----- |
| Converted OK | 44    |
| Failed       | 1     |


**Failed:** `EM3566/Datasheet/Sensor_OV13850-G04A_OmniVision_Specification(V1.1).pdf`  
**Reason:** Scanned/image-only PDF — no embedded text layer. markitdown uses pdfminer (no OCR).  
**Severity:** LOW — OV13850 camera sensor is not used in the elevator HMI design. Documented as BLK-005.

### Notable conversions for HMI development


| File                                                             | Lines                                  |
| ---------------------------------------------------------------- | -------------------------------------- |
| `EM3566/Usermanual/CM3566_Hardware_Manual_V3.md`                 | 2,036                                  |
| `EM3566/Datasheet/Rockchip_RK3566_Datasheet_V1.5-20241211.md`    | 3,884                                  |
| `EM3566/Linux6.1/Usermanual/EM3566 linux6.1 user manual_V1.0.md` | 3,011                                  |
| `EM3566/Datasheet/K101-IM2KYL02-L3_MIPI.md`                      | 2,042 (MIPI panel — relevant for R-02) |
| `EM3566/Schematic/em3566_v3sch.md`                               | 1,341                                  |
| `EM3566/Datasheet/RTL8211F(D)(I)-CG_DataSheet_1.2.md`            | 6,166                                  |


### Next actions

- TASK-001 in [REVIEW] — A1 needs to review A2's kas manifest output.
- Project owner still needs to contact vendor on BLK-001 (R-01) and BLK-002 (R-02).
- TASK-002, TASK-003, TASK-004 remain [READY] for A2.

---

## 2026-04-15 — TASK-001 kas manifest and custom layers (A2)

**Agent:** A2 (Composer2 / Cursor)  
**Phase:** 0  

### Actions taken

- Implemented **TASK-001**: `kas/elevator-hmi.yml` with all upstream repos pinned to full SHAs; added `meta-openembedded` (`meta-oe`, `meta-python`) as required by `meta-rockchip` upstream.
- Added `meta-hmi-platform/` and `meta-hmi-app/` with `conf/layer.conf` and sentinel recipes for BitBake-parseable empty layers.
- Added root `README.md` (kas usage, layer table, `KAS_WORK_DIR` note).
- Verified `kas dump` and `kas shell … --skip setup_environ` (writes `build/conf/bblayers.conf` with correct layer order via kas `prio`). `bitbake-layers` blocked on this host by missing `lz4c` until TASK-002 host deps are installed.
- `.gitignore`: added `build/conf/` so kas-generated BitBake config is not committed.

### Task status

- TASK-001 → `[REVIEW]` in `AGENTS.md` (awaiting A1).

---

## 2026-04-15 — Project workspace initialized

**Agent:** A1 (Claude Code / product lead)  
**Phase:** 0 — Foundation & Risk Mitigation  
**Week:** 1  

### Actions taken

- Created workspace scaffolding: `CLAUDE.md`, `AGENTS.md`, `.cursor/rules/001-project.mdc`, `diary/`, `docs/`
- Loaded and reviewed all project documents: roadmap-v1.md, platform-decisions-v1.md, Vendor_Requirements_Specification.md, CM3566 hardware manual, LMT101 spec, RK3568 TRM, SKD41, ACM reference
- Initialized task queue in `AGENTS.md` with Phase 0 tasks (TASK-001 through TASK-004) and Phase 1 placeholders (TASK-101 through TASK-103, blocked)
- Created NotebookLM source guide at `docs/NOTEBOOKLM_SETUP.md`

### Phase 0 status

All 4 critical risks remain open:

- **R-01** (temperature floor): CM3566 spec is 0°C–80°C. Project needs −20°C. **Must contact vendor this week.**
- **R-02** (MIPI-DSI routing): Vendor Debian docs say "LVDS LCD." Physical confirmation required from CM3566 vendor before PCB layout.
- **R-03** (JD9365D backport): TASK-004 prepared in queue for Composer2. Driver source from Linux 6.2 tag.
- **R-04** (backlight lifetime): Accepted risk, Phase 3 mitigation (adaptive dimming). No action blocking Phase 1.

### Next actions

1. Project owner to contact CM3566 vendor on R-01 and R-02 this week (no agent can do this — requires human vendor contact).
2. A2 (Composer2) to begin TASK-001 (kas manifest + layer skeletons).
3. A2 to begin TASK-002 (build host setup script) in parallel with TASK-001.
4. A2 to begin TASK-004 (JD9365D backport patch preparation) — this is Phase 0 prerequisite.
5. Backlight boost IC selection required from project owner before Phase 1 BOM lock.

### Risks and blockers

- R-01 and R-02 are human-action items. Phase 1 cannot start while these are open.
- No code blockers at this stage.

---

*Diary initialized. Add new entries above this line.*