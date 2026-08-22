# BLOCKERS.md — Active Blockers and Questions

**Owner:** A1 (Claude Code)  
**Format:** Open blockers at top. Closed blockers moved to archive at bottom.

---

## Open Blockers

### BLK-015 — KMS scanout never reaches the panel (VOP2/VP1) — ✅ **RESOLVED 2026-08-22**

> **RESOLUTION: the DSI panel was on the wrong video port. VP1 cannot latch
> plane updates on this board; VP0 can.**
>
> **Proof on glass (2026-08-22):** with `&dsi0_in_vp0 { status = "okay"; }` and
> `&dsi0_in_vp1 { status = "disabled"; }`, `modetest -M rockchip -s
> 191:800x1280` displays a **stable colour grid** on the panel. On VP1 the same
> command — and every KMS client including Qt/EGLFS — produced nothing for
> weeks; only writes into the boot-latched buffer via `/dev/fb0` ever appeared.
>
> **Register confirmation:** `RK3568_REG_CFG_DONE` (fe040000) is self-clearing.
> During a STATIC modeset on VP0 it reads `0x00008000` — VP0 bit CLEAR, so the
> hardware consumed the config-done and transferred shadow → active.
>
> **Why we inherited the bad port:** the Rockchip EVB gives VP0 to HDMI because
> it ships an HDMI display, pushing DSI to VP1
> (`rk3566-evb2-lp4x-v10.dtsi:190/194/541`, `rk3568-evb.dtsi:1077`). Right for
> the EVB, wrong for a product with no HDMI.
>
> **Two wrong turns worth remembering:**
> 1. VP0 was proposed early, then dropped after reading Boardcon's **LVDS** DTB,
>    where DSI is disabled and its port assignment is a meaningless default.
>    Their MIPI dtsi does use VP1 — but their shipped Linux images are LVDS/HDMI
>    only, so that path was evidently never validated on this silicon.
> 2. Sampling `REG_CFG_DONE` during `modetest -v` shows the VP bit set almost
>    always, because a flip is nearly always pending at 60 Hz. That is NORMAL.
>    Reading it as "the hardware never consumes config-done" produced a
>    confident, wrong conclusion — and nearly buried the correct fix. **Probe
>    that register with a STATIC modeset only.**
>
> **Consequence:** the `linuxfb` + software-rendering workaround is no longer
> required. EGLFS/Mali and zero-copy VPU video (ADR-001, CLAUDE.md §1) are
> unblocked.
>
> Also eliminated by test along the way, so nobody re-treads them: the
> drm/rockchip backport (vendor display path byte-identical, patch at `924fd3b`),
> the logo/loader route, the legacy-cursor hack (not in our branch), and the
> IOMMU (attached, group 9).

#### Original report (2026-08-18)
**Opened:** 2026-08-18
**Severity:** HIGH for media — **worked around for UI** (linuxfb), see below.

**Symptom.** No KMS client can put a new buffer on the panel. Qt/EGLFS, and
**`modetest` with a plain dumb buffer**, are equally invisible. Only writes
*into the framebuffer that is already latched* (`/dev/fb0`) ever appear.

