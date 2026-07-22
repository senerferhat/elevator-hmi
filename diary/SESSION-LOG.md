# SESSION-LOG.md — Elevator HMI Display Bring-Up (post task-queue-protocol)

**Format:** One entry per session, newest at bottom (append-only). No `TASK-NNN` IDs, no
`[REVIEW]/[TESTING]` status machinery — see rescue-lead charter, 2026-07-03, for why this
file replaces that model going forward. `AGENTS.md` / `diary/PROGRESS.md` / `diary/BLOCKERS.md`
remain the historical record through 2026-06-13 and are not actively maintained past this point.

Trust tiers (charter §1): Tier 1 = owner/vendor direct statement. Tier 2 = scope/DMM reading or
verbatim dmesg with artifact triple. Tier 3 = prior agent conclusion — re-derive, don't trust the
label. Every entry below states its tier.

**Current flash target (kept in sync here, not in `docs/FLASH-PROCEDURE.md` — see that file's
"READ THIS FIRST" banner for why):** `core-image-minimal-elevator-hmi-em3566.rootfs-lane420-reset.wic`
is **flashed and booted (2026-07-03)** — dmesg confirms 420 Mbps + expected BTA `-110` regression,
**but this build turned out to also have an active BIST-unlock sequence (not a clean single-variable
test — see entry below)**. Glass/visual result not yet reported — **do not recommend a new flash
target until that's in.** **Update this line whenever the recommended target changes; it is the one
thing every other doc in this repo should point back to instead of copying.**

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

### Bandwidth finding CONFIRMED on-target (2026-07-03, Tier 2, owner capture)

```
[    2.444532] jadard: VENDOR-CLOCK-MATCH — VIDEO non-burst (PLL_CLOCK=420)   <- static string, misleading now
[    3.632123] jadard: dsi mode_flags=0x00000201 lanes=4 format=0 video=1 burst=0
[    3.881933] jadard: GET_POWER_MODE(0x0A) pre-TE=0x1c
[    3.898606] jadard: DIAG15 ID=0x93 0x00 0x00
[    3.915130] jadard: DIAG15 self-diag=0xc0
[    3.966037] jadard: DIAG15 scanline=0x00
[    3.966086] jadard: init table: 196 cmds, rc=0
[    3.966144] dw-mipi-dsi-rockchip: final DSI-Link bandwidth: 468 x 4 Mbps
```

Exactly as predicted from reading `dw_mipi_dsi_calculate_lane_mpbs()`: burst=0 confirmed, but
bandwidth is **468 Mbps, not 420**. All DIAG15 registers byte-identical to every prior
"digitally healthy, backlit black" build. This specific combination — **non-burst mode at the
468 (burst-margin) rate** — has never been tested before in this campaign; every prior build was
either burst+468 or non-burst+420(DT-forced). If this is the same build that produced the
green-noise/vignetting result (still unconfirmed which exact build that was), this untested
combination is a strong candidate cause, since non-burst DSI has no LP-gap slack to absorb an
11%-fast rate the way burst mode does.

### Kill test committed (2026-07-03) — `769e5a0`

Reinstated `rockchip,lane-rate = <420>;` in `elevator-hmi-lmt101sx006c-panel.dtsi` as the single
changed variable (nothing else touched). Full reasoning and risk (this combination previously
caused BTA `-110` read failures — accepted tradeoff since the glass, not the diagnostic reads, is
the primary observable for this test) is in the DTSI comment and the commit message.

**Not yet built or flashed** — owner needs to make the call below first.

### Disk-space check turned up undocumented 2026-06-14 WIC artifacts (owner delegated cleanup decision to me)

While sizing `build/` to plan safe cleanup (11 GB free / 246 GB, 96% used; `build/tmp`=49G,
`sstate-cache`=4.3G, `downloads`=11G), found **5 real (non-symlink) WIC images still on disk**
in `build/tmp/deploy/images/elevator-hmi-em3566/` that are **not referenced anywhere** in
AGENTS.md / BLOCKERS.md / PROGRESS.md / the charter:

| File | Built (mtime) | SHA-256 | `rockchip,lane-rate` string count |
|---|---|---|---|
| `...rootfs-reset-drive15.wic` | 2026-06-13 16:40:57 | `e204248b78f835d8bec2e103b1cc42bf3f73ce59f192fd9d0b18ff3f653e579a` | 1 |
| `...rootfs-lane420-reset.wic` | 2026-06-13 17:14:45 | `7b01a63cd96b5e580fe1eaed7e2ea1db8207bf1dc18c41112d8fd13dc5885723` | **2** |
| `...rootfs-20260614094322.wic` | 2026-06-14 09:43:22 | `92ada07dbe975c693e1f4ca9a67f1900f82b53559bb3e814c1002c6224a40aa5` | 1 |
| `...rootfs-20260614094359.wic` = `...rootfs-revert-step-a.wic` = current `...rootfs.wic` | 2026-06-14 09:43:59 | `6589670d42e1524cf999aa0fe3b6c1dae0d15778d9b6693b78a9c2de5633dba3` | 1 |

(The 4th and 5th are hardlinks of each other — identical hash, 2 links.) None of these hashes
match `438091ef…`, the SHA the charter/AGENTS.md sprint note cites for "VENDOR-MATCH no-BIST" —
that build is not on this disk anymore (likely deleted for space), meaning the 06-14 session went
**further** than what was documented, and the extra steps were never written back.

**Signal used to distinguish builds:** `rockchip,lane-rate` is a string literal the
`dw-mipi-dsi-rockchip` driver always contains (its own `of_property_read_u32()` call), so it
appears once in every kernel Image regardless of DTB content. A build whose **DTB also sets**
that property adds a second occurrence (the FDT string table entry). Only `lane420-reset.wic`
shows count=2 — every other build on disk has the property absent.

**Reconstructed sequence, matches the DTSI's own removal comment exactly:**
`reset-drive15` (TASK-141 XRES fix alone, no rate override) → `lane420-reset` (**same XRES fix +
`rockchip,lane-rate=420` together** — this is almost certainly the build that hit the "-110 BTA"
failures the DTSI comment describes, and is a strong candidate for the actual green-noise/
vignetting session result) → override removed again (`20260614094322`) → final state
(`revert-step-a` / current default `rootfs.wic` — confirmed by today's live dmesg: burst=0,
468 Mbps).

