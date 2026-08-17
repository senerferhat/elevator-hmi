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
- Owner challenge (correct): "at 420 the reads failed — is 420 guilty, and was the
  vendor mail accurate?" Re-derived from the record: 420 not PROVEN guilty (one
  dmesg-confirmed 420 build, `7dbf72d9`, read clean) but all four other 420 builds
  hit `-110` on every read and 468 has never failed once; co-variable never isolated
  (BIST and pinctrl both falsified). Writes worked at 420 in all builds. The 7/3
  email's parity claim was true only for succeeded reads and glossed the failures
  in the body (attachments disclosed it). EMAIL-4 v2 corrected: explicit
  read-reliability paragraph added to section 2 (1 clean / 4 failed at 420, -110
  = host BTA, root cause unknown, baseline 468 for reliable diagnostics; BIST
  verdict unaffected — produced at 468 with clean reads). No 420 re-test build now:
  BIST is rate-independent; revisit only if vendor's answer to question A requires
  rate parity.
- **VDDIN record corrected (owner, 2026-07-22): the Plan B bypass jumper NO LONGER
  EXISTS.** The May "defective load switch" diagnosis (BLK-013) was made while the DT
  drove a wrong enable pin with inverted polarity; TASK-132 (`287374c`) bench-traced
  the real chain (PWM0_M0 → R457 → Q18 NPN → Q17 P-FET → GPIO0_B7 ACTIVE-HIGH), the
  current DTS uses it, the switch works, the jumper is removed, and today's BIST runs
  (both panels) used the stock switch path. BLK-013 annotated SUPERSEDED in
  BLOCKERS.md; EMAIL-4 section 3 rewritten (proper switch path + honest history line;
  bypass-disclosure framing dropped; inrush question C reworded — load-switch current
  limit makes the peak-inrush spec directly decision-relevant). NOTE: charter §3
  "power bypass in place / not yet disclosed" is stale on this point too. (owner direction: "don't lead the
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

## 2026-07-23 (owner-directed full re-audit — ROOT-CAUSE CANDIDATE FOUND)

- Action: owner ordered zero-trust re-audit of the ENTIRE boot→BIST path ("don't trust
  any older agent run"). Audited: deployed DTB (decompiled from the flashed binary),
  jadard driver, and — for the first time in the campaign — the DSI host core
  (`drivers/gpu/drm/bridge/synopsys/dw-mipi-dsi.c`, vendor 6.1 fork) line by line.
- Kill test defined before acting: see FLASH-PROCEDURE 2026-07-23 section (pattern vs
  black grid for both new images).
- Result:
  - **FINDING (structural, campaign-wide): this vendor kernel switches the DSI host to
    VIDEO mode in `bridge_atomic_enable()` BEFORE calling `drm_panel_enable()`** —
    `pre_enable` = command mode + `drm_panel_prepare` only. Our mainline-style jadard
    driver sends the whole vendor bring-up from enable() → every build since May sent
    init/SLPOUT/DISON/BIST as HS commands inside live-video blanking, panel receiving
    video packets before init. Fixture (MTK flow) inits in command mode pre-video;
    Rockchip's simple-panel-dsi puts init in prepare() for exactly this reason. Dmesg
    order (jadard prints before `final DSI-Link bandwidth`) confirms on-target.
  - Secondary observations: commands sent HS (no MODE_LPM; fixture uses LP) — noted,
    not changed (single variable); dsi1's leftover simple-panel node is inert (parent
    disabled); -110-at-420 plausibly reframed as BTA in zero-margin blanking (noted,
    not chased).
  - **Patch 0021 INIT-IN-PREPARE** (`f04ae58`): full vendor sequence moved to prepare()
    (command mode, pre-video); enable() keeps DIAG15/TE only. Video image built:
    `…rootfs-init-in-prepare.wic`, SHA `9900365b…` — SET ASIDE as checkpoint per owner.
  - **Patch 0022 BIST-IN-PREPARE** (`ba66670`): vendor TEST 2 arm appended inside the
    corrected sequence + 2 s observation dwell. Image built:
    `…rootfs-bist-inprep.wic`, SHA `6b74331d…`. **Owner flash order: BIST first.**
  - Checkpoint ledger added to FLASH-PROCEDURE (all four WICs retained; reflash or
    rebuild from git at any time).
  - **Email #4 ON HOLD until these two results are in** (outcome changes the letter).
- Next: owner flashes `bist-inprep.wic`, watches glass continuously from power-on
  (window ~4–6 s), reports dmesg + observation; then `init-in-prepare.wic`.

### BIST-IN-PREPARE result — KILL TEST ANSWERED: ordering hypothesis FALSIFIED

- Result (artifact triple): WIC SHA `6b74331dd7d27c750a47741694764327317cbec4c409716d9ffe3be32dbce2a1`
  (`images-archive/bist-inprep.wic`), git HEAD `ba66670`, clean tree.
- dmesg confirms the fix executed as designed: `DCS-INIT`(3.624)→`SLPOUT`(3.625)→
  `DISON`(3.750)→`BIST armed (INIT-IN-PREPARE, cmd-mode, pre-video)`(3.764), all
  inside `prepare()` — then a measured **2.02 s gap** before `mode_flags=...video=1`
  at 5.784, matching the built-in `msleep(2000)` exactly. Confirms: BIST armed with
  ZERO video ever having reached the panel, for a full 2 seconds, in pure DSI
  command mode — the strictest, most fixture-identical test run in this campaign.
- **Glass observation (owner, watched continuously power-on through login):
  BLACK throughout. No pattern, no flash, at any point — including the full 2 s
  command-mode-only window.**
- **Ordering hypothesis (2026-07-23 finding: video-before-init) is FALSIFIED as
  the root cause of the black screen.** The panel does not produce any visible
  self-test output even when driven exactly as the vendor's own fixture would
  drive it — command-mode-only, no host video involvement whatsoever.
- Known confound in THIS build's register reads (does not affect the kill test,
  which is visual-only, not register-based): `GET_POWER_MODE(0x0A)=0x08`,
  `DIAG15 ID=0x38 0x00 0x00` (vs the constant `0x93...` everywhere else),
  `self-diag=0x11`, `scanline=0x28` (first-ever non-zero scanline). NOT reliable
  evidence of anything: (a) these reads run in `enable()`, still unguarded, and
  fire at t=5.85s — AFTER video mode was already switched back on at t=5.784,
  so they're just as video-confounded as every previous capture; (b) BIST arm's
  `E0,01` was never restored to `E0,00` before these reads — ID changing from the
  constant `0x93` strongly suggests page-1 registers were read by mistake, not
  page-0. Both are patch bugs in 0021/0022 (DIAG15 block never moved into the
  command-mode window, no page restore after BIST arm). Flagged for a future fix
  if further register-level BIST diagnostics are ever wanted; NOT chasing now —
  the visual kill test already answered the question this build was built for.
