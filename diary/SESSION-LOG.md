# SESSION-LOG.md — Elevator HMI Display Bring-Up (post task-queue-protocol)

**Format:** One entry per session, newest at bottom (append-only). No `TASK-NNN` IDs, no
`[REVIEW]/[TESTING]` status machinery — see rescue-lead charter, 2026-07-03, for why this
file replaces that model going forward. `AGENTS.md` / `diary/PROGRESS.md` / `diary/BLOCKERS.md`
remain the historical record through 2026-06-13 and are not actively maintained past this point.

Trust tiers (charter §1): Tier 1 = owner/vendor direct statement. Tier 2 = scope/DMM reading or
verbatim dmesg with artifact triple. Tier 3 = prior agent conclusion — re-derive, don't trust the
label. Every entry below states its tier.

---

## 2026-06-14 — [TRANSCRIBED FROM CHARTER, NOT INDEPENDENTLY VERIFIED — Tier 3 until confirmed]

**Source:** rescue-lead charter §5, handed to this agent 2026-07-03. This entry exists so the
result is not lost again; it has not been corroborated against a primary log by this agent — no
dmesg, photo, or artifact triple for this specific flash/observation exists anywhere in the repo.

- Action: flashed a no-BIST vendor-match rebuild (0018 DCS-init + 0019 clock-match, 0020 BIST
  disarmed), 9.6 V backlight, at git `d9565d6` + uncommitted DTS/DTSI/bbappend changes (now
  committed as `6eb2f37`, see 2026-07-03 entry below).
- Kill test defined before acting: not recorded.
- Result reported: **green noise, gray flashing, quick vibration, corner vignetting** during the
  init phase — not flat black. WIC SHA reported as `438091ef…` (not independently re-hashed by
  this agent; no file by that prefix exists on this disk currently — rebuild required to
  reproduce).
- Two loose observations from the same session, per charter: (a) switching toward 420 Mbps broke
  DCS diagnostic reads (`-110 ETIMEDOUT`); (b) `dmesg` reportedly showed `dclk_vop1` = 700,000,000
  Hz against an expected 70 MHz.
- Conclusion (as handed down): booster/source drivers/analog pixel path are alive; HS data is
  arriving; the fault reframes from "dead hardware" to "misconfigured/mistimed."
- Next: reconcile against source-level findings below (2026-07-03 entry) before treating this as
  settled.

---

## 2026-07-03 — Charter handoff, repo grounding, git housekeeping, and one concrete source-level finding

**Agent:** new lead (this session) · **Tier:** 2 (own repo/source inspection) unless marked otherwise

### Actions taken

1. **Adopted the rescue-lead charter** as the operating protocol for this project going forward
   (task-queue protocol in `AGENTS.md` retired per charter §0/§7).
2. **Verified git state independently** (Tier 2 — ran the commands myself):
   - `HEAD` was `d9565d6` on `task/TASK-139-dcs-init`, matching the charter's claimed baseline
     exactly.
   - Found and cleared a stale, fully-empty `.git/rebase-apply/` (orphaned since 2026-06-10, no
     actual patch/todo data inside it — same phantom state `diary/STATE-2026-06-10.md` had
     already flagged and recommended clearing).
   - Working tree had substantial **uncommitted** changes sitting behind that phantom state:
     `AGENTS.md`, `diary/BLOCKERS.md`, `diary/PROGRESS.md`, two docs, the board DTS, the panel
     DTSI, the bbappend, plus untracked patches `0018`/`0019`/`0020` and two new `STATE-*.md`
     files. Owner authorized committing this as a housekeeping checkpoint (no content edits by
     this agent) — done as commit `6eb2f37` on `task/TASK-139-dcs-init`. Left untouched as
     probable junk (not committed, not deleted): `**The` (0-byte stray file), `MainActivity.java`
     (0-byte, unrelated to this project), a duplicate root-level copy of
     `LMT101SX006C initial codes.txt` (the canonical tracked copy is
     `library/LMT101/LMT101SX006C initial codes.txt`), `.claude/`, `build/` (63 GB Yocto tmp — do
     not ever add), `j3/` and `tmp_jd9365/` (small mainline/vendor reference source trees, kept
     local/untracked as reference material, not project-authored code).
3. **Searched the repo for the charter's Section 5 result** — confirmed it is genuinely absent:
   no `2026-06-14` date string, no "green noise"/"vignette"/"vibration" language anywhere in
   tracked or untracked files (excluding `build/`). The two `.cap` files at repo root
   (`bootandlcdtestlogs.cap`, `minicom.cap`) are **not** that session's log — they're dated
   2026-05-10 (a CSI/camera-probe capture, unrelated to the DSI panel path) and 2026-04-18 (early
   pre-panel boot log) respectively. Transcribed the charter's Section 5 into the entry above so
   it stops being an orphaned fact living only in a handoff document.