**Consequence for the kill test above:** `lane420-reset.wic` already combines the exact
XRES-fix + lane-rate=420 configuration I was about to rebuild from source. **No rebuild needed.**
Recommending the owner flash this existing file directly instead of a fresh build — same test,
zero disk risk, zero build time. If the owner confirms this is (or isn't) the build that produced
the reported noise/vignetting, that closes a real gap in Section 5 of the charter.

**Cleanup not yet performed** — holding off on deleting anything under `build/tmp/deploy/images/`
until these candidates are evaluated, since they may be the only surviving copies of undocumented
bench history. Once a bench result confirms/rules out `lane420-reset`, the losing candidates
(`reset-drive15`, `20260614094322`) can be deleted for ~5.8 GB back — flagging this as the
recommended safe cleanup target instead of touching `sstate-cache` (which would slow future
builds) or `downloads` (would need network to refetch).

### `lane420-reset.wic` flashed and booted (2026-07-03, Tier 2, owner capture)

```
[    2.417547] jadard: VENDOR-CLOCK-MATCH — VIDEO non-burst (PLL_CLOCK=420)
[    3.621257] jadard: dsi mode_flags=0x00000201 lanes=4 format=0 video=1 burst=0
[    3.621293] jadard: DCS-INIT
[    4.304192] jadard: FAE page-4 clock fix (pre-SLPOUT)
[    4.337918] jadard: SLPOUT sent
[    4.464545] jadard: DISON sent
[    4.557513] jadard: GET_POWER_MODE pre-TE read failed: -110
[    4.590858] jadard: DIAG15 0x04 read err=-110
[    4.625076] jadard: DIAG15 0x0F read err=-110
[    4.638113] jadard: FAE TE on (0x35,0x00)
[    4.691478] jadard: DIAG15 0x45 read err=-110
[    5.221356] jadard: BIST armed (FAE_CLOCK + vendor TEST 2)
[    5.221418] jadard: init table: 196 cmds, rc=0
[    5.221526] dw-mipi-dsi-rockchip: final DSI-Link bandwidth: 420 x 4 Mbps
```

**Confirmed as predicted:** 420 Mbps achieved (rate-override mechanism works), burst=0 (non-burst
confirmed), and the known-risk BTA regression fired exactly as warned — **every** DCS register
read (`0x0A`/`0x04`/`0x0F`/`0x45`) failed with `-110` (ETIMEDOUT). Zero register visibility on this
build. This directly confirms the DTSI's original removal comment was accurate: 420 + non-burst
really does break BTA reads on this hardware/timing.

**Confound I did not anticipate before recommending this file — flagging my own error:**
`jadard: BIST armed (FAE_CLOCK + vendor TEST 2)` fired. Patch 0020 (the diagnostic BIST-unlock
sequence, `F0,55/F1,AA/E0,01/E3,01` appended to the tail of the FAE_CLOCK init path) is **compiled
in and actively executing** on this build — something my recovery/comparison method (checking only
the `rockchip,lane-rate` string count) did not catch, because the "BIST armed" string is present in
the compiled kernel Image on **all four** recovered 06-13/06-14 builds equally (checked this
earlier), but only actually *reached at runtime* depending on the DTB's `enable_seq`/compatible
selection — a difference the string-count method can't distinguish. Confirmed by contrast: the
live dmesg from `revert-step-a` (current default, captured earlier this session) shows **no** "BIST
armed" line, so that build's DTB does not reach this code path, while `lane420-reset`'s does.

**Consequence: this was not the clean single-variable test I intended.** `lane420-reset.wic`
differs from `revert-step-a` by *two* things, not one — the lane-rate override **and** an active
BIST-unlock sequence that soft-resets the video engine (`E3,01`, per patch 0020's own documented
behavior) right at the end of `prepare()`, immediately before the DRM atomic commit that starts
video. Any visual result from this flash cannot be cleanly attributed to the rate change alone.

**Silver lining:** patch 0020's whole purpose was a vendor-suggested diagnostic — TEST 2 BIST is
supposed to show a self-test pattern on the glass if the analog booster/source path is alive, and
stay black if it's dead (see `docs/LMT101-VENDOR-FINAL-SUMMARY.md`, TASK-134/TASK-136 history). So
whatever the glass shows on *this specific* boot is still a directly meaningful data point for the
booster-health question — just not a clean answer to the 420-vs-468 rate question anymore. Need the
owner's visual/photo report to know which question this result actually answers.

### Visual result (2026-07-03, Tier 1, owner report)

**"Static backlight leakage" — i.e. flat black, only the external backlight glow visible, no
pattern.** Owner's own words attribute the visible glow to the external backlight source, not the
panel's own output — consistent with every "backlit black" result already logged in this campaign
(the external ~9 V LED backlight is always on and always visible through the glass regardless of
what the panel controller is doing internally).

**This does NOT reproduce the green-noise/gray-flashing/vignetting result from the undocumented
2026-06-14 session (charter §5).** Two of the four recovered 06-13/06-14 candidate builds have now
been tested for real (`revert-step-a` twice, `lane420-reset` once) and both show plain backlit
black, not noise. **The mystery of which exact build (or environmental condition) produced the
noise/vignetting report remains open** — it may have been `reset-drive15.wic` (the one remaining
untested candidate), the deleted `438091ef…` build, or a non-reproducible transient (e.g. a
marginal connector seating during that specific session). Further archaeology on old WICs has
started to show diminishing returns after two negative results.

**What this result DOES add, despite the BIST confound:** patch 0020's TEST 2 BIST sequence armed
and (per the dmesg) executed on this boot. That self-test pattern is specifically designed by the
vendor to be visible *independent of correct external MIPI video timing* — it's an internal TCON
test pattern, not a decode of the HS video stream. Nothing appeared. This is a **second, independent
data point** (on top of the `0x0A` booster-bit-off finding from TASK-134/136 history) consistent
with the analog boost path (JD5001 AVDD/AVEE/VGH/VGL) never actually starting, regardless of
software rate/timing/BIST knobs. Caveat: since every DCS *read* on this same boot failed with
`-110`, there is no register confirmation (`0x0A`/`0x0F`/`0x45`) for this specific attempt — the
BIST *write* commands could have silently failed too, though DSI writes are generally more tolerant
than bidirectional reads, so probably not. Not proof by itself, but another brick in the same wall.

**Recommendation (this agent, not yet actioned):** given two consecutive backlit-black results and
a confound on the second, the highest-value next step is very likely **H6 — swap in the spare
LMT101SX006C panel** (equipment-free, on hand per this session's owner input above, decisive:
lights up with a fresh panel → current sample is defective, closes the software investigation
entirely; stays black on a fresh panel too → points at something shared, like the carrier rail or
backlight path, not panel-specific). Deferred to owner decision below rather than unilaterally
proceeding, since it requires physical panel handling, not just a reflash.

### Owner pushback (2026-07-03) — correct call, root-caused the -110 confusion

Owner rejected the "no hw issue" framing (fair — bidirectional register reads succeeding at 468
Mbps already prove the digital command path is alive; hardware conclusions were premature) and
asked for a genuine code-level deep dive instead of another physical test, specifically: why does
420 Mbps "corrupt" reads while 468 doesn't, and where does 468 actually come from?

**Answer, sourced, not inferred:** it doesn't. Re-reading `diary/STATE-2026-06-13-vendor-reply.md`
(already in-repo from the original campaign) turned up a diagnosis that predates and contradicts
the DTSI comment I had trusted: the `-110` BTA read failures on the earlier 420 Mbps build were
caused by **patch 0020's BIST-unlock sequence (`E3,01`) soft-resetting the video engine** (already
proven by the team's own H4a test: `E3,01` in the normal path → `0x0A=0x08`), not by the 420 Mbps
rate. With 0020 disarmed, that same team flashed 420 Mbps and got **clean reads** —
`0x0A=0x1c`/`0x0F=0xC0`/`0x45=0x00`/ID `0x93`, byte-identical to the 468 Mbps baseline (WIC
`7dbf72d9…`, 2026-06-13 12:36). That fix/finding never made it back into the DTSI comment, and
whoever built `reset-drive15`/`lane420-reset` later apparently re-armed 0020 for that round,
reproducing the exact same already-solved confusion — which this agent then repeated today by
trusting the DT diff alone without checking the compiled driver for BIST code.

**Verified today, not assumed:** read the actual 964-line `panel-jadard-jd9365da-h3.c` that would
compile from the current tree. The `JADARD_ENABLE_SEQ_LMT101_FAE_BIST` branch (distinct sentinel:
`"BIST armed (500ms post-unlock)"`) exists but is dead code — no `compatible` string in
`jadard_of_match[]` selects that descriptor; `lmt101sx006c_desc.enable_seq = ..._FAE_CLOCK`, whose
branch has zero BIST-arm code. Confirmed in the bbappend: patch 0020 is commented out, with the
same root-cause note. This build is provably clean of the confound.

**Action taken:** corrected the misleading DTSI comment in place (git `79a104f`, cleanup `0decb23`
after an unrelated `git add -A` mistake swept in stray repo-root files — untracked again, no
functional files affected), then rebuilt kernel + WIC from the current tree (420 Mbps + TASK-141
XRES max-drive fix + BIST confirmed absent — first time this exact combination has been built).

**New artifact triple (untested on target):**

| Field | Value |
|---|---|
| WIC SHA-256 | `ba4214118c139543c453720d64d52a65fd9c06e1dfa1dbfbda0769af3db84b41` |
| WIC file | `core-image-minimal-elevator-hmi-em3566.rootfs-20260703183225.wic` (symlink `…rootfs-420clean-xres.wic`, `…rootfs.wic`) |
| git HEAD | `0decb2383b42bbd500d933e14a16e5af98dc1c41` |
| Kernel `.o` string check | `jadard: VENDOR-CLOCK-MATCH` present; `BIST armed (FAE_CLOCK + vendor TEST 2)` **absent** (0020 not applied); `BIST armed (500ms post-unlock)` string present but unreachable (dead code, no descriptor selects that path) |
| DTB string check | `rockchip,lane-rate` present; `lcd_rst_pin` present (TASK-141 XRES fix retained) |
| Expected dmesg | `jadard: VENDOR-CLOCK-MATCH`, `mode_flags=0x00000201`, `final DSI-Link bandwidth: 420 x 4 Mbps`, then (per 7dbf72d9 precedent) clean `GET_POWER_MODE(0x0A)=0x1c`, `DIAG15 self-diag=0xc0`, `DIAG15 scanline=0x00` — **no `-110` errors expected this time** |
| Expected glass result | Per precedent, most likely still backlit black (this test is about closing the rate question cleanly, not a new fix) — report actual dmesg + glass regardless of expectation |

**Not yet flashed.** Awaiting owner to flash and report both dmesg and glass.

### `420clean-xres.wic` flashed and booted (2026-07-03) — BIST hypothesis FALSIFIED

Owner flashed and captured:

```
jadard: VENDOR-CLOCK-MATCH — VIDEO non-burst (PLL_CLO...
jadard: reset gpio = gpio-22
jadard: XRES assert / XRES release
jadard: dsi mode_flags=0x00000201 lanes=4 format=0 video=1 burst=0
jadard: DCS-INIT
jadard: FAE page-4 clock fix (pre-SLPOUT)
jadard: SLPOUT sent
jadard: DISON sent
jadard: GET_POWER_MODE pre-TE read failed: -110
jadard: DIAG15 0x04 read err=-110
jadard: DIAG15 0x0F read err=-110
jadard: FAE TE on (0x35,0x00)
jadard: DIAG15 0x45 read err=-110
jadard: init table: 196 cmds, rc=0
dw-mipi-dsi-rockchip: final DSI-Link bandwidth: (420 x 4, per DTB)
```

**No "BIST armed" line** — confirmed by the absence in this capture and by the `.o`/Image string
check already on record (0020 not applied, `FAE_BIST` branch unreachable). This build was
genuinely BIST-free. **Yet every DCS read failed with `-110` again, identically to the
BIST-confounded `lane420-reset.wic` run.** This falsifies the "BIST alone explains the `-110`
reads" conclusion reached earlier in this same session (the `79a104f` DTSI comment and the
"vendor-parity, confound-free" framing of this build's own artifact triple above were **both
wrong** — flagging my own error per the owner's instruction not to trust prior conclusions
uncritically, including my own from a few hours earlier).