**Evidence (all measured on target 2026-08-18, serial console).**
- `modetest -M rockchip -s 191@112:800x1280` sets the mode ("setting mode
  800x1280-60.08Hz on connectors 191, crtc 112") — glass unchanged.
- `modetest -v` runs at a steady **60.08 Hz**; VOP IRQ 46 (`fe040000.vop`)
  advances 33703 → 33823 in 2 s = exactly 60/s. **vblank and page flips work.**
- With `rockchipdrm debug=1` (`VOP_DEBUG_PLANE`), the driver logs the correct
  address **every frame**:
  `vp1 update Smart1-win0[800x1280@(0,0)->800x1280@(0,0)] zpos[1] fmt[XR24]
  addr[0x00000000bb8000] ... by kworker/u8:0`, alternating with the second
  flip buffer. So the **driver is programming scanout correctly**.
- Two independent planes on VP1 (`Smart1-win0` **96** and `Esmart1-win0` **120**)
  active simultaneously, each with its own buffer — **neither latches**.
- While a client owned the plane, writing into the fbdev buffer still changed the
  glass → the hardware never left the buffer latched at boot.
- **No** IOMMU page faults, no VOP errors in `dmesg`.
- Full modeset teardown IS visible (Ctrl+C on modetest flashes the panel off/on),
  so modesets reach hardware; only plane/buffer updates fail to latch.
- Single display device: `card0` = `rockchip display-subsystem`; `card1` is the
  **NPU** (`rknpu`). `/dev/fb0` is `rockchipdrmfb` on that same device.

**Falsified — do NOT retry:** `YRGB_MST` reading `0x0` (it reads 0 even when the
display works — write-only/shadowed); dead vblank; fbdev/fbcon fighting the
client (with fbcon unbound the two addresses are just the client's own
front/back buffers, 121 vs 120); per-plane bug; kernel config gaps
(`CONFIG_ROCKCHIP_VOP2=y`, `ROCKCHIP_DW_MIPI_DSI=y`, `PHY_ROCKCHIP_INNO_DSIDPHY=y`,
`ROCKCHIP_IOMMU=y` all set); `loader_protect` (only gates `vop2_clk_reset`).

**Workaround IN EFFECT (UI only).** `QT_QPA_PLATFORM=linuxfb` +
`QT_QUICK_BACKEND=software` — Qt renders in software directly into `/dev/fb0`,
the path that provably works. **Verified on glass 2026-08-18**: red/green test
QML, then `/usr/bin/elevator-hmi` itself. The init script also unbinds
`vtcon1` because fbcon draws into the same `/dev/fb0`.

**Why this is still HIGH.** The workaround costs the **Mali GPU** (ADR-001
assumed EGLFS/Mali) and, more seriously, **GStreamer zero-copy VPU video
(CLAUDE.md §1 Media) needs DRM planes and cannot composite through linuxfb.**
Video is impossible until this is fixed.

### 2026-08-22 — vendor BSP compared; candidate fix = disable the logo route

The vendor materials were in `library/` all along — I previously said they were
not, having searched too narrowly. `library/EM3566/Linux6.1/` holds four
prebuilt images **and** a 20 GB BSP source tarball containing
**`boardcon-em3566-v3-v3.0-mipi.dtsi`** — Boardcon's own MIPI-DSI config for
this exact board.

#### FALSIFIED: "DSI is on the wrong video port"

First hypothesis was that VP1 was at fault and dsi0 should move to VP0, based on
their **LVDS** image's DTB. **Wrong.** In that build DSI is disabled, so its port
assignment is an unused default. Boardcon's actual MIPI config uses **VP1, same
as us**:
```
boardcon-em3566-v3-v3.0-mipi.dtsi:314  &dsi0_in_vp0 { status = "disabled"; };
boardcon-em3566-v3-v3.0-mipi.dtsi:318  &dsi0_in_vp1 { status = "okay";     };
boardcon-em3566-v3-v3.0-mipi.dtsi:322  &route_dsi0  { status = "disabled";
                                                     connect = <&vp1_out_dsi0>; };
```
The VP0 change was built, then reverted before ever being flashed. **VP1 is not
the problem.**

#### CANDIDATE: `route_dsi0` — the U-Boot logo handover

The real difference in that same block: the vendor sets `route_dsi0` to
**disabled**. We inherit `rk3566-evb2-lp4x-v10.dtsi:541`, which sets it `okay`.

`rockchip_drm_show_logo()` walks the `route` children and skips unavailable
ones, so an `okay` route makes the kernel adopt the bootloader's display. That
path calls `vop2_crtc_loader_protect(crtc, true)`, which bypasses atomic commit
entirely (`rockchip_drm_vop2.c:6804`):
```c
vp->loader_protect = true;
vop2->active_vp_mask |= BIT(vp->id);
vop2_initial(crtc);
if (VOP_WIN_GET(vop2, win, enable)) {   /* primary win already on from U-Boot */
        win->pd->ref_count++;
        vp->enabled_win_mask |= BIT(win->phys_id);
}
drm_crtc_vblank_on(crtc);
```
It adopts the window the loader left enabled and marks it owned. That is the
shape of BLK-015: commits accepted, vblank running, correct address programmed
every frame, hardware still scanning the boot buffer.

**Applied:** `&route_dsi0 { status = "disabled"; }` — one variable, matching the
vendor. Verified in the rebuilt DTB (`route-dsi0 disabled`, DSI still VP1).

Image: `images-archive/qt-hmi-noroute.wic`
SHA256 `809f19968c8fe0b650ea2a806b8c5751234459cd54f52c416be41ca82b882327`

**NOT CONFIRMED** — board powered off all session. Kill test:
```
modetest -M rockchip -s <connector>@<crtc>:800x1280
```

#### 2026-08-22 RESULT — route fix FALSIFIED; driver proven correct

Flashed `qt-hmi-noroute.wic` and ran the kill test on target. **Glass showed
white — modetest still invisible. BLK-015 unchanged.**

`dmesg` also showed the logo path was already inert regardless:
```
OF: fdt: Reserved memory: failed to reserve memory for node 'drm-logo@0' ... size 0 MiB
rockchip-drm display-subsystem: failed to parse loader memory
```
`rockchip_drm_show_logo()` returns at `init_loader_memory()` **before** it
iterates the routes, so `vop2_crtc_loader_protect()` was never reached even with
`route_dsi0` enabled. The hypothesis was wrong on its own terms.

Useful by-product: with the plane state reporting `addr: 0x0`, the panel still
displayed the `/dev/fb0` white fill. **So `/dev/fb0`'s memory IS the buffer
latched at boot** — which is precisely why writing to it is the only thing that
has ever worked.

#### THE DECISIVE MEASUREMENT — the driver is doing everything right

With `rockchipdrm debug=9` (`VOP_DEBUG_PLANE | VOP_DEBUG_CFG_DONE`), during a
4-second modetest run: **241 plane updates, 243 cfg_done writes**, paired 1:1:
```
vp1 update Smart1-win0[800x1280@(0,0)->800x1280@(0,0)] zpos[1] fmt[XR24] addr[0x3e8000]
cfg_done: 0x8002
vp1 update Smart1-win0[800x1280@(0,0)->800x1280@(0,0)] zpos[1] fmt[XR24] addr[0x7d0000]
cfg_done: 0x8002
```
`0x8002` = `RK3568_VOP2_GLB_CFG_DONE_EN (BIT 15) | BIT(1)` = **the VP1 latch
trigger**. A "missing `<<16` write-mask" theory was checked and **rejected**: the
driver carries an explicit comment that on RK3568 the VP config-done bits "stand
on the first three bits ... **without mask bit**". 0x8002 is correct.

So, every frame at 60 Hz, the driver:
1. programs the new scanout address,
2. writes the correct config-done latch trigger for VP1,
and the hardware keeps scanning the buffer latched at boot.

**Conclusion: this is not a DTS problem and not a userspace problem. The driver
issues correct register writes that the hardware does not act on.**

#### STRONGEST REMAINING LEAD — our VOP2 driver is older than the vendor's

The BSP source contains a materially different driver:

| | `rockchip_drm_vop2.c` |
|---|---|
| Boardcon rkr5 (Mar 2025) | **451,378 bytes** |
| ours (meta-rockchip pin) | **423,258 bytes** |

3,541-line diff; **28 functions exist only in the vendor's driver**, including:
- `vop2_handle_post_buf_empty` + rate limiter — the VOP2 display-FIFO underrun
  interrupt. **We have no handler for it at all.**
- `vop2_set_aclk_rate` — our DTB carries `rockchip,aclk-normal-mode-rates` but
  our driver has no code to consume it.
- `vop2_iommu_fault_handler`

meta-rockchip's pinned `linux-rockchip` is not Boardcon's BSP. For this board the
BSP is the reference.

**Recommended next step:** build against the vendor VOP2 driver — either move the
kernel to Boardcon's `em3566_linux6.1-rkr5` or backport
`drivers/gpu/drm/rockchip/` from it. That is a substantial change and should be
its own task, but it is now the best-supported path and everything cheaper has
been eliminated.

#### 2026-08-22 — ROOT CAUSE MEASURED: the VOP never consumes config-done

`RK3568_REG_CFG_DONE` (fe040000) is **self-clearing**: the driver writes
`GLB_CFG_DONE_EN | BIT(vp->id)` and the VOP consumes it at frame start, clearing
the bit. Sampled directly from `/sys/kernel/debug/dri/0/regs`:

| State | Register | Meaning |
|---|---|---|
| idle, VP1 | `0000c000` | no pending bit |
| modetest on **VP1** | `0000c002` x10 | **VP1 bit stuck set** |
| idle, VP0 | `00008000` | no pending bit |
| modetest on **VP0** | `00008001` x10 | **VP0 bit stuck set** |

**The VOP consumes config-done on NEITHER video port.** Shadow registers
therefore never transfer to the active bank, and the VP keeps scanning whatever
was latched at boot. This single fact explains every symptom seen since
2026-08-18.

And it is not for want of frames — the VP is demonstrably running:
- line counter at `fe040060` advances (`007d` -> `03d7` -> `022e`)
- vblank IRQ 46 fires 60/s
- the panel shows live content from the boot-latched buffer
- the driver programs the right address AND the right cfg_done value every
  frame (rockchipdrm debug=9: 241 plane updates / 243 cfg_done writes, 1:1)

The driver cannot detect it: `vop2_pending_done_bits()` returns 0 early when the
only pending bit belongs to the calling VP, so nothing verifies it cleared.

#### FALSIFIED BY TEST (not by argument)

- **Move DSI to VP0.** Built, flashed, measured: VP0 bit sticks exactly like
  VP1. Not port-specific.
- **Backport Boardcon's drm/rockchip.** Their vop2 driver is 28 KB larger, but
  every display-path function is byte-identical
  (`vop2_cfg_done`, `rk3568_vop2_cfg_done`, `vop2_crtc_atomic_flush`,
  `vop2_wait_for_fs_by_done_bit_status`, `vop2_win_atomic_update`,
  `vop2_plane_atomic_update`, `vop2_crtc_atomic_enable`, `vop2_initial`,
  `vop2_win_enable`). Their kernel would behave the same. Patch abandoned;
  preserved at commit `924fd3b`.
- `route_dsi0` logo handover, DTS port routing, the legacy-cursor hack (not in
  our branch), the IOMMU (`Adding to iommu group 9` — attached), our userspace.

#### STATUS: ESCALATE

A VOP that scans frames continuously but never consumes config-done on any
video port is a hardware/BSP defect. It is not fixable in our DTS, our
userspace, or by taking the vendor's driver.

**Defect report for Boardcon / Rockchip:**
> RK3566 (Boardcon EM3566 v3, CM3566 SoM), kernel 6.1.57-rockchip-standard from
> meta-rockchip. VOP2 scans out normally: line counter advances, vblank at
> 60 Hz, panel displays the buffer latched at boot. But `REG_CFG_DONE` bit for
> the active VP never clears — sampled 10x during a `modetest -v` run on VP1
> (`0x0000c002`) and again after re-routing DSI to VP0 (`0x00008001`). The
> driver writes the correct value (`GLB_CFG_DONE_EN | BIT(vp)`) and the correct
> plane address every frame. Consequently no plane update ever reaches the
> hardware, and the only way to change the display is writing into the
> already-latched framebuffer via /dev/fb0. Reproduced with `modetest` and a
> plain dumb buffer, so no Qt/Mali/GBM involvement.

Workaround in production use: `linuxfb` + software rendering (writes into the
latched buffer). Costs the Mali GPU and makes zero-copy VPU video impossible.

#### Separate lead for the `wrap 52` hack (not BLK-015)

Vendor: `dsi,flags = <(MIPI_DSI_MODE_VIDEO | MIPI_DSI_MODE_VIDEO_BURST | MIPI_DSI_MODE_LPM)>`
Ours (patch 0019): `MIPI_DSI_MODE_VIDEO | MIPI_DSI_MODE_NO_EOT_PACKET`, burst
deliberately OFF for the LMT101 path ("VENDOR-CLOCK-MATCH, PLL_CLOCK=420").
A constant horizontal shift that wraps is the classic signature of a DSI/VOP
timing mismatch in **non-burst** mode; burst re-syncs each line. Worth testing
as a single variable after BLK-015 is settled.

#### Two free confirmations from the vendor DTB

- No RK809 PMIC node at all — this board genuinely has none.
- `sdmmc0` uses one regulator for both `vmmc`/`vqmmc` and has **no
  `sd-uhs-sdr104`** — independently the same shape as our SD fix.

**Tracked in:** `CLAUDE.md` §2, `docs/FLASH-PROCEDURE.md`,
`meta-hmi-app/recipes-qt/elevator-hmi-app/files/elevator-hmi.init` (revert notes).

---

## Resolved Blockers

### BLK-014 — LMT101 backlit black with full DRM scanout — ✅ **RESOLVED 2026-08-07**
**Opened:** 2026-06-02 — **Closed:** 2026-08-07
**Severity was:** HIGH — blocked Phase 1 display gate
**Owner:** lead (single-agent)

> **RESOLUTION — THE PANEL WORKS. IT WAS NEVER A HARDWARE FAULT.**
>
> **Proof (2026-08-07):** a full-screen white fill of `/dev/fb0` on the running
> board displayed **plain white on the glass**; a half-buffer fill displayed a
> clean **white/black split** (correct addressing and orientation). 1000×4096 =
> 4,096,000 B = exactly 800×1280×4 (XR24) = the whole framebuffer. Backlight
> leakage cannot produce this. `/sys/kernel/debug/dri/0/summary` concurrently
> showed `Video Port1: ACTIVE`, DSI-1, 800x1280p60, `clk[70000] real_clk[70000]`,
> H 800/840/860/880 and V 1280/1310/1314/1324 (exactly the vendor porches),
> `Smart1-win0: ACTIVE` XR24 800x1280.
>
> **Two causes, in sequence:**
> 1. **Real bug — DSI init ordering (fixed by patch 0021, INIT-IN-PREPARE).**
>    This vendor kernel's `dw-mipi-dsi` switches the host to VIDEO mode in
>    `bridge_atomic_enable()` **before** calling `drm_panel_enable()`. Our
>    mainline-style jadard driver sent the entire vendor bring-up (196-cmd table,
>    page-4 clock fix, SLPOUT, DISON) from `enable()` — i.e. as HS commands
>    inside the blanking of an already-running video stream, so the panel got
>    video packets before it was ever initialised. Patch 0021 moved the whole
>    sequence into `prepare()` (command mode, pre-video), matching the vendor
>    fixture and Rockchip's own `simple-panel-dsi`.
> 2. **Why the fix stayed invisible for ~2 weeks — `CONFIG_FRAMEBUFFER_CONSOLE`
>    was not set.** `/dev/fb0` existed (DRM fbdev emulation) but nothing ever
>    rendered into it; a zero-filled framebuffer is a correctly-displayed BLACK
>    screen. Every "still black" observation after 0021 was the panel faithfully
>    showing black. Enabled 2026-08-07 (+ `CONFIG_LOGO`).
>
> **Process lesson:** patch 0021's kill test was written as *"pattern/fbcon
> visible OR 0x45 non-zero"*, then validated **only via BIST** (patches
> 0022/0024) — an instrument that has never produced a positive result on this
> panel and therefore could not be trusted to report a negative one. The
> framebuffer-content half of the same kill test was never re-run after 0021
> landed. A correct fix was repeatedly graded by a broken measuring device.
>
> **Red herrings, formally closed:** `0x45 scanline = 0x00` (not a reliable
> liveness indicator here); `0x0A` bit7 "booster off" (the vendor's OWN healthy
> fixture reads `0x18`, bit7 also clear — never indicated a fault); `0x0F=0xC0`
> was the panel correctly reporting itself healthy the entire campaign — it was
> right. "Both panels black" — both panels are **fine**; identical symptom
> because the cause was host-side firmware, shared by both tests.
>
> **Hardware fully exonerated:** 3.3 V rail, XRES timing (scope-verified 20 ms),
> MIPI lanes (all four + clock proven by working HS command traffic), FPC
> wiring, VCC3V3_LCD load switch. Owner's measurements were correct throughout.
>
> **Vendor:** LCD Mall was pursuing a non-existent hardware fault on our report.
> Correction owed — panels are not defective, no RMA or cross-test needed.

