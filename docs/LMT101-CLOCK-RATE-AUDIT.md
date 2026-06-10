# LMT101 — DSI clock / rate coherence audit (no code changes)

**Date:** 2026-06-02  
**Context:** FAE reports “MIPI rate mismatch” may cause backlit-black; bench reported **468 × 4 Mbps** while vendor init cites **PLL_CLOCK=420**.  
**Purpose:** Pull **actual** numbers from in-tree sources; compare requested vs measured vs vendor.

---

## 1. Mode timings — `lmt101sx006c_desc` (patch `0003`)

**Source:** `meta-hmi-platform/recipes-kernel/linux/files/0003-drm-panel-jadard-lmt101sx006c-vendor-init.patch`

| Field | In-tree value | Vendor `LMT101SX006C initial codes.txt` |
|--------|---------------|----------------------------------------|
| Active H × V | 800 × 1280 | (implicit) |
| hfront_porch (hfp) | **40** | horizontal_frontporch **40** |
| hsync (hsa) | **20** | horizontal_sync_active **20** |
| hback_porch (hbp) | **20** | horizontal_backporch **20** |
| vfront_porch (vfp) | **30** | vertical_frontporch **30** |
| vsync (vsa) | **4** | vertical_sync_active **4** |
| vback_porch (vbp) | **10** | vertical_backporch **10** |
| `.clock` (kHz) | **70000** | PLL_CLOCK **420** (see §3) |

**Porches:** byte-for-byte match with vendor snippet header.

**Totals:**

- `htotal` = 800 + 40 + 20 + 20 = **880**
- `vtotal` = 1280 + 30 + 4 + 10 = **1324**

**Implied pixel clock from mode line @ 60 Hz:**

```
f_pixel = htotal × vtotal × refresh
        = 880 × 1324 × 60
        = 69,955,200 Hz ≈ 69.96 MHz
```

**`.clock = 70000` kHz** → **70.000 MHz** — within **~0.06%** of computed 69.96 MHz (DRM rounding).

---

## 2. Expected DSI lane rate (from mode + RGB888 + 4 lanes)

```
lane_rate = f_pixel × bpp / lanes
          = 70.0e6 × 24 / 4
          = 420.0 Mbps per lane
```

| Quantity | Value |
|----------|--------|
| Pixel clock (requested) | **70.0 MHz** |
| bpp (RGB888) | **24** |
| Lanes | **4** |
| **Expected lane rate** | **420 Mbps** |
| Vendor **PLL_CLOCK** | **420** |
| **Delta (vendor vs expected)** | **0%** (same number) |

Vendor **PLL_CLOCK=420** aligns with **420 Mbps/lane** derived from our DRM mode, not 420 MHz pixel clock.

---

## 3. Measured on bench (2026-06-02 `dmesg`)

```
dw-mipi-dsi-rockchip: final DSI-Link bandwidth: 468 x 4 Mbps
```

| Quantity | Value |
|----------|--------|
| **Reported lane rate** | **468 Mbps** |
| **Expected (§2)** | **420 Mbps** |
| **Absolute delta** | **+48 Mbps (+11.4%)** |

Rockchip DSI host rounded **up** from the mode-derived target. The FAE page-4 register block (`0x37/0x35/0x36/0x2C` on page **0x04**) is intended to reconcile panel-side MIPI rate with SoC — **BUILD B** (`0013`).

---

## 4. Where 468 Mbps comes from (Rockchip path)

**Not re-derived from a live `kas build` kernel tree in this audit** — host may lack full BitBake tree. Mechanism (pinned **linux-rockchip 6.1** BSP):

1. DRM mode → `dw_mipi_dsi_encoder_mode_set()` / Rockchip DSI driver computes **lane byte clock** from `mode->clock`, format, and lane count.
2. DPHY PLL picks nearest supported multiplier/divider → often **rounds up** to a discrete Mbps step.
3. `dmesg` line **“final DSI-Link bandwidth: N x L Mbps”** is the **post-PLL** per-lane HS bit rate.

**Requested rate (software intent):** ~**420 Mbps/lane** from **70 MHz** × 24 / 4.  
**Actual rate (hardware):** **468 Mbps/lane** — **+11.4%**.

---

## 5. Summary table

| Layer | Requested / expected | Actual / measured | Match? |
|--------|----------------------|-------------------|--------|
| Porches H/V | vendor file | `lmt101sx006c_desc` | **YES** |
| Pixel clock | ~69.96 MHz computed | `.clock` **70 MHz** | **YES** |
| Lane rate (calc) | **420 Mbps** | **468 Mbps** (`dmesg`) | **NO (+11.4%)** |
| Vendor PLL_CLOCK | **420** | maps to **420 Mbps** calc | **YES** |
| DCS 0x0A after DISON | display-on bit set | **0x18** (sleep-out, **not** display-on) | **NO** |

**0x0A = 0x18:** bit 4 (0x10) sleep-out set; bit 2 (0x04) display-on **clear** — consistent with FAE “rate mismatch / display not latched” even after `0x29`.

---

## 6. Recommended validation after BUILD B

1. Cold boot → `dmesg | grep -i jadard` — confirm **“FAE page-4 clock fix”** and **“FAE TE on”**.
2. Re-read **`GET_POWER_MODE(0x0A)`** — expect display-on bit (0x04) set if panel accepted DISON.
3. Note whether **`468 x 4 Mbps`** changes (may stay 468; panel-side regs may not alter SoC PHY report).
4. Run **`modetest … -P 96 … -F tiles -v`** — visual check.

**BUILD A (BIST)** runs first: if internal pattern appears, panel/glass path is OK and BUILD B targets MIPI data path only.

---

*Files cited: `0003-drm-panel-jadard-lmt101sx006c-vendor-init.patch`, `library/LMT101/LMT101SX006C initial codes.txt`, `diary/PROGRESS.md` 2026-06-02.*