4. **Found undocumented in-flight work directly in the DTS/DTSI source** (part of the same
   uncommitted diff, now committed as `6eb2f37`) that the charter did not mention and that
   `AGENTS.md`/`diary/BLOCKERS.md` never recorded — call it **TASK-141** informally (source
   comment already uses that label) even though there is no task-queue entry for it:
   - **XRES drive-strength fix.** Comment in `elevator-hmi-boardcon-em3566-v3.dts`: with the panel
     *connected*, the XRES release edge (GPIO0_C6 / CON1 pin 11) could not pull back HIGH into
     the panel load, while it toggled cleanly with the panel *disconnected*. With `&spi0` and
     `&gt1x` disabled (TASK-121/TASK-132 history), the pad reverts to its weakest default drive
     strength. Fix: added a `&pinctrl` node forcing `RK_FUNC_GPIO` + `pcfg_pull_up_drv_level_15`
     (max drive + pull-up) on that pin, wired into the panel node via `pinctrl-names`/`pinctrl-0`.
     **This is a real, previously-unrecorded finding** — the reset line was electrically marginal
     under actual panel load throughout the entire campaign to date, on every prior "digitally
     healthy but black" bench result. It does not by itself explain black-vs-lit, but it means
     every register read/write and reset-pulse-width measurement taken before this fix was made
     against a possibly-marginal reset release, not a clean one.
   - **Lane-rate DT override removed** (`rockchip,lane-rate = <420>` deleted from
     `elevator-hmi-lmt101sx006c-panel.dtsi`), with an in-source note: "at 420 + non-burst (patch
     0019) all BTA reads failed with -110... testing without lane-rate override to isolate
     whether the PHY rate or the non-burst mode is the cause of BTA failure." This confirms the
     `-110` read failures charter §5/§6 mentions were observed specifically with the explicit
     420 Mbps DT override *present*, not simply from patch 0019 alone.

### Finding: patch 0019's rate claim does not do what the diary says it does

Read `dw-mipi-dsi-rockchip.c` (the actual pinned kernel source, present locally at
`build/tmp/work-shared/elevator-hmi-em3566/kernel-source/drivers/gpu/drm/rockchip/dw-mipi-dsi-rockchip.c`,
lines 607–644, `dw_mipi_dsi_calculate_lane_mpbs()`) directly — Tier 2, verbatim source, not
inferred:

```c
/* optional override of the desired bandwidth */
if (!of_property_read_u32(dev->of_node, "rockchip,lane-rate", &value)) {
        target_mbps = value;
} else {
        mpclk = DIV_ROUND_UP(mode->clock, MSEC_PER_SEC);
        if (mpclk) {
                /* take 1 / 0.9, since mbps must big than bandwidth of RGB */
                tmp = mpclk * (bpp / lanes) * 10 / 9;
                ...
```

**This function never inspects `mode_flags`.** `MIPI_DSI_MODE_VIDEO_BURST` (what patch 0019 drops
in `jadard_dsi_probe()`) has **zero effect** on the computed PHY bit rate. The only two things
that change `target_mbps` are (a) the `rockchip,lane-rate` DT property, taken verbatim if present,
or (b) the pixel-clock-derived `10/9`-margin formula if it is absent. For this panel's descriptor
(`.clock = 70000` kHz, confirmed byte-for-byte in patches 0001/0003 — not a typo, not a units bug):
`70 MHz × (24bpp/4lanes) × 10/9 ≈ 466.7 → rounds to 468 Mbps`. That arithmetic is exactly the
"≈468 Mbps" the in-source comment predicts once the override is removed, and exactly the number
the entire campaign measured before TASK-140.

**Consequence:** the `7dbf72d9…` "VENDOR-CLOCK-MATCH" build that reported `420 x 4 Mbps` in dmesg
achieved that rate *only* because `rockchip,lane-rate = <420>` was present in the DTB at the time
— not because of patch 0019's mode_flags change. That DT property has since been deleted (as the
"revert-step-a" BTA isolation step). **The current committed tree (`6eb2f37`, same source that
would produce a rebuild of the `438091ef…` / green-noise config) is therefore running at ~468
Mbps again, not the vendor's stated PLL_CLOCK=420** — vendor-match mismatch #14 is silently back
open, and every future dmesg check must read the actual `final DSI-Link bandwidth: ... Mbps` line
rather than assume "0019 is applied" implies 420.