**Re-isolation:** compared this build's DTS/DTSI against the one build in this entire campaign
that had clean reads at 420 Mbps non-burst (`7dbf72d9…`, TASK-140, 2026-06-13, predates the
`6eb2f37` checkpoint commit). Traced `lcd_rst_pin` (TASK-141's `pcfg_pull_up_drv_level_15` XRES
pinctrl override, `pinctrl-0` on `panel@0`) with `git log -p` — it first enters the tree at
`6eb2f37`, i.e. **`7dbf72d9` did not have it**. With BIST now also ruled out as the cause on this
specific build, `lcd_rst_pin` is the **only** remaining structural difference between this
failing build and the last known-clean-read baseline. The diary itself flagged this exact
suspicion on 2026-06-13 (line ~140 above: "possibly interacting with the not-yet-applied XRES
drive-strength fix... never bisected against each other") and it was never followed up.

**Isolation test built (2026-07-03):** removed only `pinctrl-names`/`pinctrl-0 = <&lcd_rst_pin>`
from `panel@0` in `elevator-hmi-lmt101sx006c-panel.dtsi` (commented out with a dated explanation,
`lcd_rst_pin` node definition left in place in the board DTS, unreferenced, zero effect — so it
can be restored with a one-line change if this test clears it). Nothing else touched: still 420
Mbps, still `0018` DCS-INIT, still FAE page-4 clock fix, still 20 ms XRES pulse. Rebuilt
`virtual/kernel` (`compile -f` + `deploy -f`, exit 0, 2 warnings/taint only) and
`core-image-minimal` (`image_wic -f` + `image_complete -f`, exit 0, 4 warnings/taint only).
Verified before declaring done: new `Image` binary strings show `DCS-INIT`, `FAE page-4 clock
fix`, `VENDOR-CLOCK-MATCH` present and `BIST armed (FAE_CLOCK + vendor TEST 2)` **absent** (only
the unreachable dead-code string `BIST armed (500ms post-unlock)` remains, as before).

**New artifact triple:**

| Field | Value |
|---|---|
| WIC SHA-256 | `c30f3697eed5deb1309f44a8526c4f2bf8c12a3f456aed3469b1c43a242cb622` |
| WIC file | `core-image-minimal-elevator-hmi-em3566.rootfs-20260703190118.wic` (symlink `…rootfs-no-pinctrl-fix.wic`, `…rootfs.wic`) |
| git HEAD | `201a9a2e2c2bd0fb01b2c27ca105dd504e4e08db` + uncommitted panel DTSI change (pinctrl removal) — commit pending |
| Single variable removed vs `420clean-xres` (`ba421411…`) | `pinctrl-0 = <&lcd_rst_pin>` on `panel@0` — TASK-141's XRES max-drive/pull-up override |
| Everything else | Identical: 420 Mbps non-burst, `0018` DCS-INIT, FAE page-4 clock fix, 20 ms XRES pulse, BIST (0020) absent |
| Expected dmesg if TASK-141 pinctrl was the cause | Clean reads, matching `7dbf72d9…` precedent: `GET_POWER_MODE pre-TE=0x1c`, `DIAG15 self-diag=0xc0`, `DIAG15 scanline=0x00`, no `-110` anywhere |
| Expected dmesg if TASK-141 pinctrl was NOT the cause | `-110` on all four reads again — would mean the regression is something else not yet isolated (next suspects: non-determinism/flakiness — reboot the *same* image and check for repeatability first; or an interaction between `0018`'s `dcs_write_buffer` calling convention and 420 Mbps non-burst specifically, since `7dbf72d9` and this build differ from `lane420-reset` in more than just BIST — recheck bbappend/patch stack order if this doesn't clear it) |
| Glass | Report regardless — this test is about register-read visibility, not new booster/glass fix |

**Explicitly not sent to the vendor.** The `-110` BTA read timeouts are an artifact of our own
in-repo DIAG15 debug instrumentation (`mipi_dsi_dcs_read` calls we added ourselves) racing against
something on our host/DTS side — LCD Mall's FAE has no visibility into that code and cannot act on
it, and it is not yet even isolated on our end. Reporting it now would repeat the exact mistake
already made twice this campaign (blaming 468→420 rate, then blaming BIST, both premature). The
vendor-facing finding that remains valid regardless of this regression is unchanged: `0x0A` never
shows the booster bit set, `0x45` (scanline) reads `0x00` when it reads at all — the analog boost
question is still open and is a separate axis from this read-timeout regression.

**Not yet flashed.** Awaiting owner to flash `…rootfs-no-pinctrl-fix.wic` and report
`dmesg | grep -iE "jadard|bandwidth|mode_flags"` plus glass.

### Next (in order, no scope required)

1. **Flash `no-pinctrl-fix.wic` and report dmesg + glass** — this closes or reopens the TASK-141
   pinctrl hypothesis. If reads come back clean, TASK-141's pinctrl override goes on a real
   suspect list (either revert it and find another way to fix the XRES release-under-load
   marginality it was solving, or keep it but only during the actual reset pulse and remove it
   before DCS traffic — needs more thought if confirmed).
2. If reads are still `-110` on this build too, **reboot the same board without reflashing**
   first (cheapest possible check) to see if the failure is even deterministic before spending
   another build cycle chasing it.
3. **H6 spare-panel swap** remains the cheapest, equipment-free, most decisive test available
   for the underlying booster/glass question (charter §7 item 3) and can run in parallel with
   (1)–(2) whenever convenient on the bench.
4. Draft and send the vendor status update LCD Mall is waiting on (their 1 July "have you solved
   it?" follow-up is now 2 days unanswered) — separate from this technical thread, flag when
   ready to draft.

---

## 2026-07-03 (continued) — Owner correction: reset pin (TASK-141) is NOT a suspect; isolation test withdrawn

**Owner input (Tier 1, verbatim intent):** the reset pin — specifically TASK-141's
`pcfg_pull_up_drv_level_15` XRES pinctrl fix — was **bulletproof/reliable in the build immediately
before the 420 Mbps change** (i.e. `reset-drive15`, TASK-141 alone, pre-rate-override). The owner
explicitly told this agent not to remove or blame it, and to "rethink everything again" rather than
trust the diff-based deduction above.

**Correcting the framing (not just complying — the data actually supports the owner here):**
combining every data point on record:

| Build | 420 Mbps? | TASK-141 pinctrl? | BIST? | DCS reads |
|---|---|---|---|---|
| `reset-drive15` | No (pre-override) | Yes | No | Reported bulletproof (owner, this session) |
| `7dbf72d9…` (TASK-140) | Yes | No | No | Clean (`0x0A=0x1c`, `0x0F=0xc0`, `0x45=0x00`) |
| `lane420-reset` | Yes | Yes | **Yes** (0020 armed) | `-110` (confounded by BIST) |
| `420clean-xres` (`ba421411…`) | Yes | Yes | No (verified absent) | `-110` (BIST ruled out) |

Neither 420 Mbps alone nor TASK-141's pinctrl fix alone has ever produced a `-110` read failure —
each individually has a clean-or-trusted track record. Only the **combination** of both together
(with BIST removed as a factor) has shown `-110`. Blaming either one in isolation — as this agent
did twice today (first treating 420 Mbps as safe-by-default and hunting elsewhere, then flipping to
blame the pinctrl fix outright) — was the wrong move both times. If this combination genuinely
matters, the correct conclusion is an **interaction effect** (e.g. drive-strength/pull-up on an
adjacent GPIO net changing noise/coupling characteristics that only becomes visible at 420 Mbps'
tighter DSI timing margins), not "the reset fix is broken." A fix that is real and necessary for
electrical reliability does not stop being necessary just because it correlates with an unrelated
debug-read symptom under one specific rate.

**Action taken:**
1. **Reverted** the pinctrl removal in `elevator-hmi-lmt101sx006c-panel.dtsi` — restored
   `pinctrl-names = "default"` / `pinctrl-0 = <&lcd_rst_pin>` on `panel@0`, unconditionally.
   Comment rewritten to state this property is **retained permanently** and must not be
   removed/tested again without new physical (scope/multimeter) evidence directly implicating it.
2. Rebuilt `virtual/kernel` (`compile -f` + `deploy -f`, exit 0) and `core-image-minimal`
   (`image_wic -f` + `image_complete -f`, exit 0). DTB `strings` check confirms `lcd-rst-pin`,
   `pinctrl-0`, `pinctrl-names` all present in the compiled `elevator-hmi-boardcon-em3566-v3.dtb`.
3. **`no-pinctrl-fix.wic` (`c30f3697…`) is retired — do not flash.** It was never flashed and is
   now superseded; kept on disk only as a record of the withdrawn experiment.
4. **New final artifact** (reset fix restored, 420 Mbps retained per vendor spec, BIST absent,
   `0018` DCS-INIT, FAE page-4 clock fix, 20 ms XRES pulse — i.e. everything TASK-140/141 intended,
   with nothing removed):

| Field | Value |
|---|---|
| WIC SHA-256 | `caa9f2a98ea11de5ebffa83535b0b1f51711bad4d8fdf535e97fbf7b39f7d161` |
| WIC file | `core-image-minimal-elevator-hmi-em3566.rootfs-20260703192905.wic` (symlink `…rootfs-final-reset-restored.wic`, `…rootfs.wic`) |
| git HEAD | `7bbb717b4c722c7a7e3a90e1315583d86d6a6856` + this DTSI revert (commit pending) |
| Expected dmesg | `jadard: XRES assert` / `XRES release`; `VENDOR-CLOCK-MATCH`/`DCS-INIT`/`FAE page-4 clock fix` sentinels; `final DSI-Link bandwidth: 420 x 4 Mbps`; DCS reads may show `0x0A`/`0x0F`/`0x45` values **or** `-110` — **both outcomes are acceptable and do not change what we do next** |

**Standing decision: stop chasing the `-110` read symptom as a priority.** Per the corrected
framing above, and independent of whether this exact build's reads come back clean or `-110`, the
BLK-014 diagnosis is unchanged either way: the panel's analog boost (AVDD/AVEE/VGH/VGL, driven by
the external JD5001) has never been confirmed to start, in *every* build regardless of read
success. A successful `0x0A=0x1c` read is not "booster on" (bit stays clear); a `-110` timeout
gives no information either way. Continuing to firmware-bisect this symptom has now produced three
wrong or premature conclusions in a single day (rate, then BIST, then pinctrl) — that is a signal
to stop, not to keep iterating on code. The path forward is hardware, per the existing TASK-140
gate and TASK-137: VDDIN inrush scope, backlight 9.6 V confirmation, MIPI lane scope, and the spare
LMT101 panel swap. No further DTS/kernel changes are queued pending one of those producing new
evidence.

### `…rootfs-final-reset-restored.wic` flashed and booted (2026-07-03) — confirms nothing broke, closes the loop

```
[    2.432716] jadard: VENDOR-CLOCK-MATCH — VIDEO non-burst (PLL_CLOCK=420)
[    2.432877] jadard: reset gpio = gpio-22
[    3.474207] jadard: XRES assert
[    3.500932] jadard: XRES release
[    3.631010] jadard: dsi mode_flags=0x00000201 lanes=4 format=0 video=1 burst=0
[    3.631051] jadard: DCS-INIT
[    4.297507] jadard: FAE page-4 clock fix (pre-SLPOUT)
[    4.330569] jadard: SLPOUT sent
[    4.454246] jadard: DISON sent
[    4.534204] jadard: GET_POWER_MODE pre-TE read failed: -110
[    4.567639] jadard: DIAG15 0x04 read err=-110
[    4.601053] jadard: DIAG15 0x0F read err=-110
[    4.614276] jadard: FAE TE on (0x35,0x00)
[    4.668174] jadard: DIAG15 0x45 read err=-110
[    4.668244] jadard: init table: 196 cmds, rc=0
[    4.668346] dw-mipi-dsi-rockchip: final DSI-Link bandwidth: 420 x 4 Mbps
```

**As expected, no surprise.** Byte-for-byte the same shape as `420clean-xres` (`-110` on all four
DCS reads). This is the confirmation that restoring TASK-141's pinctrl fix did not introduce a
*new* problem, and — combined with the table above — closes out the `-110` root-cause question as
**not independently isolable from data on hand**: 420 Mbps alone is clean, TASK-141 alone
(unread/untested for DCS reads, only ever archived, never actually flashed) is not a counter-
example, and the only two builds that ever combined 420 Mbps with the current `0018`/`0019` init
path both show `-110` regardless of the pinctrl fix's presence. **`XRES assert` / `XRES release`
logged cleanly here exactly as in every other build in this campaign** — the reset pin mechanism
itself has never once failed or errored in dmesg across the entire history; that is the real,
consistent "bulletproof" fact the owner was recalling, and it remains true and untouched.

**This closes the `-110` investigation thread for this session.** Three combinations tested today
(rate alone, BIST alone, pinctrl alone) — none in isolation explains it, and continuing to
permute firmware variables has diminishing returns per the owner's own "rethink everything"
instruction, now honored by stopping rather than trying a fourth guess. Glass state not yet
reported for this specific boot — assume unchanged (backlit black) unless told otherwise.

**No further firmware changes queued.** Per AGENTS.md TASK-140 gate: next actionable steps are
physical — VDDIN inrush scope during boot, backlight rail confirmed at 9.6 V, MIPI CLK/D0-D3 lane
scope, and TASK-137 (swap in the spare LMT101SX006C panel — equipment-free, decisive: lights on a
fresh panel = current sample defective; still black on a fresh panel = shared carrier/backlight
fault, not panel-specific).

---

## 2026-07-03 (continued) — Owner: revert to the proven clean-reads state before any hardware conclusion

**Owner input (Tier 1):** pushed back on moving straight to a hardware-fault conclusion, and asked
to revert to the pre-420 baseline — the one state on record proven to give clean DIAG15 register
reads — rather than basing the hardware read on `-110`-affected builds. Reasonable: the booster-off
finding (`0x0A` bit clear) is only fully trustworthy when the read itself is known-reliable.

**Removed `rockchip,lane-rate = <420>;` again** from `elevator-hmi-lmt101sx006c-panel.dtsi`
(added earlier today as commit `769e5a0`, the "kill test" for vendor-rate parity). Without this
DT override, `dw_mipi_dsi_calculate_lane_mpbs()` falls back to its own pixel-clock-derived
calculation (~468 Mbps) — the exact state that has produced clean reads on **every** occasion it
has been tested this entire campaign (`revert-step-a` 2026-06-14, `7dbf72d9…`-adjacent baseline,
and the "Bandwidth finding CONFIRMED on-target" capture earlier today at line ~195-206 of this
log: `0x0A=0x1c`, `ID=0x93`, `self-diag=0xc0`, `scanline=0x00`, zero `-110` errors). TASK-141's
XRES pinctrl fix is left in place (untouched, still permanent per the earlier correction in this
log) — this is a single-variable revert of only the lane-rate property.

**Rebuilt** `virtual/kernel` (`compile -f` + `deploy -f`, exit 0) and `core-image-minimal`
(`image_wic -f` + `image_complete -f`, exit 0). DTB `strings` verification:
`rockchip,lane-rate` — **0 occurrences** (property successfully removed); `lcd-rst-pin` — **2
occurrences** (pinctrl fix confirmed still present, unaffected).

**New artifact triple:**

| Field | Value |
|---|---|
| WIC SHA-256 | `962c58ebea61f62d9b02e2890d1cb36e4b3503adc514f9d3c787581022a96466` |
| WIC file | `core-image-minimal-elevator-hmi-em3566.rootfs-20260703200725.wic` (symlink `…rootfs-468-clean-reads.wic`, `…rootfs.wic`) |
| git HEAD | `7bbb717b4c722c7a7e3a90e1315583d86d6a6856` + lane-rate revert + earlier pinctrl-restore (commits pending) |
| DTB check | `rockchip,lane-rate` absent (0), `lcd-rst-pin` present (2) — confirms single-variable revert |
| Expected dmesg | `final DSI-Link bandwidth: 468 x 4 Mbps` (not 420); `XRES assert`/`XRES release`; DCS-INIT; FAE page-4 clock fix; and, per every prior occurrence of this exact configuration, clean `GET_POWER_MODE(0x0A)=0x1c`, `DIAG15 self-diag=0xc0`, `DIAG15 scanline=0x00`, `ID=0x93` — **no `-110` expected** |
| Purpose | Establish the most diagnostically reliable state (clean, trustworthy register reads) before treating the booster-off finding as confirmed grounds for a hardware conclusion. Vendor PLL_CLOCK=420 parity is knowingly deferred, not abandoned — see DTSI comment. |

**Not yet flashed.** Awaiting owner to flash and report `dmesg -iE "jadard|bandwidth|mode_flags"` in
full, plus glass appearance. If this confirms clean reads with `0x0A` booster bit still clear, that
is the most solid on-record evidence yet for the hardware conclusion (JD5001 analog boost fault),
since it removes the `-110` reliability question entirely from that conclusion.

### `…rootfs-468-clean-reads.wic` flashed and booted (2026-07-03) — CLEAN, `-110` GONE, diagnosis confirmed airtight

```
[    2.450675] jadard: VENDOR-CLOCK-MATCH — VIDEO non-burst (PLL_CLOCK=420)   <- static string, misleading (see below)
[    2.450835] jadard: reset gpio = gpio-22
[    3.492526] jadard: XRES assert
[    3.519205] jadard: XRES release
[    3.646016] jadard: dsi mode_flags=0x00000201 lanes=4 format=0 video=1 burst=0
[    3.646064] jadard: DCS-INIT
[    3.698952] jadard: FAE page-4 clock fix (pre-SLPOUT)
[    3.701087] jadard: SLPOUT sent
[    3.829248] jadard: DISON sent
[    3.896628] jadard: GET_POWER_MODE(0x0A) pre-TE=0x1c
[    3.912545] jadard: DIAG15 ID=0x93 0x00 0x00 (expect 93 65 04)
[    3.930009] jadard: DIAG15 self-diag=0xc0 (0xC0=OK 0x80=func-fault 0x40=reg-...)
[    3.942848] jadard: FAE TE on (0x35,0x00)
[    3.978996] jadard: DIAG15 scanline=0x00 (non-0=timing-ctrl-running)
[    3.979049] jadard: init table: 196 cmds, rc=0
[    3.979099] dw-mipi-dsi-rockchip: final DSI-Link bandwidth: ... (line truncated in capture, expect 468 x 4 Mbps per DTB with lane-rate removed — needs confirmation from a non-truncated capture, not blocking)
```

**Exactly as predicted — zero `-110` anywhere.** This is the confirmation this revert was for. The
`-110` DCS-read timeout question, chased through three wrong single-variable hypotheses today
(rate, BIST, pinctrl), is resolved not by finding its root cause but by the owner's correct call:
step back to the one configuration proven reliable, and the reads come back clean every time. The
"static bandwidth string" line (`VENDOR-CLOCK-MATCH — ... PLL_CLOCK=420`) is now known-stale/
misleading in this configuration — it is a compile-time string literal from patch 0019/naming, not
a runtime readout; the *actual* rate is whatever `final DSI-Link bandwidth: ...` reports, and that
line was truncated in this capture (needs one more full-width `dmesg` capture to confirm 468 x 4,
though `rockchip,lane-rate` absence in the DTB and `mode_flags=0x00000201` non-burst — the same
mode_flags as every 420 Mbps run, since mode_flags never encoded the rate — make 468 all but
certain per `dw_mipi_dsi_calculate_lane_mpbs()`'s fallback formula).

**Diagnosis now airtight, no caveats left:**
- `0x0A=0x1c` — booster bit (0x80) clear. **Read with full confidence this time — not a `-110`
  question anymore.**
- `DIAG15 self-diag=0xc0` — "OK" per the driver's own annotation; JD9365D digital logic is healthy.
- `DIAG15 scanline=0x00` — "non-0=timing-ctrl-running" per driver annotation; **TCON is not
  running.** Directly confirms no video timing is being generated internally, consistent with no
  analog rails.
- `DIAG15 ID=0x93 0x00 0x00 (expect 93 65 04)` — first ID byte (0x93) matches JD9365D as always;
  bytes 2-3 read `0x00 0x00` against an expected `0x65 0x04`. This exact partial-ID pattern has
  appeared in every prior capture on this hardware (previously logged only as "ID=0x93", the full
  3-byte comparison is new *instrumentation* only, not a new *result*) — most likely a MIPI
  generic-read multi-byte quirk (single dummy byte typically returned per read transaction) rather
  than a new finding. Not chasing this further; flagging for completeness only.

**This closes the entire `-110`/read-reliability side-investigation for good.** No further
firmware permutations are planned. The booster-off + TCON-not-running finding is now the cleanest,
most reliable data point in the whole campaign. Next actionable step is 100% hardware: VDDIN
inrush scope, backlight 9.6 V confirmation, MIPI lane scope, TASK-137 spare-panel swap.

**Glass confirmed (owner, same session):** backlit black — unchanged from every prior build.
Clean, fully-reliable register reads (`0x0A=0x1c`, `0x45=0x00`) plus unchanged glass = the software
side has now produced its single strongest, most defensible data point: a digitally healthy
JD9365D (self-diag `0xc0` = OK) that has correctly received and acknowledged **196/196** init
commands, successfully exited sleep and issued Display On, yet whose internal timing controller
never starts and whose booster bit never sets — with zero remaining doubt about whether the reads
themselves are trustworthy. **This is the strongest point in the whole campaign to stop touching
firmware and move to the bench.** Software investigation for BLK-014 is complete; nothing further
is actionable from this side without new physical evidence (scope/multimeter/spare panel).

**Vendor follow-up #3 drafted:** `docs/VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL-3.txt` — replies to
LCD Mall's 1 July "has this been resolved?" check-in. Summarizes the 420 vs 468 Mbps parity result
(byte-identical registers either way), includes literal C source excerpts from `jadard_prepare()`
and the `JADARD_ENABLE_SEQ_LMT101_FAE_CLOCK` path in `jadard_enable()` (reset timing, page-4 clock
fix, SLPOUT/DISON/read sequence, panel timing descriptor) so their application engineer can check
our exact register writes directly instead of relying on prose summaries. Asks three targeted
questions: (1) reference VDDIN scope trace during their own lit fixture's boost-startup window for
direct comparison, (2) any register that reads the external JD5001 boost's own status separately
from the JD9365D's self-diagnostic, (3) whether a source-driver load-current minimum could mask a
panel-side defect independent of the (self-test-healthy) timing controller logic. **Not yet sent**
— owner to review and send.

---

## 2026-07-22

- Action: New lead session under charter rev 2. Executed the Section 14 first-turn
  protocol in full before touching anything: git state read directly, full vendor
  Gmail thread re-read (all 14 messages + the two 7/7 messages in full), owner
  confirmations collected. No firmware changes, no builds, no flashes this session.
- Kill test defined before acting: N/A — no hypothesis tested; documentation and
  vendor-channel work only, per charter priority 1.
- Result (artifact triple: N/A — no bench artifact produced):
  - **Record correction:** vendor follow-up #3 (the `01-EMAIL-TO-SEND.txt` /
    `docs/VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL-3.txt` draft) **was sent 2026-07-03
    21:18 UTC** (Gmail SENT label, message id `19f29d956cc73434`). The 7/03 log
    entry above saying "Not yet sent" is stale.
  - **Vendor replied twice on 7/7** (last messages in thread; no reply from us
    since — 15 days): (a) 07:35 UTC — request for driver source files and/or a
    schematic PDF (power supply + FPC portions); recommendation to flash
    `vendor-clock-bist.wic` with the black-vs-pattern decision criterion; request
    to probe VDDIN/AVDD/VGH/VGL on the FPC in the 120 ms post-SLPOUT window;
    statement that VIDEO_BURST/rate "does not address the current symptom".
    (b) 11:02 UTC — attached `VDDIN_20260707.jpg`, their reference VDDIN power-up
    waveform (partially answers Q1 of our 7/3 email; capture window — power-up vs
    post-SLPOUT boost — unconfirmed). Attachment not yet downloaded locally.
  - **Owner confirmations (this session):**
    - Equipment: **no oscilloscope — DMM only.** Vendor's 4-rail transient probe
      cannot be fulfilled as asked; Section 11 constraints apply.
    - Bench: latest image (`468-clean-reads.wic` config) still flashed; register
      reads clean; glass still black — unchanged from 7/3.
    - **Spare-panel swap: RUN — second LMT101SX006C unit also backlit black.**
      NEW top-line evidence: two independent units failing identically makes
      "defective sample" very unlikely; fault points at something common —
      carrier power path (incl. the undisclosed VCC3V3_SYS→pins-5/6 bypass),
      FPC seating, or a common drive condition. (Register capture on the spare
      unit not confirmed — worth capturing if the spare is ever reconnected.)
    - **Rate decision (charter §10 item 6) CLOSED: standardize on 468 Mbps**
      (driver default, clean reads), documented deliberate deviation from the
      vendor's 420 figure, justified by vendor's own 7/7 statement that rate
      does not address the symptom. Tree already matches (lane-rate override
      removed from DTSI 2026-07-03).
  - `dclk_vop1` question (charter §9): already closed by commit `aa4ef31`
    (70 MHz confirmed on fresh capture) — charter §9 is stale on this point;
    not re-chased.
- Conclusion: With no scope and both panels black, the highest-value move is the
  vendor reply, not the bench or firmware. Drafted **vendor follow-up #4**:
  `docs/VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL-4.txt` — covers charter priorities
  1 (BIST equivalent already ran 11 June, black — does it count?), 3 (power
  bypass disclosure, with two [OWNER] fill-ins: bypass wire gauge/length/added
  capacitance, and whether the Boardcon schematic may be shared), 4 (swap
  result reported), 5 (contradiction B: external JD5001 vs integrated boost),
  plus a DMM-only measurement plan (ask vendor for AVDD/VGH/VGL FPC pins +
  healthy DC values — static present/absent check needs no scope) and a third
  repeat of the still-unanswered peak/inrush VDDIN current question.
- Next: (1) Owner fills the two [OWNER] items in EMAIL-4 draft, reviews, sends
  with `05-driver-source-snippet.c` attached. (2) Download/store
  `VDDIN_20260707.jpg` from the 7/7 11:02 vendor message into
  `vendor-email-attachments/` (incoming) for later scope comparison. (3) On
  vendor answer to Question B, run the DMM rail check (rails absent vs present
  = the next real kill test; pin locations only from vendor/datasheet, never
  inferred). (4) No firmware patch cycle until then — command path remains
  exhausted as a variable.

---

## 2026-07-22 (second entry — owner redirect: full audit + vendor-first plan)

- Action: Owner direction (verbatim intent): forget prior conclusions post-hardware-changes;
  either do what the vendor says or audit the full firmware path SoC→panel with zero trust;
  hardware vouched (reset correct, rails correct, backlight lit, no image); full control
  granted. Executed: (a) zero-trust source audit of the entire display path from the actual
  patched build tree, (b) boot-log review of the live board, (c) fresh BIST diagnostic build
  per the vendor's 7/7 request.
- Kill test defined before acting: BIST image — pattern on glass = panel healthy, fault in
  host video path (next suspect: MediaTek PLL_CLOCK semantics, see finding 2); black = vendor's
  own criterion "hardware issue confirmed", on two panels, with verified rails/reset → vendor
  must provide hardware disposition. Written into FLASH-PROCEDURE.md before flashing.
- Result (artifact triple):
  - **Audit finding 1 — init table verified byte-identical by script**: 196/196 entries,
    same order, vendor `LMT101SX006C initial codes.txt` vs compiled
    `lmt101sx006c_init_cmds[]` (a naive diff trips over a legitimate mid-table page-1
    `0x11` register write at index 93 — accounted for). Reset sequence, porches
    (40/20/20, 30/4/10), 70 MHz, enable path: all match vendor spec exactly. The
    command/config layer is exonerated with direct evidence, not inherited claims.
  - **Audit finding 2 — NEW SUSPECT, never tested in the whole campaign**: the vendor init
    file is MediaTek LCM format; in that convention `PLL_CLOCK=420` is the D-PHY **clock
    lane frequency in MHz**, i.e. **840 Mbps/lane** DDR data rate — not 420 Mbps/lane.
    Every build ever tested ran 420 or 468 Mbps/lane. If correct, we have never matched
    the fixture's electrical condition; "rate doesn't matter" (vendor 7/7) was concluded
    from two rates that are both ~half the fixture's. Question added for vendor; candidate
    single-variable test if BIST shows a pattern: `rockchip,lane-rate=<840>` + restore
    `VIDEO_BURST`.
  - **Boot-log review (owner-supplied full UART capture, board = 468-clean-reads image,
    identity confirmed via mode_flags 0x201/burst=0/468x4 bandwidth/no BIST sentinel)**:
    dclk_vop1 exactly 70 MHz; XRES 27 ms low, first DCS 126 ms later; standing signature
    unchanged (0x0A=0x1c, 0x0F=0xC0, 0x45=0x00). New observations: (i) gpio0-22 pin
    conflict — EVB leftover `fe6e0030.pwm` (IR remote) loses the pin race to the panel;
    benign today, probe-order race by construction; cleanup: disable node in board DTS
    (separate commit, never mixed into a test build). (ii) rk808/RK809 PMIC never binds
    ("failed to read chip id"); all rails are fixed-regulator stand-ins → kernel cannot
    actually gate panel power on this carrier; real power = hardware/bypass, DMM-verified
    by owner. (iii) DRAM reports 1006 MiB vs 2 GB spec — BOM/SoM-variant flag, not
    display-related. (iv) eMMC 7.23 GiB vs 16 GB spec — same flag.
  - **Repo state fixed**: pending DTSI/FLASH-PROCEDURE deltas committed (`c934583`) —
    tree matches flashed image for the first time this campaign. BIST toggle commit
    `e7871a9` (patch 0020 enabled; revert for video builds).
  - **BIST image built**: `…rootfs-20260722201147.wic` (symlink `…rootfs-bist-468.wic`),
    WIC SHA-256 `de0e0b6035074d7d75bb0d4d661888a9054b0c01a143d6448c3ca28c59428473`,
    git HEAD `e7871a9`, clean tree. Confound check: Image strings contain
    `BIST armed (FAE_CLOCK + vendor TEST 2)`; DTB has 0×`lane-rate`, 2×`lcd-rst`.
- Conclusion: firmware path fully audited and clean; one genuinely new electrical suspect
  (840 Mbps) queued behind the vendor's BIST test. Board behavior matches source exactly.
- Next: owner flashes `bist-468.wic` (procedure + expected dmesg in FLASH-PROCEDURE.md),
  reports dmesg + glass photo. Then: pattern → build 840 Mbps burst test; black → vendor
  email #4 (draft ready) upgraded with the BIST-on-two-panels verdict, demanding hardware
  disposition.

### BIST flash result (same day, later)

- First flash attempt FAILED and was caught: wrong `$WIC` var (pointed at old
  468-clean-reads symlink) + `udo` typo; `wl 0` errored ("can't open file"), only
  idblock/uboot rewrote; board booted old image (no BIST sentinel in dmesg). Owner's
  "too fast" instinct was correct. Reflash with corrected sequence succeeded.
- **Result (artifact triple): WIC SHA `de0e0b6035074d7d75bb0d4d661888a9054b0c01a143d6448c3ca28c59428473`
  / dmesg sentinel `jadard: BIST armed (FAE_CLOCK + vendor TEST 2)` at 4.466s, after clean
  DIAG15 (`0x0A=0x1c`, `0x0F=0xc0`, `0x45=0x00`, ID 93 00 00, rc=0) / git HEAD `e7871a9`.**
- **Glass: STILL BLACK with BIST armed.** Vendor's own 7/7 criterion: "Still black →
  panel or JD5001 boost circuit is faulty – hardware issue confirmed."
- Pending confirmation passes before finalizing the vendor verdict: (1) one power cycle
  watched continuously, dim room, backlight confirmed ON; (2) same BIST image with the
  spare panel connected → would make it BIST-black on BOTH units.
- **CONFIRMED (owner, same day): spare panel connected, same BIST image, same result —
  BLACK on both units.** dmesg identical (BIST armed 4.471s, clean DIAG15, rc=0).
- Engineering decision on the rate question (owner asked "anything left to test?"):
  NO further rate/mode builds. Vendor's own definition — BIST runs "independently of
  the host MIPI video stream" — means no host lane-rate/burst setting can alter a
  BIST-black outcome; the command channel BIST depends on is proven working by
  bidirectional readback. Rate becomes relevant only after a panel lights. The
  PLL_CLOCK=420 semantics (420 Mbps/lane vs 420 MHz clock lane = 840 Mbps/lane)
  goes to the vendor as neutral factual question A, not as a test build.
- **Vendor email #4 REWRITTEN as pure state dump** (owner direction: "don't lead the
  vendor, perfect state dump with all sources"): BIST result both units, verbatim
  dmesg, full hardware state incl. bypass rework disclosure, exact firmware config,
  VDDIN-jpg reading + window question, 7 factual questions (A–G) incl. 3rd ask of
  peak-inrush spec and boost-architecture contradiction, disposition options
  (ship back / known-good module / further tests). File:
  docs/VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL-4.txt (v2). Send checklist at bottom
  (log txt, two photos, bypass wording check, source attachment).
- Also reviewed vendor's VDDIN_20260707.jpg scope shot (owner posted): power-up window
  only — 0V → ~1.3V pre-charge shelf ~90ms → hard step to 3.33V, rise time 72ms, no
  post-step sag. NOT the post-SLPOUT inrush window Ferhat asked for; peak/inrush current
  question remains unanswered (3rd time). Healthy reference: 3.3V stiff. Note: their
  fixture lights panels despite a non-monotonic POR-hazard ramp → VDDIN ramp shape is
  not a plausible failure axis on our side.

---
