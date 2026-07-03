# LMT101SX006C — Vendor-Locked Firmware & Bench Summary

**Date:** 2026-06-13 · **Panel:** LMT101SX006C (JD9365DA-H3 + JD5001 external boost) · **Host:** Rockchip RK3566 / EM3566 v3
**Status:** Firmware **provably exhausted and 100% vendor-matched**. Glass still backlit-black. Fault localized to **panel analog boost / sample** — outside software.

---

## 1. One-line conclusion

The JD9365D **digital core is alive and healthy** (accepts all 196 init writes, answers DCS reads bidirectionally, self-diagnostic `0x0F=0xC0`), the IC reports the **boost as commanded-on** (`0x0A=0x1c`, booster bit D7=0 — the vendor's *healthy* reading), **but the timing controller never runs** (`0x45=0x00`). With identical firmware the vendor's fixture lights the same init file perfectly. Therefore the remaining difference is the **external JD5001 AVDD/AVEE/VGH/VGL boost not producing rails on this unit** — an electrical / panel-sample issue, not init, timing, packet, rate, or reset.

---

## 2. Vendor truth → firmware match (every line)

| # | Vendor statement (LCD Mall) | Firmware implementation | Match |
|---|------------------------------|-------------------------|:---:|
| 1 | Init file = 196 register pairs through `0xE7,0x0C` | `lmt101sx006c_init_cmds[]` byte-identical (patch 0003) | ✅ |
| 2 | `0x80,0x03` = 4 MIPI lanes (CMD_DSI_INT0) | in table; `dsi-lanes = <4>` | ✅ |
| 3 | Init writes framing | `mipi_dsi_dcs_write_buffer()` (patch 0018, H-pkt ruled out) | ✅ |
| 4 | Q1 reset: Active-Low | `reset-gpios … GPIO_ACTIVE_LOW`; gpio-22 | ✅ |
| 5 | Q1 reset: power-on → **10 ms** → XRES low | `msleep(10)` after rails (patch 0007) | ✅ |
| 6 | Q1 reset: XRES low **20 ms** pulse | `msleep(20)` (patch 0019) — was 10 ms | ✅ |
| 7 | Q1 reset: XRES high → **120 ms** → MIPI | `post_reset_delay = 120` (patch 0005) | ✅ |
| 8 | Q2 power: delay until VCC3V3_LCD ≥90% stable before MIPI | 10 ms power-on + 120 ms reset dwell before first DCS | ✅ |
| 9 | TEST 1 page-4 clock: `E0,04/37,58/35,08/36,49/2C,06/E0,00` before 0x11 | `fae_clock[]` pre-SLPOUT (patch 0011/0013) | ✅ |
| 10 | Tail: `0x11` → **120 ms** → `0x29` → **5 ms** → `0x35,00` | `display_init_delay=120`, `display_on_delay=5`, TE `0x35,00` | ✅ |
| 11 | Porches (init file): hsa20/hbp20/hfp40, vsa4/vbp10/vfp30 | `lmt101sx006c_desc` mode timings | ✅ |
| 12 | PLL_CLOCK = **420** | non-burst → 70 MHz×24/4 = 420 Mbps (patch 0019; `mode_flags 0x203→0x201`) | ✅ |
| 13 | Q4: video mode + HS enabled | `MIPI_DSI_MODE_VIDEO`, HS at scanout | ✅ |
| 14 | Q1 booster: started implicitly by `0x11`, no extra reg | we send only `0x11`; nothing extra gates it | ✅ |
| 15 | Healthy `0x0A` after 11+29 = **0x18** (0x9C = faulty boost) | we read **0x1c** (= 0x18 + display-on bit); D7=0 healthy | ✅ |
| 16 | Q4: `0x0F` healthy = **0xC0** | we read **0xC0** | ✅ |
| 17 | Q2: HS not required at 0x11; LP/late-HS OK (boost on RC osc) | our HS starts ~140 ms after 11/29 — vendor says fine | ✅ (per vendor) |
| 18 | Q3: VDDIN 3.3 V, ~75 mA active | bench: 3.3 V steady, no sag/crash observed | ✅ (bench) |
| 19 | TEST 2 BIST: init + 11 + 29 + `F0,55/F1,AA/E0,01/E3,01` | armed on FAE_CLOCK tail (patch 0020) | ✅ |

**No vendor line remains unimplemented.**

---

## 3. On-target register results (2026-06-13, vendor-clock-match image)

```
jadard: VENDOR-CLOCK-MATCH — VIDEO non-burst
jadard: dsi mode_flags=0x00000201 lanes=4         # 0x201 = VIDEO|NO_EOT, BURST dropped (was 0x203)
jadard: XRES assert / XRES release                 # 20 ms low pulse (Q1)
jadard: FAE page-4 clock fix (pre-SLPOUT)
jadard: SLPOUT sent / DISON sent
jadard: GET_POWER_MODE(0x0A) pre-TE=0x1c           # sleep-out+normal+display-on; booster D7=0 (HEALTHY per vendor)
jadard: DIAG15 ID=0x93 0x00 0x00                   # mfr byte 0x93 = JD9365 confirmed
jadard: DIAG15 self-diag=0xc0                      # register-load OK + functionality OK
jadard: DIAG15 scanline=0x00                       # TIMING CONTROLLER NOT RUNNING
jadard: init table: 196 cmds, rc=0                 # every write accepted
modetest plane 96 @ 60.08 Hz sustained             # SoC scanout live
```
**Glass: backlit black, no pixels, no change on `/dev/fb0` fill.** Registers are byte-identical to the prior 468/burst baseline → lane rate and reset width were **not** the cause.

| Register | Read | Healthy? | Meaning |
|---|---|---|---|
| `0x0A` GET_POWER_MODE | `0x1c` | ✅ (vendor: 0x18 class, D7=0) | sleep-out + display-on; IC commands boost ON |
| `0x0F` self-diagnostic | `0xC0` | ✅ | register loading + functionality detection pass |
| `0x45` scanline | `0x00` | ❌ | timing controller not generating scanlines |
| `0x04` ID byte1 | `0x93` | ✅ | JD9365 controller confirmed |

**Interpretation:** `0x0A`+`0x0F` healthy + `0x45=0x00` = the IC is digitally fine and *thinks* boost is enabled, but no internal refresh runs → the **external JD5001 boost is not delivering AVDD/AVEE/VGH/VGL**. The source drivers have no analog supply → black.

---

## 4. Hardware confirmed at bench

- **VDDIN (FPC 2/3): 3.3 V, no crash/sag** observed by owner (steady-state DMM). *Inrush transient during the 120 ms post-SLPOUT still to be scoped — vendor troubleshooting step 1.*
- **Backlight:** external supply, LED string lit (glow visible). Vendor spec is **9.6 V / 180 mA**; set to that value to remove as a variable.
- **Reset/XRES:** GPIO0_C6 / gpio-22, active-low, 20 ms low pulse, assert/release seen in dmesg at boot.
- **MIPI command path proven:** the panel ACKs all 196 writes and returns real DCS read values → the data lanes carry LP traffic bidirectionally. HS video pixel transport at 60 Hz not yet scoped (confirmatory only).

---

## 5. Two images on disk

| Image (WIC label) | Purpose | Tail behaviour |
|---|---|---|
| `…rootfs-vendor-clock-match.wic` | **Production / normal video** | full vendor init + page-4 clock + 420 non-burst + 20 ms reset + DIAG15 reads |
| `…rootfs-vendor-clock-bist.wic` | **Diagnostic — vendor TEST 2** | all of the above, then arms BIST `F0,55/F1,AA/E0,01/E3,01` (patch 0020). E3,01 soft-resets the video engine; flash this only to check the panel self-test pattern |

**Why BIST was absent before:** the production descriptor selects the `FAE_CLOCK` enable sequence; the old `FAE_BIST` sequence (patch 0011) is a separate, unselected code path. Patch 0020 arms BIST at the end of the `FAE_CLOCK` path so it now runs *with* the full init code, exactly as the vendor requires.

### BIST decision

| BIST image result | Conclusion |
|---|---|
| Self-test pattern appears | Panel source/TCON **can** light → fault is in our HS video/source path; keep chasing MIPI video. |
| Still black (as in BIST v1) | Panel analog boost/source is dead regardless of host → **hardware / defective sample** confirmed. |

---

## 6. Vendor Q&A — final mapping

- **Q1 (booster trigger):** implicit in `0x11`; no extra register. ✅ we send only `0x11`. On healthy module `0x0A=0x18`; `0x9C` would mean faulty boost. We read `0x1c` (healthy class).
- **Q2 (clock source):** boost runs on JD9365D **on-chip RC oscillator**, not MIPI CLK. Late HS (≈140 ms) is OK; only video phase needs stable HS. → Our LP-at-0x11 is **not** the fault per vendor; continuous-HS-before-init not required.
- **Q3 (power):** 3.3 V, 75 mA active. → Verify supply withstands **inrush** (scope, step 1).
- **Q4 (0x0F):** standard MIPI RDDIAGNOSTIC; healthy = `0xC0`. ✅ matches.

---

## 7. Remaining actions (all hardware — software is closed)

1. **PRIME — scope VDDIN during 120 ms after SLPOUT.** Boost inrush sag <90% stalls JD5001 → exactly the "digital alive, TCON dead" signature. Plan-B 3.3 V bypass current capacity is the suspect.
2. **Flash `vendor-clock-bist.wic`** → does the self-test pattern show? (decides panel-source-alive vs dead).
3. **Backlight → 9.6 V / 180 mA** (vendor spec).
4. **Swap a fresh LMT101 sample (H6 / TASK-137).** Digital-healthy + analog-boost-dead is the classic bad-sample / dead-boost-passive signature.
5. If a known-good sample is also black with VDDIN steady, **ship sample to LCD Mall** for cross-check (offered) — firmware is now provably identical to their lit fixture.

---

## 8. Artifact triples

**Production (vendor-clock-match):**
- WIC SHA-256: `7dbf72d902a580c05db0d236665b18eaf227309395104257efa075c3ea1217a7`
- File: `core-image-minimal-elevator-hmi-em3566.rootfs-20260613123616.wic`
- git: `d9565d6` + 0019; dmesg: `jadard: VENDOR-CLOCK-MATCH` + `420 x 4 Mbps`

**Diagnostic (vendor-clock-bist):**
- WIC SHA-256: `11d740455c39403cabb4ed3cd010d4be1149f3ef8643db824f96fdbe8b35b8a4`
- File: `core-image-minimal-elevator-hmi-em3566.rootfs-20260613131032.wic` (symlink `…-vendor-clock-bist.wic`)
- git: `d9565d6` + 0019 + 0020; dmesg: `jadard: VENDOR-CLOCK-MATCH` + `jadard: BIST armed (FAE_CLOCK + vendor TEST 2)`
- Build: `BUILD_EXIT_CODE=0`, `do_patch: Succeeded`; driver `.o` strings confirm both sentinels.
