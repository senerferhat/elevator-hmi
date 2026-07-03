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