This also means the charter §6 "unreconciled discrepancy" (clean reads at one 420 Mbps build vs.
`-110` timeouts at another) most likely was never a 420-vs-420 comparison at all: the clean-read
build ran at a DT-forced-and-untested-against-BTA-issues 420, and the failing build was a
different, not-yet-isolated combination (rate override present + something else — possibly
interacting with the not-yet-applied XRES drive-strength fix, since that fix and the override
removal landed in the same uncommitted diff and were never bisected against each other).

**Kill test proposed (not yet run — no patch written, per charter rule 1):** on the *next* build,
capture the exact `dmesg` line reading `final DSI-Link bandwidth: ... Mbps` (or equivalent) instead
of assuming it from which patches are `SRC_URI`-active. If vendor-exact 420 Mbps is still wanted,
`rockchip,lane-rate = <420>` must be reinstated in the DTSI — but only as a single isolated change
from whatever the next baseline is, per charter rule 3 (one hypothesis in flight).

### Checked and ruled out (this session, no bench needed)

- **`dclk_vop1` = 700 MHz claim (charter §5/§7 item 4):** the static mode descriptor
  (`.clock = 70000` in both `0001` mainline-backport patch and `0003` vendor-init patch) is
  correctly 70 MHz in kHz units — not a units/typo bug in the tracked source. If a fresh capture
  still shows 700,000,000 Hz, that would need a *dynamic* explanation (not this descriptor); the
  much more mundane explanation — a `70000000` vs `700000000` one-digit misread while transcribing
  a fast bench session — fits the evidence better given the old (2026-05-10) capture in this repo
  shows the correct `dclk: 70000000` / `set dclk_vop1 to 70000000, get 70000000` for the same
  70 MHz mode. **Still needs the owner's fresh verbatim `dmesg | grep -i dclk_vop` to close** —
  requested, not yet received.

### Owner input this session (Tier 1)

- No oscilloscope/logic analyzer on hand right now; reset-line and lane voltage levels were
  checked previously (consistent with the TASK-141 finding above — this was almost certainly what
  motivated that fix). Owner's explicit direction: don't default to blaming hardware right now.
- Spare LMT101SX006C panel **on hand** (H6 test is available without waiting on an order).
- CM3566/EM3566/LMT101/JD9365D remains the committed platform.
- Vendor (LCD Mall) is still responsive; they've asked what happened to the project since — a
  status reply is owed to them, not the other way around. No new unlogged technical reply from
  them.
- Not sure exactly what's flashed on the bench right now beyond "the latest one tested" — needs
  confirming against the artifact triple before the next physical test.

### `dclk_vop1` — CLOSED (2026-07-03, Tier 2, owner capture)

Owner ran `dmesg | grep -i dclk_vop` on the board as currently flashed (login prompt visible
in the same capture, i.e. a fresh boot, not a stale buffer):

```
[    3.386420] rockchip-vop2 fe040000.vop: [drm:vop2_crtc_atomic_enable] set dclk_vop1 to 70000000, get 70000000
```

**70,000,000 Hz = 70 MHz exactly, requested value == actual value.** Matches the static
descriptor (`.clock = 70000` kHz) and the old 2026-05-10 capture. The charter §5/§7-item-4 "700
MHz" claim does **not** reproduce on this hardware right now. Verdict: almost certainly a
one-digit transcription slip during the original 2026-06-14 session, not a real driver/DT bug.
**Do not spend further time on this axis.**

Still open: which exact build this dmesg was captured against (see Next item 1 below) — matters
for correctly attributing this reading, though the 70 MHz pixel clock is independent of the
420-vs-468 lane-rate question (different clock domains: `dclk_vop1` is the RGB/pixel clock into
the DSI encoder, not the DSI PHY bit rate itself).

### Next (in order, no scope required)

1. **Owner to confirm exactly which WIC/git state produced the capture above** — need this to
   know if `mode_flags`/lane-rate were 0019-clock-match-only (`7dbf72d9…`), the reverted/no-DT-
   override state (would show ~468 Mbps), or something else. Ask for `dmesg | grep -iE
   "jadard|bandwidth|mode_flags"` from the same boot to get this for free.
2. Rebuild `6eb2f37` clean, capture the actual `final DSI-Link bandwidth: ... Mbps` line, and
   treat 420-vs-468 as a **separate, explicit, single-variable test** from the XRES
   drive-strength fix — do not re-conflate them like the pre-existing uncommitted diff did.
3. **H6 spare-panel swap** remains the cheapest, equipment-free, most decisive test available
   (charter §7 item 3) and can run in parallel with (1)–(2) whenever convenient on the bench.
4. Draft and send the vendor status update LCD Mall is waiting on (owed regardless of firmware
   findings) — separate from this technical thread, flag when ready to draft.

---