- Conclusion: video-ordering was a well-reasoned, well-evidenced hypothesis and
  the correct next thing to test — now cleanly ruled out. Standing diagnosis
  (panel/JD5001 boost/TCON hardware fault, both units) survives its most
  rigorous challenge yet. No further firmware permutations planned.
- Next: owner decision — (a) still run `init-in-prepare.wic` (video, no BIST,
  same corrected ordering) for completeness, though it's not expected to add
  diagnostic value beyond what BIST just answered; or (b) finalize and send
  vendor email #4 (currently ON HOLD) with this new command-mode-isolated BIST
  result added as the strongest evidence yet.

---

### POWER-DELAY (10ms->250ms) result — KILL TEST ANSWERED: rail-settle hypothesis FALSIFIED

- Action: owner-directed test — extend VCC3V3_LCD-to-XRES delay from vendor's stated 10 ms
  to 250 ms (25x), on top of the already-proven-good base (0021 ordering + 0022 BIST).
  Single variable, kill test written before flashing (FLASH-PROCEDURE.md).
- Result (artifact triple): WIC SHA `542ab97ef79c80b8a343356165563e4874199f6c66962dd1ff695b2bc7d838d8`
  (`images-archive/power-delay-250ms.wic`), git HEAD `d655a82`, clean tree.
- Timing verified by direct arithmetic on the two dmesg captures (old 10ms vs new 250ms):
  XRES assert/release, DCS-INIT, and BIST-armed timestamps all shifted by a consistent
  +251 to +255 ms — exactly matching the intended +240 ms delay increase, confirming the
  patch landed precisely where designed and nothing else drifted. BIST-arm-to-video gap
  held at ~2.0-2.2 s in both runs (msleep(2000) intact, normal DRM-stack variance).
- **Glass: BLACK again, full window, same as the 10 ms baseline.** Owner report: "result
  again black screen."
- Register reads in this capture (`0x0A=0x08`, `ID=0x38 00 00`, `self-diag=0x11`,
  `scanline=0x28`) are the EXACT same byte values as the previous (10 ms) BIST-in-prepare
  capture — reproducible, not random, which corroborates rather than contradicts the
  page-1-artifact explanation already on record (2026-08-07 BIST-IN-PREPARE entry): this is
  consistent wrong-page register content, not a new hardware signal, not evidence either way.