**Historical record of the investigation is preserved below and in
`diary/SESSION-LOG.md`.**

**2026-07-22 — VENDOR BIST TEST EXECUTED: BLACK ON BOTH PANEL UNITS — hardware
branch of vendor's own criterion.** Fresh BIST image (`bist-468.wic`, WIC SHA
`de0e0b60…`, git `e7871a9`): full 196-cmd init + page-4 fix + SLPOUT/DISON +
vendor TEST 2 arm (`F0,55/F1,AA/E0,01/E3,01`), clean DIAG15 in same boot
(`0x0A=0x1c`, `0x0F=0xC0`, `0x45=0x00`, rc=0), sentinel `BIST armed` logged.
Glass black on unit #1 AND spare unit #2, backlight lit, watched 30+ s. Ran on
the **stock VCC3V3_LCD switch path** (bypass jumper removed — see BLK-013
supersede note). Per vendor 7/7: "Still black → panel or JD5001 boost circuit
is faulty – hardware issue confirmed." Zero-trust firmware audit same day:
init table 196/196 byte-identical by script; reset/porches/enable path all
vendor-exact. **No further firmware permutations planned.** State-dump reply
drafted (`docs/VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL-4.txt`, questions A–G incl.
PLL_CLOCK semantics, analog-rail pin map for DMM, 3rd ask of peak-inrush spec,
boost-architecture contradiction, disposition). **Blocker now waits on vendor
answer / hardware disposition.**

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