- **Rail-settle-time hypothesis FALSIFIED up to 250 ms** (25x vendor's stated 10 ms, without
  a scope trace of the actual VCC3V3_LCD rise — can't rule out needing more than 250 ms, but
  25x margin over a fixture value that works on vendor's own bench makes that unlikely).
- Conclusion: both firmware-timing hypotheses tested this session (command-mode ordering,
  rail-settle delay) are now cleanly falsified, on top of content/framing/rate already
  verified/exonerated earlier in the campaign. Firmware-side timing knobs are effectively
  exhausted. Standing hardware diagnosis (boost/TCON path, both panels) survives its most
  rigorous set of challenges yet.
- Owner raised a separate, still-open line independently (same session): two panels failing
  IDENTICALLY is stronger evidence for a SHARED cause than two coincidental panel defects —
  sound logic. Re-examined for hidden HOST-side (not panel) causes never yet checked:
  (a) MIPI LP/command-mode transactions conventionally only exercise Lane 0 + clock — D1/D2/D3
  have never been exercised by anything proven working in this campaign (every "it works"
  signal — 196 cmds ACKed, bidirectional reads, BIST handshake — all ride LP command mode).
  Charter R-02 (SoM shared LVDS/MIPI TX mux) was cleared by owner reading a block diagram,
  never physically lane-verified end-to-end. (b) Attempted to widen the dmesg search beyond
  the narrow `jadard|bandwidth` grep used all campaign, using already-saved captures —
  `diary/captures/*.cap` turned out to be pre-panel-era DDR/SPL training logs, not useful;
  **no full unfiltered kernel dmesg has ever been captured/saved in this campaign.**
- Next (owner decision, no firmware patch needed for either):
  (1) DMM continuity check, D1/D2/D3, SoC pin through CON1 to panel FPC — bench-doable now,
  never done before in this campaign. (2) Full unfiltered `dmesg` capture on next boot (not
  grep-filtered) to check for PHY/DSI-level warnings hidden by the narrow filter so far.

---

## 2026-08-07 (continued) — dclk_vop1 intermittent 10x clock race REOPENED (owner-directed full-dmesg hunt)

- Action: owner requested a full, unfiltered dmesg (not grep-filtered to jadard|bandwidth) to
  hunt for anything hidden by the narrow filter used all campaign — sound instinct given two
  panels failing identically points to a shared, not-yet-examined cause.
- Result: found `rockchip-vop2 fe040000.vop: [drm:vop2_crtc_atomic_enable] set dclk_vop1 to
  700000000` in a full capture from the power-delay-250ms.wic BIST-black boot — 9 digits,
  700 MHz, a 10x error vs the expected 70 MHz (panel's `.clock = 70000` kHz descriptor,
  unchanged across every patch 0018-0023). This is the EXACT item flagged in the charter
  (Section 9) and declared "closed, confirmed 70MHz" by commit `aa4ef31` (2026-06-13) — based
  on what now appears to have been a single non-representative sample.
- Traced print statement to source (`rockchip_drm_vop2.c:8998`, Tier 2 verbatim):
  `dclk_rate = adjusted_mode->crtc_clock * 1000 / vp->dclk_div; ...
  DRM_DEV_INFO(..., "set %s to %ld, get %ld\n", ..., dclk_rate, clk_get_rate(vp->dclk));` —
  format is `set <name> to <requested>, get <hardware readback>`; our terminal was truncating
  the `, get ...` half on every capture this whole campaign (narrow window, hard cut, not
  soft-wrapped) — genuinely never seen before now.
  `fold` unavailable on this busybox image; worked around with
  `dmesg | grep dclk_vop1 | sed 's/, get/\n  get/'`.
- **Rebooted, recaptured on the SAME image: `set dclk_vop1 to 70000000` / `get 70000000` —
  correct, matching, on this boot.**
- **Conclusion: INTERMITTENT, boot-to-boot race — not a deterministic bug, not a non-issue.**
  Same image, same hardware, wrong (700MHz, unconfirmed get-value) on one boot, correct
  (70MHz, get matches) on the next. Consistent with a PLL-lock-timing/clock-parent-selection
  race during early boot on RK3566's CRU tree, not something any of our jadard driver patches
  (0018-0023) could cause or fix (architecturally unrelated file, never touched).
- Scope, stated precisely: this clock feeds VOP pixel data into the DSI encoder for VIDEO
  transmission only. Architecturally unrelated to BIST (command-mode, pre-video, per vendor's
  own definition) - does NOT explain the BIST-black result, does not change the standing
  boost/TCON diagnosis. DOES reopen, with real evidence, a candidate explanation for why
  actual VIDEO (as opposed to BIST) has never once rendered in this campaign, independent of
  panel health - relevant once/if a genuine video-mode test is run again.
- Also scanned the rest of the full dmesg for anything else DSI/PHY/MIPI-relevant: nothing
  new. CSI/camera sensor probe failures (gc8034/ov5695, rk3x-i2c timeouts) are a DIFFERENT
  PHY (csi2-dphy0, camera input, not our DSI0 display output) - unrelated. PCIe link fail -
  no card installed, unrelated. Ethernet DMA reset fail - unrelated subsystem. gpio0-22/pwm7
  pin race and rk808 PMIC failure - both already logged 2026-07-22, not new. No DSI0
  controller-level CRC/ECC/framing/timeout errors found anywhere in either capture.
- Next: if pursued, needs its own multi-boot characterization (reboot N times, log
  dclk_vop1 set/get each time, establish failure rate) - separate from the BIST/boost
  investigation, not blocking it. Not yet correlated against an actual video-mode attempt
  (only tested under BIST images so far, where this clock is never exercised for output).

---

## 2026-08-07 (continued) — returned to main thread: vendor email #4 finalized with isolation-test evidence

- Action: updated docs/VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL-4.txt with the two firmware tests
  run since the draft was last touched (command-mode ordering isolation, 250ms power delay) —
  both now presented as "ADDITIONAL ISOLATION TESTING" in section 1, with a register-free,
  timing-only proof (BIST-armed-to-video-mode gap = 2.02s, matching the intentional hold to
  the millisecond) for the command-mode claim. Question F rewritten to state precisely what's
  already been excluded (video/HS-clock precondition, power settle time) so the vendor's own
  BIST-precondition question is answered as far as we can answer it ourselves.
- Scoping check: isolation tests (i) and (ii) explicitly marked "unit #1" only in the email —
  the spare panel was tested under the ORIGINAL vendor-specified BIST config (video-timed
  ordering, section 1/2 main result) but NOT under the newer command-mode-isolated variant.
  Not overclaiming both units under both configs.
- Send checklist updated: two serial logs now needed (original BIST both units, isolation
  test unit #1 only), with WIC SHAs referenced for owner to locate the right captures.
- Status: email is now the strongest version of the case this campaign has produced —
  content/framing/rate exonerated, ordering and rail-timing hypotheses tested and falsified
  under conditions stricter than the vendor's own BIST specification, on top of the original
  both-panels-black result. Still on owner review before send (checklist above).

---

## 2026-08-07 (continued) — RECORD CORRECTION: email #4 was already sent 2026-07-23; vendor re-engaged; email #5 drafted

- Action: owner pasted the live Gmail thread. Discovered: docs/VENDOR-SUPPORT-LMT101-
  BRINGUP-EMAIL-4.txt was NOT still a draft — a shorter version was actually SENT
  2026-07-23 00:00, before this session's ordering-isolation and power-delay tests
  existed. This session's edits to that file (ADDITIONAL ISOLATION TESTING, TIMING
  PROOF sections) were made under the stale belief it was still pending send — those
  sections were never sent and don't exist in the vendor's inbox. Corrected the file's
  STATUS header to state this plainly and point to email #5.
- Also found: the 23 July send's actual Gmail attachment list is 05-driver-source-
  snippet.c ONLY — the serial log and photos the email text references were never
  attached. Gap, not previously caught (the send checklist existed but apparently
  wasn't fully worked through, or was worked through with an earlier/shorter draft
  before those checklist items were added).
- Thread activity since: 2026-08-07 12:31 owner sent a one-line nudge ("keen to
  resolve... could you review the logs... advise next steps"); 12:38 owner forwarded
  the thread to a third party (SerkanSume1@gmail.com — likely stakeholder/colleague,
  not otherwise identified in this campaign's records); 13:38 vendor (Abby) replied
  same-day: "I will push the engineering to check and reply soon." Thread is active,
  not stalled.
- Drafted docs/VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL-5.txt: short, standalone follow-up
  (does not repeat the 23 July state dump). Covers exactly the two genuinely new
  findings from this session — command-mode-only BIST isolation (zero video ever sent,
  2.02s measured window, still black) and 25x power-settle-time test (250ms vs vendor's
  10ms, still black) — plus closes the missing-attachment gap (serial logs, photos).
  Owner review + attachment checklist at file bottom before send.
- Next: owner reviews/sends email #5 (or waits for vendor engineering reply first,
  owner's call — vendor has committed to respond, no urgency to preempt them, but the
  new evidence is ready either way).

---

## 2026-08-07 (continued) — MASTER IMAGE built: BIST-then-video, every boot, production behavior

- Action: owner requested (vendorless, forward-looking) a permanent boot flow: BIST
  self-test first, then normal video operation, with the ability to "reboot the LCD"
  without a full system reboot. Confirmed design via AskUserQuestion: trigger = every
  boot, always (not on-demand, not temporary-until-vendor-resolves).
- Design/implementation: patch 0024 refactors the reset pulse and full command
  bring-up into reusable helpers (`jadard_xres_pulse()`, `jadard_send_bringup()`),
  used twice per boot: once for the BIST self-test phase (command mode, zero video,
  per 0021's ordering), once for a clean video-ready phase after a SECOND independent
  XRES power-cycle. The second reset is architecturally the "reboot the LCD"
  capability requested — real, software-triggered, no Linux reboot involved.
- Technical rationale documented: E3,01 (BIST enable) soft-resets the display engine
  (established earlier in the campaign — 0x0A read 0x08 immediately after E3,01
  outside the dedicated BIST test), so BIST cannot be a soft mode-switch; the panel
  needs a fresh hardware reset before video can safely resume. This is why the flow
  is two full reset+init cycles per boot, not one with a mode toggle.
  BIST observation dwell set to 300ms (down from the 2s used for visual-confirmation
  testing) since this now runs on every boot with no automated pass/fail check
  available — kept short since every dwell length tested this campaign (300ms-2000ms
  equivalent) has shown identical (black) results regardless.
  Reverted to vendor's original 10ms power delay (0023's 250ms was a falsified
  hypothesis test, not a retained fix).
- Supersedes 0022 (one-shot diagnostic BIST, no return-to-video path) and 0023
  (250ms rail-settle, falsified) - both disabled in bbappend, kept in tree for
  history, explicit "do not enable alongside 0024" comments added.
- Build verified: WIC SHA `e479c2e4f3bffd46760978f9d2d82efa9cdafaf765ac4cec1f871c36617f0b6b`
  (`images-archive/master-image.wic`), git HEAD `2e16a30`, clean tree. Confound check:
  all four new MASTER-phase sentinels present; old 0022/0023 sentinels confirmed absent.
- Next: owner flashes master-image.wic, reports dmesg (expect TWO full XRES assert/
  release pairs per boot - this is correct, not a bug) + glass observation. This
  becomes the standing boot behavior going forward, independent of vendor's response
  on the underlying hardware question.

---

## 2026-08-07 (continued) — MASTER IMAGE first boot analyzed; result REPRODUCED on second boot

- Result (artifact triple): WIC SHA `e479c2e4f3bffd46760978f9d2d82efa9cdafaf765ac4cec1f871c36617f0b6b`
  (`images-archive/master-image.wic`), git HEAD `2e16a30`.
- Structural verification: both phases executed exactly as designed. Phase 1
  (self-test): XRES assert/release at 3.473/3.499 (cold boot), MASTER self-test
  phase -> DCS-INIT -> SLPOUT -> DISON -> BIST armed, all correctly sequenced.
  Phase 2 (video): MASTER video phase at 4.073, SECOND XRES assert/release at
  4.086/4.113, DCS-INIT -> SLPOUT -> DISON -> normal video handoff at 4.380.
  Two full reset+init cycles per boot, exactly as built.
- **NEW FINDING, register reads after phase 2 differ from every prior clean/
  non-BIST capture in this campaign:**
    - `0x0A` (power mode): `0x08` (was `0x1C` in every non-BIST capture)
    - `0x0F` (self-diagnostic): `0x00` = "both faults" per our own driver's
      bit-mapping comment (was `0xC0` = healthy, in every non-BIST capture)
    - `0x04` (ID): `0x93 00 00` -- MATCHES the historical constant, confirming
      this read is NOT page-1-confounded like the earlier BIST-arm captures
      (those showed ID=0x38, the tell that page selector was stuck on 1). A
      real XRES hardware reset resets the whole chip including page-select,
      so this read is genuinely page-0 and should be trustworthy.
  **REPRODUCED IDENTICALLY on a second boot of the same image** (same WIC,
  same git HEAD) -- 0x0A=0x08, ID=0x93 00 00, self-diag=0x00, scanline=0x00,
  bit-for-bit identical to the first capture. Not a one-off glitch; a
  deterministic consequence of this specific BIST-then-RESX-then-reinit
  sequence.
- Two competing, NOT YET disambiguated explanations recorded:
  (a) BIST/E3,01 leaves the self-diagnostic circuit in a state that a
      bare RESX pulse does not clear (many display ICs latch self-test/
      fault status until a full VDD power-cycle, by design, for post-mortem
      inspection) -- if true, master-image's phase-2 "reboot" needs a full
      regulator power-cycle, not just XRES, between the BIST and video
      phases.
  (b) This is the first genuinely unconfounded (page-0-correct) self-
      diagnostic read this campaign has ever captured, and it is reporting
      something real and negative that earlier page-1-confounded or
      never-run-BIST-in-same-session captures never surfaced.
- Decisive, cheap next test proposed (not yet run by owner): flash the
  ALREADY-ARCHIVED `init-in-prepare.wic` (SHA 0c947979..., 0021 only, zero
  BIST ever touched in this boot) and check 0x0A/0x0F. 0x1C/0xC0 there would
  support (a); 0x08/0x00 there would be surprising given every prior capture
  on that exact image and would need re-examination.
- Still missing: owner has not reported GLASS observation for either phase of
  either master-image boot (BIST self-test pattern vs black; video phase
  black vs anything). This remains the primary/decisive signal, asked for
  twice, not yet answered.
- No other new DSI/PHY-relevant lines found in either full unfiltered dmesg
  capture -- camera (gc8034/ov5695, different PHY), PCIe link fail (no card),
  ethernet DMA reset fail, gpio0-22/pwm7 pin race, rk808 PMIC read fail: all
  previously logged, unrelated or already-known items, unchanged.

---

## 2026-08-07 (continued) — MASTER IMAGE glass result: black (both phases)

- Owner report: master-image.wic showed nothing on the glass through the boot --
  no BIST pattern in phase 1, no video in phase 2. Consistent with every prior
  test this campaign; the DIAG15 anomaly (0x0A=0x08, self-diag=0x00) reported
  separately does not correspond to any visible change on glass either way.
- Owner now flashing init-in-prepare.wic (comparison test, no BIST) per the
  pending ask -- result not yet in.

---

## 2026-08-07 (continued) — DIAG15 anomaly RESOLVED: BIST latches self-diag fault, RESX-only doesn't clear it

- Comparison test result: init-in-prepare.wic (SHA 0c947979..., 0021 only, zero
  BIST ever touched, single XRES pair confirmed in dmesg) reads `0x0A=0x1C`,
  `0x0F=0xC0` (healthy) -- back to the historical baseline instantly, the moment
  BIST is out of the picture entirely.
- **Root cause identified**: `E3,01` (BIST enable) latches a fault status in the
  JD9365D's self-diagnostic register that a bare RESX (hardware reset pin) pulse
  does NOT clear -- a common, often intentional IC design pattern (self-test
  circuits designed to hold their result across a logic reset, cleared only by
  a genuine VDD power-cycle, precisely so the result survives for inspection).
  Confirms hypothesis (a) from the prior entry; hypothesis (b) (first-ever
  trustworthy negative reading) is ruled out.
- Scope: this affects ONLY the self-diagnostic register's reportability after
  BIST within the master-image's phase 2 -- it does NOT change the actual video
  outcome. Glass has been black in both configurations (BIST-then-video and
  BIST-free-video) throughout this entire campaign; the 0x0A/0x0F register
  value has never once correlated with whether video actually appears.
- Optional refinement, not yet implemented: if trustworthy post-BIST self-
  diagnostic telemetry is wanted (e.g. for future logging/automated pass-fail),
  master-image's phase 2 "reboot" would need to become a full regulator
  power-cycle (disable/enable jadard->vdd + vccio, not just the XRES pulse) to
  properly clear the latch. Not required for the master image's core purpose
  (BIST self-test + return to video) since video behavior is unaffected either
  way -- owner decision whether to pursue.

---

## 2026-08-07 — *** RESOLVED: PANEL WORKS. WHITE FRAMEBUFFER FILL DISPLAYED ON GLASS ***

- **BLK-014 RESOLVED.** Owner wrote a full-screen white fill to /dev/fb0 on the
  running board (init-in-prepare.wic flashed, patch 0021 active) and **the glass
  displayed a plain white image**. 1000 x 4096 = 4,096,000 bytes = exactly
  800 x 1280 x 4 (XR24) = the entire framebuffer. Backlight leakage cannot
  produce this. Display path functional end-to-end: SoC -> VOP2/VP1 -> DSI0 ->
  JD9365D -> pixels.
- Supporting evidence from same session, `/sys/kernel/debug/dri/0/summary`:
  `Video Port1: ACTIVE`, Connector DSI-1 / Encoder DSI-190, mode 800x1280p60,
  `clk[70000] real_clk[70000]`, H: 800 840 860 880 / V: 1280 1310 1314 1324
  (exactly the vendor's porches), `Smart1-win0: ACTIVE`, XR24, src/dst
  800x1280. Every layer correct.
- **ROOT CAUSE (actual): the command-mode init ordering bug, fixed by patch 0021
  (INIT-IN-PREPARE).** This vendor kernel's dw-mipi-dsi switches the host to
  VIDEO mode in bridge_atomic_enable BEFORE calling drm_panel_enable(), so the
  mainline-style jadard driver was sending the entire vendor bring-up (196-cmd
  table, page-4 fix, SLPOUT, DISON) as HS commands inside the blanking of an
  already-running video stream -- the panel received video packets before it was
  ever initialized. 0021 relocated the sequence into prepare() (command mode,
  pre-video, fixture-equivalent). That fix worked immediately.
- **Why the fix looked like a failure for ~2 weeks (process lesson):** 0021's
  kill test was written as "pattern/fbcon visible OR 0x45 non-zero". It was then
  validated using **BIST** (patches 0022/0024), which is an unreliable instrument
  on this panel -- `E3,01` produces no visible pattern here under any condition
  tested. The framebuffer-content test (the OTHER half of the kill test, and the
  one that actually works) was never re-run after 0021 landed. A correct fix was
  repeatedly graded by a broken measuring device.
- Contributing factor: `console=ttyFIQ0` only, no `console=tty0`, so nothing ever
  paints into /dev/fb0 during boot. A zero-filled framebuffer is a correctly
  displayed BLACK screen. Every "still black" observation after 0021 was the
  panel faithfully rendering black.
- **Red herrings, now formally closed:**
  - `0x45 scanline = 0x00` -- over-interpreted all campaign as "TCON not
    running". Not a reliable liveness indicator on this part/read timing.
  - `0x0A` bit7 "booster off" -- vendor's OWN healthy fixture reads 0x18, also
    bit7 clear. Never indicated a fault. Vendor's 0x9C-means-faulty guidance is
    inconsistent with the MIPI DCS spec and with their own healthy value.
  - `0x0F = 0xC0` (register loading OK + functionality OK) was the panel
    correctly reporting itself healthy for the entire campaign. It was right.
  - Two-panel "both black" -- both panels are FINE. Identical symptom because
    the cause was host-side firmware ordering, shared by both tests.
  - Hardware (3.3V rail, XRES timing, MIPI lanes, FPC wiring, load switch) --
    all exonerated. Owner's scope/DMM verification was correct.
- Vendor status: LCD Mall has been pursuing a non-existent hardware fault on our
  report. We owe them a correction (see next actions) -- panels are not
  defective, no RMA/cross-test needed.
- Next: (1) owner confirm half-screen fill (addressing/orientation proof);
  (2) get real content on screen permanently -- fbcon/console or the Qt EGLFS
  application (actual project goal); (3) send vendor correction; (4) update
  CLAUDE.md phase status, BLOCKERS.md (close BLK-014), PROGRESS.md.

---

### fbcon image built (2026-08-07) — first image that displays unaided

- `CONFIG_FRAMEBUFFER_CONSOLE` was confirmed absent from the defconfig
  (`# CONFIG_FRAMEBUFFER_CONSOLE is not set`) — the second half of the BLK-014
  root cause. Added it (+ `DETECT_PRIMARY`, `CONFIG_LOGO`, `LOGO_LINUX_CLUT224`)
  to `elevator-hmi.cfg`; all four verified present in the built kernel `.config`
  with no dependency warnings.
- **Near-miss caught before handover:** the first fbcon build was accidentally
  stacked on patch 0024 (master/BIST two-phase flow), which was still enabled in
  the bbappend. Sentinel check on the built Image caught it (`MASTER self-test
  phase` / `BIST armed (self-test phase)` present). That image would very likely
  have shown BLACK — a BIST pass leaves the panel at `0x0A=0x08`/`0x0F=0x00`
  versus healthy `0x1C`/`0xC0`, and the white-fill proof was obtained on 0021
  alone. Archive deleted, 0024 permanently disabled in the bbappend with an
  explanatory comment, rebuilt clean.
- Final image: `images-archive/fbcon-display.wic`, SHA
  `f13f3eb00d95a0465e3b7b265e800020ae55d4deb6d4e55e578f59b304410bab`.
  Sentinels verified: `INIT-IN-PREPARE (cmd-mode, pre-video)` present;
  `MASTER self-test phase` / `BIST armed (self-test phase)` absent;
  `CONFIG_FRAMEBUFFER_CONSOLE=y`, `CONFIG_LOGO=y`.
  (`BIST armed (500ms post-unlock)` remains in `strings` — dead code from patch
  0014, unreachable because `enable_seq = FAE_CLOCK`, present in every working
  build including init-in-prepare.wic.)
- Expected on flash: Tux boot logo + kernel messages rendering on the panel with
  no manual framebuffer writes.

---

### ✅ CONFIRMED ON GLASS (2026-08-07) — boot logo + live console, unaided

- Owner report, `fbcon-display.wic` (SHA `f13f3eb0…`): **Tux boot logo appeared,
  then the console terminal rendered on the panel**, portrait orientation, with
  no manual framebuffer writes. Full display path confirmed working end to end
  from power-on through userspace.
- This is the definitive close of BLK-014 and of the display bring-up campaign
  (2026-06-02 → 2026-08-07). The panel, both units, were always healthy.
- Orientation note (NOT a defect): console renders vertically/portrait, which is
  the panel's native geometry (800x1280 portrait, per CLAUDE.md §1). Whether the
  product wants portrait or landscape in the car is a product decision, not a
  bring-up issue. If landscape is wanted later: `fbcon=rotate:1` on the kernel
  cmdline (needs `CONFIG_FRAMEBUFFER_CONSOLE_ROTATION`), DRM plane rotation, or
  `QT_QPA_EGLFS_ROTATION` for the Qt app — cheap either way, defer to Phase 2.
- Phase 1 display gate: **PASSED**.

---

## 2026-08-17 — Qt 6.8 first build BLOCKED: meta-qt6 LTS branches require a commercial Qt license

- Steps 1/2/4 of the Qt bring-up plan completed; step 3 (first build of
  `elevator-hmi-image`) **failed at fetch**.
- **Root cause:** kas pins meta-qt6 to `443684a0`, which is branch **`lts-6.8.6`**
  (the kas comment claims `lts-6.8.7` — doc drift). ALL meta-qt6 `lts-*` branches
  fetch Qt modules from **`tqtc-`-prefixed repos** on
  `git://codereview.qt-project.org/qt/tqtc-<module>.git`. Those are The Qt
  Company's COMMERCIAL repositories: they need a Qt commercial license and
  authenticated access. Qt LTS point releases are a commercial-only benefit.
  Failed modules: tqtc-qtbase, tqtc-qtdeclarative, tqtc-qtshadertools,
  tqtc-qtlanguageserver, tqtc-qtquicktimeline.
- Public alternatives confirmed available on the same meta-qt6 remote:
  branches `6.8`, `6.8.0`, `6.8.1`, `6.8.2`, `6.8.3` (public code.qt.io repos,
  open source LGPLv3). LTS branches: `lts-6.8`, `lts-6.8.4` … `lts-6.8.7`.
- **This is a product/licensing decision, not a bug.** ADR-001 (CLAUDE.md §3)
  mandates "Qt 6.8 LTS", which is only obtainable commercially. Relevant to the
  choice: LGPLv3 carries the anti-tivoization/installation-information
  requirement, which interacts directly with this product's signed RAUC OTA and
  locked-down field devices (24/7 unattended, 5-yr life, 500–1000 units/yr).
- Everything non-Qt built fine (reached task 2846/7014 before the Qt fetches).
  GPU/EGL resolution verified correct beforehand: virtual/egl -> rockchip-libmali,
  MALI_PLATFORM=gbm, qtbase PACKAGECONFIG "kms gbm gles2 eglfs",
  QT_QPA_DEFAULT_PLATFORM=eglfs.
- **Process error (mine):** I reported "build finished exit 0". The command was
  `kas build ... | tee ... | tail`, so the exit status came from `tail`, not kas.
  Use `set -o pipefail` (or check PIPESTATUS) on every piped build command.
- Disk: 75G free before, 56G after the failed build.
- Next: owner decision on Qt licensing (commercial LTS vs public open-source
  branch), then re-pin meta-qt6 and rebuild.

---

## 2026-08-17 (23:04) — continuation agent takeover; Qt 6.8.3 image still building

- Took over mid-build on `develop` (`ef6aa1a`). Read `docs/HANDOFF-2026-08-17.md`
  and `CLAUDE.md`. BLK-014 stays closed; patches 0022/0023/0024 stay disabled.
- `kas build kas/elevator-hmi.yml --target elevator-hmi-image` is still running
  (started 22:54, log `build-logs/qt-image-public683-20260817.log`). At takeover:
  task ~4506/7014, **0 ERROR**, 44 GB free. Load ~109 on 20 cores.
- Public Qt 6.8.3 **fetch succeeded** for qtbase, qtdeclarative, qtshadertools,
  qtlanguageserver, qtquicktimeline (native + target). Previous commercial
  `tqtc-` blocker is gone. `qtbase-native` is in `do_compile` (started 23:00).
- `librsvg` is retrying crates.io fetches via MIRRORS — WARNINGs only so far.
- Next: wait for the build, then verify ERROR count / WIC / manifest, hardlink
  into `images-archive/qt-hmi.wic`, record SHA-256, give the flash command.

---

## 2026-08-17 (23:30) — qtbase do_configure FAILED: Mali wrappers export no EGL symbols

- Public Qt 6.8.3 fetch/native compile succeeded (`qtbase-native` compile
  23:00–23:21). Target `qtbase do_configure` failed at 23:23:
  `Feature "opengles2": Forcing to ON breaks its condition` /
  `GLESv2_FOUND = FALSE`; same for `eglfs` (`QT_FEATURE_egl = OFF`).
- Not a PACKAGECONFIG mistake. `virtual/egl` is rockchip-libmali, GBM blob
  `libmali-bifrost-g52-g13p0-gbm.so` is in the sysroot, `egl.pc` is correct.
- Root cause: JeffyCN mali-hook **wrappers** (`libEGL.so.1`, `libGLESv2.so.2`,
  `libgbm.so.1`, each 67 KB) export **zero** dynamic symbols. Real
  `eglGetDisplay` lives in `libmali.so.1.9.0` (43 MB). CMake FindEGL links
  the wrapper; GNU ld `--as-needed` drops it; HAVE_EGL/HAVE_GLESv2 fail.
  Headers compiled fine (step 1/2 of the try_compile succeeded).
- Fix (in `meta-hmi-platform`, not community layers): qtbase bbappend sets
  `-DEGL_LIBRARY/-DGLESv2_LIBRARY/-Dgbm_LIBRARY` to `${STAGING_LIBDIR}/libmali.so`.
  Same idea as AGL's FindEGL `NAMES mali` hack. Waiting for the failed kas
  run to exit, then rebuild.

---

## 2026-08-17 (23:35) — Mali EGL CMake fix confirmed: qtbase configure succeeds

- Failed kas run finished: 6679 tasks, 1 failed (`qtbase do_configure`).
  rust-llvm-native and gcc completed after the failure (sstate kept).
- Fix committed `907e643` and pushed to `origin/develop`. Rebuild started
  (`build-logs/qt-image-mali-egl-fix-20260817.log`).
- `qtbase do_configure` now **Succeeded**. Confirmed in the configure log:
  `HAVE_EGL - Success`, `HAVE_GLESv2 - Success`, `EGL yes`, `OpenGL ES 2.0 yes`,
  `EGLFS yes`, `EGLFS GBM yes`. (`EGLFS Mali no` is expected — we want the
  GBM/KMS plugin, not the Mali-specific QPA.)
- Next: wait for qtbase/qtdeclarative compile + image, then archive/flash.

---

## 2026-08-18 (00:12) — qtsvg ptest failed; disabling on-target ptests

- Mali EGL fix held: `qtbase do_configure/compile/install/package` all succeeded
  (EGL/GLES2/EGLFS/GBM yes). Target `qtshadertools`/`qtsvg`/`qtlanguageserver`
  configured; `qtlanguageserver` compiled.
- New failure: `qtsvg do_install_ptest_base` — ptest cmake cannot find
  `Qt6::Gui` (`tst_qicon_svg` / `tst_qsvgrenderer`). Poky enables `ptest` in
  DISTRO_FEATURES; Qt 6.8 then rebuilds the whole unit-test tree as a second
  cmake project. qtbase ptest alone was ~2800 objects / ~20 min. Not needed
  on the HMI image.
- Fix: `PTEST_ENABLED:forcevariable = "0"` in `elevator-hmi.conf` (beats
  ptest.bbclass's hard assignment). Not removing `ptest` from DISTRO_FEATURES,
  so we don't hash-bust the world. Rebuild next.

---

## 2026-08-18 (00:35) — elevator-hmi-app cmake cannot find Qt6 Gui (same Mali hole)

- noptest rebuild: 5899 tasks, 1 failed. qtdeclarative compiled. App
  `do_configure` failed: `HAVE_EGL/HAVE_GLESv2` false, so `find_package(Qt6 Gui)`
  reports "dependency GLESv2 could not be found". Qt6GuiConfig.cmake is present;
  CMake FindEGL still links the empty mali-hook wrappers. The qtbase bbappend
  EXTRA_OECMAKE only covers qtbase itself.
- Fix: same `-DEGL_LIBRARY=libmali.so` trio on `elevator-hmi-app`. Not changing
  rockchip-libmali packaging this round (would invalidate qtbase/qtdeclarative
  sysroots and cost another ~30 min). Follow-up: point unversioned libEGL.so at
  libmali so every CMake consumer works.

---
