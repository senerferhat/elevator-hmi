# EM3566 v3 — Flash procedure (`rkdeveloptool`)

Exact lab steps for **Boardcon EM3566 v3** + `**core-image-minimal`** WIC and Rockchip loader artefacts. Project context: `[CLAUDE.md](../CLAUDE.md)`, full bring-up: `[BRINGUP-CHECKLIST.md](BRINGUP-CHECKLIST.md)`.

Run `**rkdeveloptool**` on the **host** (not inside a Docker/kas-only environment where `sudo`/USB may not work).

---

## ⚠️ READ THIS FIRST — how to find today's actual flash target

**Do not trust any hardcoded filename/SHA below without checking it first.** This doc drifted out
of sync with reality at least once already (2026-06-13 → 2026-07-03: the "canonical" build below
was deleted from disk, and its pass/fail dmesg expectations no longer matched the current board
state — see `diary/SESSION-LOG.md` 2026-07-03 entry for the full story). Named "canonical" sections
in this file are a **point-in-time snapshot**, not a live pointer — they will go stale again.

**Single source of truth going forward: `diary/SESSION-LOG.md`, newest entry, "current flash
target" / "kill test" line.** That file is append-only and dated — the newest entry always wins.
Steps:

1. Open `diary/SESSION-LOG.md`, read the **last** entry (bottom of file).
2. Find the filename + SHA-256 it names as the thing to flash/test next.
3. `sha256sum` that exact file before flashing — **if the hash doesn't match, stop and re-check the
   log; don't flash it anyway.**
4. Do **not** substitute `ls -t *.wic | head -1` for this lookup — the newest-*mtime* file on disk
   is frequently a diagnostic-only scratch build (BIST test, register-probe build, etc.), not
   necessarily the one actually recommended to test next. Mtime tells you build recency, not intent.
5. After flashing, capture `dmesg | grep -iE "jadard|bandwidth|mode_flags"` in full and compare
   against what the session-log entry says to *expect* — if the entry says "unknown / this is what
   we're testing," don't force-fit the result against an older doc's checklist (see problem this
   section fixes, above).

*(The superseded 2026-06-13 "VENDOR-MATCH (no-BIST)" canonical-image section that used to live here
is preserved in this file's git history — `git log -p -- docs/FLASH-PROCEDURE.md` — not repeated
below, to avoid a second stale pointer existing alongside the current one.)*

---

## CURRENT TEST TARGET (2026-08-22, later) — qt-hmi-vp0.wic — **BLK-015 candidate fix**

**Status: flash this and run the kill test.** Moves the DSI panel from Video
Port 1 to Video Port 0, matching Boardcon's own device tree. VP1 is where plane
commits never latch (BLK-015). Contains everything from `qt-hmi-cinema.wic`.

| Field | Value |
|---|---|
| **Archive file** | `~/Projects/elevator-hmi/images-archive/qt-hmi-vp0.wic` |
| **WIC SHA-256** | `b1df6fa5d5aedff54322aa0c8d0a4c468122d015ceb6da1956ddb5158fdfd16e` |
| **Deploy name** | `elevator-hmi-image-elevator-hmi-em3566.rootfs-20260822105549.wic` |
| **Change** | `dsi0 -> VP0`, `hdmi -> VP1` (was: EVB default, dsi0 on VP1) |
| **Evidence** | Boardcon DTB decompiled from `library/EM3566/Linux6.1/Image/update-buildroot-lvds.img`: VP0 = dsi0/dsi1/edp, VP1 = hdmi/lvds |

```bash
cd ~/Projects/elevator-hmi/images-archive
sha256sum qt-hmi-vp0.wic   # expect b1df6fa5d5aedff54322aa0c8d0a4c468122d015ceb6da1956ddb5158fdfd16e
sudo rkdeveloptool db loader.bin      # skip if the board is in Loader mode
sudo rkdeveloptool wl 0      qt-hmi-vp0.wic
sudo rkdeveloptool wl 64     idblock.img
sudo rkdeveloptool wl 0x4000 uboot.img
sudo rkdeveloptool rd
```

### KILL TEST — run this first, before anything else

```bash
modetest -M rockchip -c | grep -A3 -i "DSI\|connected"
```

Then, with the connector id and crtc id it prints:

```bash
modetest -M rockchip -s <CONNECTOR>@<CRTC>:800x1280
```

- **Test pattern on glass** -> BLK-015 is FIXED. KMS scanout works. Next: revert
  the HMI to EGLFS/Mali (see `elevator-hmi.init`), then wire VPU video.
- **Still nothing** -> the port was not the cause. Next diagnostic is the vendor
  image itself: flash `library/EM3566/Linux6.1/Image/update-buildroot-hdmi.img`
  with an HDMI monitor and run the same command under Boardcon's kernel.

Also confirm the panel still lights at all (`hmi` should start as before). If the
panel goes dark on VP0, revert this image and say so — that is information too.

---

## SUPERSEDED (2026-08-22) — qt-hmi-cinema.wic — media-first layouts

**Status: recommended for next flash.** Adds two video-first layouts on top of
the SD-slot fix and software MJPEG playback.

| Layout | What you get |
|---|---|
| `hmi simple` | floor number + animated arrows in a narrow strip, video fills the rest (portrait) |
| `hmi full` | fullscreen video, no HMI chrome (portrait, letterboxed) |
| `hmi landscape-simple` | as simple, rotated — video well ~1000x800 |
| **`hmi landscape-full`** | **fullscreen rotated — 1280x800 stage, best 16:9 picture** |

**Use `landscape-full` with a 1280x720 clip.** The rotated stage is 1280x800, so
a 1280x720 MJPEG maps **1:1 with no scaling at all** — sharpest possible, and the
cheapest to decode because there is no resample per frame.

Cinema layouts letterbox (fit) rather than crop: cropping a 16:9 clip into a
portrait well would throw away most of the frame. Bars are painted black.

| Field | Value |
|---|---|
| **Archive file** | `~/Projects/elevator-hmi/images-archive/qt-hmi-cinema.wic` |
| **WIC SHA-256** | `6e057d6636897b5640f2c85d23e5f08f9b9f66cdc8b4324a6f09c6b6bfd86fa0` |
| **Deploy name** | `elevator-hmi-image-elevator-hmi-em3566.rootfs-20260822102230.wic` |
| **Also contains** | SD slot DTS fix (vmmc off the dead RK809), MJPEG playback, ad slideshow, `hmi media` |

```bash
cd ~/Projects/elevator-hmi/images-archive
sha256sum qt-hmi-cinema.wic   # expect 6e057d6636897b5640f2c85d23e5f08f9b9f66cdc8b4324a6f09c6b6bfd86fa0
sudo rkdeveloptool db loader.bin      # skip if the board is in Loader mode
sudo rkdeveloptool wl 0      qt-hmi-cinema.wic
sudo rkdeveloptool wl 64     idblock.img
sudo rkdeveloptool wl 0x4000 uboot.img
sudo rkdeveloptool rd
```

### Max-quality clip

Encode at the SOURCE resolution — no downscale, no quality lost, and 1:1 on the
landscape stage:

```bash
gst-launch-1.0 -e filesrc location=IN.mp4 ! qtdemux name=d d.video_0 ! queue ! h264parse ! avdec_h264 ! videoconvert ! videorate ! video/x-raw,framerate=25/1 ! jpegenc quality=92 ! avimux ! filesink location=01-demo-hq.avi
```

1280x720 q92 lands around 1 GB for 5.5 minutes. MJPEG has no inter-frame
compression — that is the cost of having no H.264 decoder (libav is
`LICENSE_FLAGS = "commercial"`).

---

## SUPERSEDED (2026-08-19) — qt-hmi-sdvideo.wic — **SD slot fixed** + video

**Status: recommended for next flash.** Fixes the reason the SD slot was dead,
and carries the software video decode.

**The SD slot never worked on this board.** `rk3568-evb.dtsi` wires `sdmmc0`
(fe2b0000) `vmmc-supply` to the RK809 PMIC rail `vcc3v3_sd` (SWITCH_REG2), and
this board has **no functioning RK809 at 0x20**. The controller therefore sat in
`deferred probe pending` forever: no `/dev/mmcblk1`, `dmesg | grep sdmmc`
completely silent, pane stuck on `NO CARD` regardless of the card. Now pointed at
the board's fixed 3.3 V rail. `sd-uhs-sdr104` removed with it — UHS SDR104 needs
vqmmc switched to 1.8 V and `vccio_sd` is a fixed 3.3 V supply.

Note fe2b0000 is **sdmmc0 / the SD slot**; fe2c0000 is sdmmc1 / SDIO. An earlier
handoff had these the wrong way round.

| Field | Value |
|---|---|
| **Archive file** | `~/Projects/elevator-hmi/images-archive/qt-hmi-sdvideo.wic` |
| **WIC SHA-256** | `aa041ca8925f5ba760d3ba0008c65df101e23816e7280d4995be93a9250b8da3` |
| **Deploy name** | `elevator-hmi-image-elevator-hmi-em3566.rootfs-20260818220345.wic` |
| **Contains** | SD slot DTS fix, software MJPEG playback, ad slideshow, `hmi media` |
| **Kernel** | still **0021-only** for the panel; this touches only `&sdmmc0` |
| **Expected on glass** | insert FAT32 card → `/dev/mmcblk1`, mounts at `/media/sdcard`, `hmi portrait-video` plays the MJPEG clip looping |

```bash
cd ~/Projects/elevator-hmi/images-archive
sha256sum qt-hmi-sdvideo.wic   # expect aa041ca8925f5ba760d3ba0008c65df101e23816e7280d4995be93a9250b8da3
sudo rkdeveloptool db loader.bin      # skip if the board is in Loader mode
sudo rkdeveloptool wl 0      qt-hmi-sdvideo.wic
sudo rkdeveloptool wl 64     idblock.img
sudo rkdeveloptool wl 0x4000 uboot.img
sudo rkdeveloptool rd
```

Verify the slot first, before blaming the card or the clip:

```bash
ls /dev/mmcblk1*        # must exist now
hmi media               # mounted: yes, and the clip listed
```

---

## SUPERSEDED (2026-08-19) — qt-hmi-video.wic — SD **video plays**

**Status: recommended for next flash.** Video from the SD card now plays on the
panel, software-decoded. Stills still play as an ad slideshow.

**The clip MUST be MJPEG.** This image has `jpegdec` (plugins-good) but **no
H.264 decoder** — `gstreamer1.0-libav` is `LICENSE_FLAGS = "commercial"` and
installing it is a licensing decision for the product owner, not a build detail.
An H.264 file will be listed and then fail to decode; the pane says
`CANNOT DECODE` / `MJPEG ONLY — NO H.264 DECODER` rather than sitting blank.

| Field | Value |
|---|---|
| **Archive file** | `~/Projects/elevator-hmi/images-archive/qt-hmi-video.wic` |
| **WIC SHA-256** | `c74e86f65087a75a8f834c815fbac9c578064606634f2823e498436574e1aa37` |
| **Deploy name** | `elevator-hmi-image-elevator-hmi-em3566.rootfs-20260818213224.wic` |
| **What changed** | `VideoSurface` (QQuickPaintedItem) blits decoded frames; `MediaBackend` drives `QMediaPlayer` + `QVideoSink`, auto-plays clip 1, loops forever, no audio sink; pane shows the video, or the slideshow, or an honest error |
| **Expected on glass** | `hmi portrait-video`, insert card → MJPEG clip plays looping, header reads `PLAYING · SOFTWARE DECODE` |
| **Known cost** | CPU decode, **demo only**. Product path is zero-copy VPU on a DRM plane (ADR-001) and needs BLK-015 fixed. |

```bash
cd ~/Projects/elevator-hmi/images-archive
sha256sum qt-hmi-video.wic   # expect c74e86f65087a75a8f834c815fbac9c578064606634f2823e498436574e1aa37
sudo rkdeveloptool db loader.bin      # skip this line if the board is in Loader mode
sudo rkdeveloptool wl 0      qt-hmi-video.wic
sudo rkdeveloptool wl 64     idblock.img
sudo rkdeveloptool wl 0x4000 uboot.img
sudo rkdeveloptool rd
```

### Preparing the card

FAT32 only — the mount helper mounts `vfat`, and there are no exFAT tools in the
image, so a factory-formatted 64 GB+ card will silently fail to mount.

```bash
sudo mkfs.vfat -F 32 -n HMIMEDIA /dev/sdX1
```

Encode the clip as MJPEG at the pane size (800×600 portrait-video, 640×800
landscape-video). `-an` matters: `rk809-sound` does not probe on this board and
an unsatisfied audio sink can stall the pipeline.

```bash
ffmpeg -i source.mp4 -vf "scale=800:600:force_original_aspect_ratio=increase,crop=800:600" -c:v mjpeg -q:v 5 -r 25 -an ad.avi
```

Copy `ad.avi` to the card root. Playlist order is filename sort, so prefix
`01-`, `02-` when there is more than one.

---

## SUPERSEDED (2026-08-19) — qt-hmi-ads.wic — SD ad slideshow LIVE

**Status: recommended for next flash.** The video pane now actually shows media:
**still images from the SD card play as an ad slideshow**. Stills are a raster
blit, so they work under the software renderer with no GPU and no KMS — unlike
video, which stays blocked by BLK-015 and is listed but never faked.

| Field | Value |
|---|---|
| **Archive file** | `~/Projects/elevator-hmi/images-archive/qt-hmi-ads.wic` |
| **WIC SHA-256** | `bf709056f8c7bd6eca3782f1cadea362fcda6f1502d177e17acd1d956f92a56c` |
| **Deploy name** | `elevator-hmi-image-elevator-hmi-em3566.rootfs-20260818210110.wic` |
| **What changed** | `MediaBackend` also scans images and drives a 7 s slideshow; `VideoPane` renders them (PreserveAspectCrop, fade-in, `n / N` counter, caption); `hmi media` dumps SD state over UART |
| **Expected on glass** | `hmi portrait-video`, insert a FAT32 card with `.jpg/.png` → the pane fills with the photo and rotates every 7 s. With only `.mp4` on the card the pane still says `NO SOURCE` + `VIDEO BLOCKED (BLK-015)`. |
| **On-target** | `hmi media`, `hmi portrait-video`, `hmi wrap` (52) |

```bash
cd ~/Projects/elevator-hmi/images-archive
sha256sum qt-hmi-ads.wic   # expect bf709056f8c7bd6eca3782f1cadea362fcda6f1502d177e17acd1d956f92a56c
sudo rkdeveloptool db loader.bin
sudo rkdeveloptool wl 0      qt-hmi-ads.wic
sudo rkdeveloptool wl 64     idblock.img
sudo rkdeveloptool wl 0x4000 uboot.img
sudo rkdeveloptool rd
```

Supported ad formats are limited to what qtbase can decode in this image —
`.jpg .jpeg .png .bmp .gif`. `qtimageformats` is NOT installed, so webp/tiff are
deliberately not listed: they would show as playable and then render nothing.

---

## SUPERSEDED (2026-08-18) — qt-hmi-daylight.wic — wrap 52 + SD chrome

**Status: recommended for next flash.** Daylight theme, openFrac boot fix,
**52 px** wrap (lab-fitted), and Stage 1 SD plumbing: udev mounts VFAT
`mmcblk1` at `/media/sdcard`, QML video pane shows card/clip status.
No frames yet (BLK-015). `hmi portrait-video` to see the pane.

| Field | Value |
|---|---|
| **Archive file** | `~/Projects/elevator-hmi/images-archive/qt-hmi-daylight.wic` |
| **WIC SHA-256** | `3d71c658bd44831cadfc63be9db73f6a4be5dbc8d61560ded451881a658639b3` |
| **Deploy name** | `elevator-hmi-image-elevator-hmi-em3566.rootfs-20260818204839.wic` |
| **Expected on glass** | Light GUI, borders inside the panel (wrap 52). Video layouts: `NO CARD` / `SD · EMPTY` / clip name. Hatch stays; no playback. |
| **On-target** | `hmi wrap` (should be 52), insert VFAT TF card, `ls /media/sdcard`, `hmi portrait-video` |

```bash
cd ~/Projects/elevator-hmi/images-archive
sha256sum qt-hmi-daylight.wic   # expect 3d71c658bd44831cadfc63be9db73f6a4be5dbc8d61560ded451881a658639b3
sudo rkdeveloptool db loader.bin
sudo rkdeveloptool wl 0      qt-hmi-daylight.wic
sudo rkdeveloptool wl 64     idblock.img
sudo rkdeveloptool wl 0x4000 uboot.img
sudo rkdeveloptool rd
```

Wrap-16 SHA `99c4c268…` is `qt-hmi-daylight-wrap16.wic`.
openFrac-only SHA `d074054a…` is `qt-hmi-daylight-openfrac.wic`.
First daylight SHA `36e1aabe…` is `qt-hmi-daylight-qmlcrash.wic`.

---

## SUPERSEDED (2026-08-18) — qt-hmi-daylight.wic SHA `36e1aabe…` — QML crash

**Status: do not flash.** Same daylight theme, but `Behavior on openFrac`
with `readonly` — HMI never starts, splash stays. Archived as
`qt-hmi-daylight-qmlcrash.wic`.

---

## SUPERSEDED (2026-08-18) — qt-hmi-orientations.wic — portrait + landscape

**Status: superseded** by `qt-hmi-daylight.wic` (theme). This is the load-fix
image (`Loader` cwd bug). Dark amber-on-black theme. Keep for comparing
layout geometry if the new theme needs a sanity check.

| Field | Value |
|---|---|
| **Archive file** | `~/Projects/elevator-hmi/images-archive/qt-hmi-orientations.wic` |
| **WIC SHA-256** | `d45ed163958d9ee4a148ccb13d67ba32fb865fd3b2e3d22e670cc6628e97b6a5` |
| **Deploy name** | `elevator-hmi-image-elevator-hmi-em3566.rootfs-20260818194759.wic` |
| **On-target** | `hmi` / `hmi portrait` / `hmi portrait-video` / `hmi landscape` / `hmi landscape-video` / `hmi rot 90\|270` |

---

## SUPERSEDED (2026-08-18) — qt-hmi-layouts.wic — HTML demo GUI, CLI layouts

**Status: superseded** by `qt-hmi-orientations.wic` (adds landscape). Portrait-only
800×1280 HMI from `design/elevator-hmi` (Vertical + Vertical Video).

| Field | Value |
|---|---|
| **Archive file** | `~/Projects/elevator-hmi/images-archive/qt-hmi-layouts.wic` |
| **WIC SHA-256** | `92c19eeb6ec57952af1a33ba4702bdc62e4274a3f89e8cd8fa621128116eb502` |
| **git HEAD** | `a25793d` |
| **Deploy name** | `elevator-hmi-image-elevator-hmi-em3566.rootfs-20260818190945.wic` |
| **On-target** | `hmi` / `hmi car` / `hmi video` |

---

## SUPERSEDED (2026-08-18) — qt-hmi-linuxfb.wic — first HMI on glass

**Status: superseded** by `qt-hmi-layouts.wic`. First image where the Qt HMI actually
displays. Uses `linuxfb` + software rendering instead of EGLFS — **KMS scanout
does not reach this panel (BLK-015)**; `modetest` with a dumb buffer is as
invisible as Qt. Includes the fonts fix, so text should render for the first time.

| Field | Value |
|---|---|
| **Archive file** | `~/Projects/elevator-hmi/images-archive/qt-hmi-linuxfb.wic` |
| **WIC SHA-256** | `e202c6bce9705ac043fa5f4b3169b9294f39b066c7c62d78a0e8ee133ff494ed` |
| **Deploy name** | `elevator-hmi-image-elevator-hmi-em3566.rootfs-20260818181923.wic` |
| **What changed** | `QT_QPA_PLATFORM=linuxfb`, `QT_QUICK_BACKEND=software`; init script unbinds `vtcon1` on start (fbcon shares `/dev/fb0`) and rebinds on stop; `liberation-fonts` + `fontconfig-utils` |
| **Expected on glass** | Tux/fbcon briefly, then the Qt HMI **with text**: floor number, direction arrow, 12-floor ladder, `IN SERVICE` |
| **Known cost** | No Mali GPU (software rendering). **GStreamer VPU video will NOT work through linuxfb** — needs BLK-015 fixed. |
| **On-target checks** | `/var/log/elevator-hmi.log`, `fc-list \| head`, `/etc/init.d/elevator-hmi status` |

```bash
cd ~/Projects/elevator-hmi/images-archive
sha256sum qt-hmi-linuxfb.wic   # expect e202c6bce9705ac043fa5f4b3169b9294f39b066c7c62d78a0e8ee133ff494ed
sudo rkdeveloptool db loader.bin
sudo rkdeveloptool wl 0      qt-hmi-linuxfb.wic
sudo rkdeveloptool wl 64     idblock.img
sudo rkdeveloptool wl 0x4000 uboot.img
sudo rkdeveloptool rd
```

---

## SUPERSEDED (2026-08-18) — qt-hmi-fonts.wic — Qt image with fonts (EGLFS, does not display)

**Status: recommended for next flash.** Identical to `qt-hmi.wic` plus the fonts that
image was missing entirely, and an init script that reports real start failures.
Kernel unchanged — proven **0021-only** panel config. 0022/0023/0024 stay disabled.

| Field | Value |
|---|---|
| **Archive file** | `~/Projects/elevator-hmi/images-archive/qt-hmi-fonts.wic` |
| **WIC SHA-256** | `2177329d75a5021206a99056176bd2a007a0b7205b316d21a3a7c3a68ef5200a` |
| **git HEAD** | `7c82fe3` |
| **Deploy name** | `elevator-hmi-image-elevator-hmi-em3566.rootfs-20260818165008.wic` |
| **What changed** | `liberation-fonts` + `fontconfig-utils` installed; init script verifies the pid is alive before printing `OK` and dumps the log tail on failure |
| **Why** | The 2026-08-17 image shipped **no font files at all** — only libfontconfig1/libfreetype6. Every QML `Text` rendered blank over a `#0d1117` background, which on glass is indistinguishable from a dead panel. |
| **Expected on glass** | Tux/fbcon briefly, then the Qt HMI: large floor number, direction arrow, 12-floor ladder, `IN SERVICE` |
| **If fbcon paints over Qt** | `echo 0 > /sys/class/vtconsole/vtcon1/bind` |
| **On-target checks** | `/var/log/elevator-hmi.log`, `fc-list \| head`, `/etc/init.d/elevator-hmi status` |

```bash
cd ~/Projects/elevator-hmi/images-archive
sha256sum qt-hmi-fonts.wic   # expect 2177329d75a5021206a99056176bd2a007a0b7205b316d21a3a7c3a68ef5200a
sudo rkdeveloptool db loader.bin
sudo rkdeveloptool wl 0      qt-hmi-fonts.wic
sudo rkdeveloptool wl 64     idblock.img
sudo rkdeveloptool wl 0x4000 uboot.img
sudo rkdeveloptool rd
```

Fallbacks: `qt-hmi.wic` (previous Qt image, no fonts), then `fbcon-display.wic`
(last proven unaided-display image).

---

## SUPERSEDED (2026-08-18) — qt-hmi.wic — first Qt 6.8.3 EGLFS image (no fonts)

**Status: superseded by `qt-hmi-fonts.wic`.** Boots and runs Qt/EGLFS correctly —
the UART log shows the Mali blob loading, DSI1 mode set at 800x1280@60, plane 96
chosen and framebuffers flipping — but it contains **no fonts**, so the HMI's text
is invisible. Kept as a rollback point. First `elevator-hmi-image` with public
Qt 6.8.3, Mali-G52 EGLFS, and the QML mockup. Kernel is the proven **0021-only**
panel config (same as `fbcon-display.wic`). Patches 0022/0023/0024 stay disabled.

| Field | Value |
|---|---|
| **Archive file** | `~/Projects/elevator-hmi/images-archive/qt-hmi.wic` |
| **WIC SHA-256** | `06a9f623c66239461bf8718b9d19390f8b3893b061aa903178308cd3ffe0a768` |
| **git HEAD** | `134332a` (recipes that produced this image) |
| **Deploy name** | `elevator-hmi-image-elevator-hmi-em3566.rootfs-20260817221725.wic` |
| **Manifest** | `qtbase` 6.8.3, `qtdeclarative` 6.8.3, `rockchip-libmali`, `elevator-hmi-app` 0.1 all present |
| **App payload** | `/usr/bin/elevator-hmi` (67 KB), `/usr/share/elevator-hmi/main.qml` (9.7 KB), `/etc/init.d/elevator-hmi` (sysvinit `defaults 99 01`) |
| **Expected on glass** | Tux/fbcon briefly, then the Qt HMI mockup (floor number, direction arrow, 12-floor ladder). |
| **If fbcon paints over Qt** | `echo 0 > /sys/class/vtconsole/vtcon1/bind` |
| **On-target checks** | `/var/log/elevator-hmi.log`, `/etc/init.d/elevator-hmi status`, or run `/usr/bin/elevator-hmi` with `QT_QPA_PLATFORM=eglfs` |

```bash
cd ~/Projects/elevator-hmi/images-archive
sha256sum qt-hmi.wic   # expect 06a9f623c66239461bf8718b9d19390f8b3893b061aa903178308cd3ffe0a768
sudo rkdeveloptool db loader.bin
sudo rkdeveloptool wl 0      qt-hmi.wic
sudo rkdeveloptool wl 64     idblock.img
sudo rkdeveloptool wl 0x4000 uboot.img
sudo rkdeveloptool rd
```

**Do not flash `master-image.wic`.** That image still carries patch 0024 (BIST-then-video).
BIST never produced a visible pattern here and leaves the panel degraded
(`0x0A=0x08`, `0x0F=0x00`). Fallback if this Qt image misbehaves on glass:
`fbcon-display.wic` (SHA `f13f3eb0…`) — last proven unaided-display image.

---

## SUPERSEDED (2026-08-07) — MASTER IMAGE: BIST self-test then video — DO NOT FLASH

**Status: do not flash.** Patch 0024. BIST is useless on this panel and degrades
it. Kept only as a historical archive pointer. The 2026-08-07 text below is
the original claim; it is no longer the recommended target.

| Field | Value |
|---|---|
| **Archive file** | `~/Projects/elevator-hmi/images-archive/master-image.wic` |
| **WIC SHA-256** | `e479c2e4f3bffd46760978f9d2d82efa9cdafaf765ac4cec1f871c36617f0b6b` |
| **git HEAD** | `2e16a30` (clean tree) |
| **Confound check** | Image strings: `MASTER self-test phase (cmd-mode, pre-video)`, `BIST armed (self-test phase)`, `MASTER video phase - second reset + clean init` all present; old 0022/0023 sentinels (`BIST armed (INIT-IN-PREPARE`, `BIST armed (FAE_CLOCK`) confirmed ABSENT |
| **Expected dmesg** | `MASTER self-test phase` → init/SLPOUT/DISON → `BIST armed (self-test phase)` → ~300ms → `MASTER video phase - second reset + clean init` → **second** `XRES assert`/`XRES release` pair → init/SLPOUT/DISON again → then the normal `dsi mode_flags=...video=1` line and video-mode handoff. Two full XRES assert/release pairs per boot is the expected, correct signature — not a bug. |
| **What to report back** | (a) full `dmesg \| grep -iE "jadard\|bandwidth"` — confirm the two-phase sequence and both XRES pairs, (b) glass — same black/pattern grid as prior BIST tests applies to phase 1; phase 2 (video) behavior is whatever the standing diagnosis predicts (currently: black, backlit) |

### Flash commands (master-image) — from the permanent archive

```bash
cd ~/Projects/elevator-hmi/images-archive
sha256sum master-image.wic   # expect e479c2e4f3bffd46760978f9d2d82efa9cdafaf765ac4cec1f871c36617f0b6b
sudo rkdeveloptool db loader.bin
sudo rkdeveloptool wl 0      master-image.wic
sudo rkdeveloptool wl 64     idblock.img
sudo rkdeveloptool wl 0x4000 uboot.img
sudo rkdeveloptool rd
```

---

## ✅ CURRENT IMAGE (2026-08-07) — fbcon-display.wic — PANEL WORKS

**BLK-014 is RESOLVED. The display works.** This is the first image that shows content on
the glass with no manual intervention.

Configuration: patch **0021 only** (INIT-IN-PREPARE — vendor bring-up sent in DSI command
mode before video starts; *this was the actual fix*) plus **`CONFIG_FRAMEBUFFER_CONSOLE`**
and **`CONFIG_LOGO`** newly enabled. Patches 0022/0023/0024 (BIST variants, rail-delay test)
are **disabled and must stay disabled** for any image meant to display — BIST leaves the
panel degraded (`0x0A=0x08`, `0x0F=0x00`) and never produced a visible pattern here.

| Field | Value |
|---|---|
| **Archive file** | `~/Projects/elevator-hmi/images-archive/fbcon-display.wic` |
| **WIC SHA-256** | `f13f3eb00d95a0465e3b7b265e800020ae55d4deb6d4e55e578f59b304410bab` |
| **Confound check** | Image strings: `INIT-IN-PREPARE (cmd-mode, pre-video)` present; `MASTER self-test phase` / `BIST armed (self-test phase)` **absent**. Kernel `.config`: `CONFIG_FRAMEBUFFER_CONSOLE=y`, `CONFIG_LOGO=y`. (`BIST armed (500ms post-unlock)` may still appear in `strings` — dead code from patch 0014, unreachable since `enable_seq = FAE_CLOCK`.) |
| **Expected on glass** | **Tux boot logo**, then kernel boot messages rendering on the panel — automatically, no commands needed. |
| **Expected dmesg** | `INIT-IN-PREPARE (cmd-mode, pre-video)` → DCS-INIT → page-4 fix → SLPOUT → DISON → `0x0A=0x1c`, `0x0F=0xc0` (healthy) → `final DSI-Link bandwidth: 468 x 4 Mbps` |

```bash
cd ~/Projects/elevator-hmi/images-archive
sha256sum fbcon-display.wic   # expect f13f3eb00d95a0465e3b7b265e800020ae55d4deb6d4e55e578f59b304410bab
sudo rkdeveloptool db loader.bin
sudo rkdeveloptool wl 0      fbcon-display.wic
sudo rkdeveloptool wl 64     idblock.img
sudo rkdeveloptool wl 0x4000 uboot.img
sudo rkdeveloptool rd
```

**Note:** once fbcon is active it owns `/dev/fb0` and repaints the console, so the manual
`dd`-to-framebuffer demos will be overwritten. Use `/dev/tty1` for text, or stop the console
first, if you want to drive the framebuffer directly on this image.

---

## ⚠️ ARCHIVE POLICY (added 2026-08-07 — read before flashing)

**Never flash from `build/tmp/deploy/images/.../` by a symlink name.** Yocto's deploy step
**deletes** the previous build's timestamped `.wic` on every new `kas build` — this bit us
directly on 2026-08-07: a symlinked `init-in-prepare.wic` and `bist-inprep.wic` both went
dangling mid-session when a later build pruned their targets, causing two failed/wasted flash
attempts (`wl 0` errored, `can't open file`, rootfs never written).

**Fix:** every image worth reflashing is hardlinked (zero extra disk, immune to pruning) into
`~/Projects/elevator-hmi/images-archive/`, alongside `loader.bin` / `idblock.img` / `uboot.img`.
Always flash from **that directory**, by its short name, never by the deploy-dir symlink.

## CURRENT TEST TARGET (2026-08-07, later) — POWER-DELAY test: 250ms rail settle before XRES

**Status: recommended for next flash.** BIST-in-prepare kill test came back black through
the full 2 s command-mode-only window (ordering hypothesis falsified — see the RESULT block
in the previous section below). New single-variable test on top of that same base: the
vendor's Q1 diagram states 10 ms between VCC3V3_LCD assertion and the RESX pulse; our rail's
actual ramp time has never been scoped, and the power path has been through two hardware
corrections this campaign. Patch 0023 extends that one `msleep()` to 250 ms — nothing else
changes (0021 ordering fix + 0022 BIST arm both still active).

**Kill test (written before flashing):**
- **Pattern appears (even only in the BIST window)** → 10 ms was insufficient rail settle
  time on our specific hardware — a real, fixable finding, independent of the panel/vendor's
  own fixture characteristics.
- **Still black** → further evidence against rail-timing as an explanation (not fully
  conclusive without a scope trace of the actual VCC3V3_LCD rise — no oscilloscope on this
  bench yet).

| Field | Value |
|---|---|
| **Archive file** | `~/Projects/elevator-hmi/images-archive/power-delay-250ms.wic` |
| **WIC SHA-256** | `542ab97ef79c80b8a343356165563e4874199f6c66962dd1ff695b2bc7d838d8` |
| **git HEAD** | `d655a82` (also restores 0022, which had been accidentally reverted out of git metadata by an earlier recovery step — the previously-archived `bist-inprep.wic` binary itself was never affected, only the tracked config had drifted) |
| **Confound check** | Image strings: `BIST armed (INIT-IN-PREPARE, cmd-mode, pre-video)` + `INIT-IN-PREPARE (cmd-mode, pre-video)` both present, confirming 0021+0022 both compiled in alongside 0023 |
| **Expected dmesg** | Same shape as the previous BIST-in-prepare test, but with a visibly longer gap between `XRES assert`/`XRES release` and the earlier init lines — the extra 240 ms (250 ms new vs 10 ms old) should show up directly in the timestamps before `XRES assert` |
| **What to report back** | (a) full `dmesg \| grep -iE "jadard\|bandwidth"`, (b) glass during boot — watch continuously from power-on; window is now ~4.2–6.2 s in (shifted later by the extra 240 ms) |

### Flash commands (power-delay-250ms) — from the permanent archive

```bash
cd ~/Projects/elevator-hmi/images-archive
sha256sum power-delay-250ms.wic   # expect 542ab97ef79c80b8a343356165563e4874199f6c66962dd1ff695b2bc7d838d8
sudo rkdeveloptool db loader.bin
sudo rkdeveloptool wl 0      power-delay-250ms.wic
sudo rkdeveloptool wl 64     idblock.img
sudo rkdeveloptool wl 0x4000 uboot.img
sudo rkdeveloptool rd
```

---

## PREVIOUS TEST TARGET (2026-08-07) — BIST-IN-PREPARE: self-test on corrected command ordering — RESULT: BLACK through full command-mode window, ordering hypothesis FALSIFIED

**Status: recommended for next flash (owner-selected: BIST-first).** Built on the 2026-07-23
root-cause finding: this vendor kernel switches the DSI host to VIDEO mode BEFORE
`drm_panel_enable()`, so every prior build sent init/SLPOUT/DISON (and the old BIST arm)
inside live-video blanking — the panel received HS video before init on every boot of this
campaign. Patches 0021+0022 relocate the ENTIRE vendor sequence (196-cmd table → page-4 fix →
SLPOUT → 120 ms → DISON → vendor TEST 2 BIST arm) into `prepare()` — DSI COMMAND mode,
pre-video, fixture-identical — with a **2 s dwell** after the BIST arm as an observation
window before DRM starts video.

**Kill test (written before flashing):**
- **Pattern on glass (even only during the 2 s window)** → panel/boost/TCON healthy; the
  video-mode init ordering was the root cause → flash `init-in-prepare.wic` (video image,
  same ordering, no BIST) and expect fbcon.
- **Still black** → panel fails its own self-test under fixture-identical ordering, correct
  power (stock switch), correct reset, two units → hardware verdict final; send email #4
  (updated with this result).

| Field | Value |
|---|---|
| **Archive file** | `~/Projects/elevator-hmi/images-archive/bist-inprep.wic` |
| **WIC SHA-256** | `6b74331dd7d27c750a47741694764327317cbec4c409716d9ffe3be32dbce2a1` |
| **git HEAD** | `ba66670` (clean tree) |
| **Confound check** | Image strings: `BIST armed (INIT-IN-PREPARE, cmd-mode, pre-video)` + `INIT-IN-PREPARE (cmd-mode, pre-video)` present |
| **Expected dmesg** | `INIT-IN-PREPARE (cmd-mode, pre-video)` → `DCS-INIT` → `FAE page-4 clock fix` → `SLPOUT sent` → `DISON sent` → `BIST armed (INIT-IN-PREPARE, cmd-mode, pre-video)` — all BEFORE the `dsi mode_flags`/enable lines; then enable prints `INIT-IN-PREPARE active - enable() diagnostics only` + DIAG15 reads |
| **What to report back** | (a) full `dmesg \| grep -iE "jadard\|bandwidth"`, (b) glass during boot — watch continuously from power-on; the 2 s window lands ~4–6 s in |

### Checkpoint ledger (permanent archive — `~/Projects/elevator-hmi/images-archive/`)

| Checkpoint | Archive filename | SHA-256 | git | Status |
|---|---|---|---|---|
| Video baseline, old ordering | *(not archived — pruned)* | `962c58eb…` | `c934583` | rebuild to restore |
| BIST, old ordering (black × 2 panels) | *(not archived — pruned)* | `de0e0b60…` | `e7871a9` | rebuild to restore |
| Video, corrected ordering (NEXT after BIST) | `init-in-prepare.wic` | `0c947979de9a79621f12c984171070400c47ceab86eb8c16cf7de8b7669a5801` | `f04ae58` | ✅ archived 2026-08-07 (rebuilt — SHA differs from the original same-commit build, expected: binary is not bit-reproducible across rebuilds) |
| **BIST, corrected ordering (FLASH FIRST)** | `bist-inprep.wic` | `6b74331dd7d27c750a47741694764327317cbec4c409716d9ffe3be32dbce2a1` | `ba66670` | ✅ archived 2026-08-07 |

To rebuild any non-archived checkpoint: `git checkout <commit> -- meta-hmi-platform/recipes-kernel/linux/'linux-rockchip_%.bbappend' && kas build kas/elevator-hmi.yml`, then immediately hardlink the result into `images-archive/` before building anything else.

### Flash commands (bist-inprep) — from the permanent archive

```bash
cd ~/Projects/elevator-hmi/images-archive
sha256sum bist-inprep.wic   # expect 6b74331dd7d27c750a47741694764327317cbec4c409716d9ffe3be32dbce2a1
# Maskrom, then:
sudo rkdeveloptool db loader.bin
sudo rkdeveloptool wl 0      bist-inprep.wic
sudo rkdeveloptool wl 64     idblock.img
sudo rkdeveloptool wl 0x4000 uboot.img
sudo rkdeveloptool rd
```

### Flash commands (init-in-prepare, video — run only after BIST result is in)

```bash
cd ~/Projects/elevator-hmi/images-archive
sha256sum init-in-prepare.wic   # expect 0c947979de9a79621f12c984171070400c47ceab86eb8c16cf7de8b7669a5801
sudo rkdeveloptool db loader.bin
sudo rkdeveloptool wl 0      init-in-prepare.wic
sudo rkdeveloptool wl 64     idblock.img
sudo rkdeveloptool wl 0x4000 uboot.img
sudo rkdeveloptool rd
```

---

## PREVIOUS TEST TARGET (2026-07-22) — BIST diagnostic image (vendor 7/7 request), 468 Mbps base — RESULT: BLACK, both panels

**Status: recommended for next flash.** Vendor's 7 Jul decision tree, run fresh on the
now-validated hardware (owner: reset correct, rails DMM-verified, backlight lit; spare panel
already swapped — also black). Patch 0020 arms the vendor TEST 2 BIST sequence
(`F0,55 / F1,AA / E0,01 / E3,01`) after the full 196-cmd init + page-4 clock fix + SLPOUT/DISON,
with the DIAG15 reads (`0x0A/0x04/0x0F/0x45`) captured BEFORE the BIST arm. Built on the
clean-reads 468 Mbps base so the register verdict is reliable in the same boot.

**Kill test (written before flashing):**
- **Test pattern appears on glass** → panel + boost healthy → fault is in the host video path;
  next single-variable suspect is the MediaTek `PLL_CLOCK=420` interpretation (420 MHz clock
  lane = **840 Mbps/lane** DDR, never tested — every build so far ran 420 or 468 Mbps/lane).
- **Still black** → by the vendor's own written criterion ("panel or JD5001 boost circuit
  faulty — hardware issue confirmed"), on TWO panels with verified reset/rails/backlight →
  reply to vendor demands hardware disposition (RMA / cross-test / fixture comparison), no
  further firmware permutations.

| Field | Value |
|---|---|
| **File** | `core-image-minimal-elevator-hmi-em3566.rootfs-20260722201147.wic` (symlink `…rootfs-bist-468.wic`) |
| **Built** | 2026-07-22 23:16 (fresh, this session) |
| **WIC SHA-256** | `de0e0b6035074d7d75bb0d4d661888a9054b0c01a143d6448c3ca28c59428473` |
| **git HEAD** | `e7871a9` (clean tree — no uncommitted kernel/DTS deltas for the first time this campaign) |
| **Confound check** | Image `strings`: `BIST armed (FAE_CLOCK + vendor TEST 2)` present; DTB: `rockchip,lane-rate` 0 occurrences (468 base), `lcd-rst` 2 (reset fix intact) |
| **Expected dmesg** | Same clean sequence as 468-clean-reads PLUS sentinel `jadard: BIST armed (FAE_CLOCK + vendor TEST 2)` after the DIAG15 reads |
| **What to report back** | (a) `dmesg \| grep -iE "jadard\|bandwidth"` in full, (b) **glass appearance / photo** — pattern vs black is the entire verdict, (c) note: E3,01 soft-resets the display engine, so normal video will NOT work on this image — that is expected |

### Flash commands (BIST image)

```bash
# ── 0. From repository root ──────────────────────────────────────────
DEPLOY=build/tmp/deploy/images/elevator-hmi-em3566
WIC=core-image-minimal-elevator-hmi-em3566.rootfs-bist-468.wic

# ── 1. Verify SHA before touching the board ──────────────────────────
sha256sum "$DEPLOY/$WIC"
# Expected: de0e0b6035074d7d75bb0d4d661888a9054b0c01a143d6448c3ca28c59428473
# (then follow the same Maskrom + rkdeveloptool steps as the section below)
```

---

## PREVIOUS TEST TARGET (2026-07-03, final) — reverted to proven clean-reads state (468 Mbps)

**Status: flashed 2026-07-03, confirmed on board 2026-07-22 (boot log reviewed — image identity verified).** Supersedes `420clean-xres.wic`, `no-pinctrl-fix.wic`, and
`final-reset-restored.wic` (all preserved in git history). Full story, in order today: (1) blamed
420 Mbps for `-110` DCS-read timeouts — wrong, `7dbf72d9…` proved 420 Mbps alone reads clean;
(2) blamed BIST (patch 0020) — wrong, a BIST-free rebuild still showed `-110`; (3) blamed TASK-141's
XRES pinctrl fix — wrong, owner confirmed it predates the 420 Mbps change and restoring it changed
nothing; (4) **owner call: stop guessing which single variable causes `-110` at 420 Mbps, and
instead revert to the one state proven to give clean reads on every occasion it's been tested** —
non-burst, driver-calculated ~468 Mbps (no `rockchip,lane-rate` DT override), reset-pin fix intact.
Full chain: `diary/SESSION-LOG.md` 2026-07-03, all entries this date.

This build removes the `rockchip,lane-rate = <420>` property (vendor PLL_CLOCK=420 parity is
knowingly deferred, not abandoned) while keeping TASK-141's pinctrl fix, `0018` DCS-INIT, and the
FAE page-4 clock fix exactly as they are. Purpose: get to the most diagnostically trustworthy state
— reliable register reads — before treating the booster-off finding (`0x0A` bit clear) as solid
grounds for a hardware conclusion. Every prior test of this exact configuration (no rate override)
has produced clean reads; if this one does too, that closes the reliability question and the
booster-off finding stands on its own without any `-110` caveat.

| Field | Value |
|---|---|
| **File** | `core-image-minimal-elevator-hmi-em3566.rootfs-20260703200725.wic` (symlink `…rootfs-468-clean-reads.wic`) |
| **Built** | 2026-07-03 23:07 (fresh rebuild, this session) |
| **WIC SHA-256** | `962c58ebea61f62d9b02e2890d1cb36e4b3503adc514f9d3c787581022a96466` |
| **git HEAD** | `7bbb717b4c722c7a7e3a90e1315583d86d6a6856` + lane-rate revert + pinctrl-restore (commits pending) |
| **Confound check** | DTB `strings`: `rockchip,lane-rate` — 0 occurrences (removed); `lcd-rst-pin` — 2 occurrences (reset fix intact) |
| **Expected dmesg** | `final DSI-Link bandwidth: 468 x 4 Mbps` (NOT 420); `XRES assert`/`XRES release`; `DCS-INIT`; `FAE page-4 clock fix`; clean `GET_POWER_MODE(0x0A)=0x1c`, `DIAG15 self-diag=0xc0`, `DIAG15 scanline=0x00`, `ID=0x93` — no `-110` expected |
| **What to report back** | (a) full `dmesg -iE "jadard\|bandwidth\|mode_flags"` output — confirm bandwidth is 468 and reads are clean, (b) glass appearance |

### Flash commands (current test target)

```bash
# ── 0. From repository root ──────────────────────────────────────────
DEPLOY=build/tmp/deploy/images/elevator-hmi-em3566
WIC=core-image-minimal-elevator-hmi-em3566.rootfs-468-clean-reads.wic

# ── 1. Verify SHA before touching the board ──────────────────────────
sha256sum "$DEPLOY/$WIC"
# Expected: 962c58ebea61f62d9b02e2890d1cb36e4b3503adc514f9d3c787581022a96466

# ── 2. Enter Maskrom ─────────────────────────────────────────────────
#    Power OFF → hold RECOVERY → plug USB OTG → release after 2 s
lsusb | grep 2207
# 2207:350a = Maskrom  →  run db first (below)
# 2207:0006 = Loader   →  skip db, go straight to wl

# ── 3a. Flash — Maskrom mode (2207:350a) ─────────────────────────────
cd "$DEPLOY"
sudo rkdeveloptool db loader.bin
sudo rkdeveloptool wl 0    "$WIC"
sudo rkdeveloptool wl 64   idblock.img
sudo rkdeveloptool wl 0x4000 uboot.img
sudo rkdeveloptool rd

# ── 3b. Flash — Loader mode (2207:0006, skip db) ─────────────────────
# cd "$DEPLOY"
# sudo rkdeveloptool wl 0    "$WIC"
# sudo rkdeveloptool wl 64   idblock.img
# sudo rkdeveloptool wl 0x4000 uboot.img
# sudo rkdeveloptool rd
```

### After reboot — open serial console

```bash
sudo minicom -D /dev/ttyACM0 -b 1500000
# (8N1, no flow control; ttyUSB0 or 115200 baud on some setups — check BRINGUP-CHECKLIST §4)
```

### Post-flash validation (on board as `root`)

**This is an untested build — report what you actually see, don't check it against a fixed
pass/fail list.** (The old fixed checklist here — "MUST see 420 Mbps," etc. — is exactly the kind
of hardcoded assumption that went stale last time; see the warning banner at the top of this file.)

```bash
# ── Capture everything relevant, verbatim, full output ────────────────
dmesg | grep -iE "jadard|bandwidth|mode_flags|dsi-link"
# Report this whole block back as-is. Things worth noticing (not requirements):
#   - Does "jadard: DCS-INIT" appear? (confirms 0018 compiled in)
#   - What bandwidth does "final DSI-Link bandwidth: ... Mbps" actually report? (420 expected
#     given the DT override in this build, but confirm — don't assume)
#   - Any "-110" / ETIMEDOUT on the DIAG15 register reads? (known risk for this specific build,
#     see CURRENT TEST TARGET section above — if present, that's a real result, not a failure
#     of the test itself)
#   - GET_POWER_MODE(0x0A) value, DIAG15 ID/self-diag/scanline values if reads succeed

# ── Modeset + scanout ─────────────────────────────────────────────────
CONN=$(modetest -M rockchip 2>&1 | awk '/connected/ && /DSI/ {print $1; exit}')
echo "Connector: $CONN"
modetest -M rockchip -s ${CONN}@112:#0 -P 96@112:800x1280+0+0 -F tiles -v
# Report actual result: 60 Hz sustained or not; glass appearance (flat black / noise / vignetting /
# lit / other) — describe what you actually see, take a photo if possible.

# ── Scope targets if glass still black (unchanged from prior sessions, no equipment currently) ──
# H1b:  CON1 pin 3 (VDDIN, FPC pin 2/3) — must be stable ≥3.0 V at SLPOUT+120 ms
# H5:   Set BL supply to exactly 9.6 V (currently 9.0 V → vendor spec 9.6 V)
# H6:   Swap panel sample (fresh LMT101SX006C from stock — on hand per diary/SESSION-LOG.md)
# CLK:  Scope MIPI CLK+D0 at video start (confirmatory; LP→HS transition)
```

---

## BUILD B — FAE clock fix (2026-06-10 canonical artifact)

**Flash this for bench Step B2 (TASK-135).** Do not use `ls -t *.wic | head -1` for this target — use the exact filename.

```bash
DEPLOY=build/tmp/deploy/images/elevator-hmi-em3566

# 1. Verify SHA before flashing (mandatory per artifact-triple rule)
sha256sum "$DEPLOY/core-image-minimal-elevator-hmi-em3566.rootfs-fae-clock.wic"
# Expected: dd5be78dec198a984dce271a658219b3e44006df58d04709a3bed66fbb9728ad
# File:     core-image-minimal-elevator-hmi-em3566.rootfs-20260610170030.wic
# git HEAD: e19ae163b81db9c08b1b04813b313079787f0ff0

# 2. Enter Maskrom: power off → hold RECOVERY → plug USB OTG → release after 2s
lsusb | grep 2207   # 2207:350a = Maskrom  /  2207:0006 = Loader (skip db below)

# 3. Flash (Maskrom path)
cd "$DEPLOY"
sudo rkdeveloptool db loader.bin
sudo rkdeveloptool wl 0 core-image-minimal-elevator-hmi-em3566.rootfs-fae-clock.wic
sudo rkdeveloptool wl 64 idblock.img
sudo rkdeveloptool wl 0x4000 uboot.img
sudo rkdeveloptool rd

# 4. Open UART (1500000 baud) immediately after rd
sudo minicom -D /dev/ttyACM0 -b 1500000
```

**After boot — first check (decisive):**
```bash
dmesg | grep -i jadard
# MUST see: jadard: FAE page-4 clock fix (pre-SLPOUT)
# MUST see: jadard: GET_POWER_MODE(0x0A) pre-TE=0x??  ← record this value
# MUST NOT: jadard: BIST armed
```

See `docs/LAB-LMT101-TEST-CHEATSHEET.md` **Phase J** for the full BUILD B test suite and decision matrix.

---

## Build — TASK‑129 DTS `core-image-minimal` (Yocto host)

From **repository root** on a TASK‑002-class host (**Ubuntu** 22.04/24.04, `**scripts/setup-build-host.sh**`, **`kas`**, **`lz4c`**). The DTS is **`task/TASK-129-vcc3v3-lcd0-pfet-polarity`** snapshot: **`elevator-hmi-boardcon-em3566-v3.dts`** (single **`…v3.dtb`** on **`/boot`**).

**Recommended (kernel + WIC, forced refresh):**

```bash
kas shell kas/elevator-hmi.yml -c " \
  bitbake virtual/kernel -c compile -f && \
  bitbake virtual/kernel -c deploy -f && \
  bitbake core-image-minimal -c image_wic -f && \
  bitbake core-image-minimal -c image_complete -f "
```

**Smoke path (TASK‑105, also refreshes loaders + kernel + image via default target):**

```bash
./scripts/kas-build-task-105.sh
```

Artefacts: **`build/tmp/deploy/images/elevator-hmi-em3566/`** — **`*.wic`**, **`loader.bin`**, **`idblock.img`**, **`uboot.img`**, **`Image`**, **`elevator-hmi-boardcon-em3566-v3.dtb`**.

**Example (this workspace, 2026‑05‑20):**

| Artefact | Value |
|---|---|
| WIC | **`core-image-minimal-elevator-hmi-em3566.rootfs-20260520184237.wic`** |
| WIC SHA‑256 | `ee9866c538420d7befc149be953bef7a358591724020230171ddbf3a47635069` |
| DTB SHA‑256 (**TASK‑129 tree**) | `54f07dba885b86b00e4d210110ce353dc686df6d1d8930a71824d3f365364972` |

After every rebuild, **`ls -t build/tmp/deploy/images/elevator-hmi-em3566/*.wic | head -1`** and record the new **`rootfs-<timestamp>.wic`** (and **`sha256sum`**) next to **`diary/PROGRESS.md`** if you rely on rollback.

Then continue with **Step 2** / **Step 3** below to flash.

---

## Prerequisites

- `**rkdeveloptool`** installed on the **host** (not inside a build container).
- **USB OTG** cable: **board → host** (recovery / download port per EM3566 v3 silk/markings).
- **Build outputs** present under the kas build tree (paths relative to **repository root** unless noted):
`build/tmp/deploy/images/elevator-hmi-em3566/`

---

## Required files (all in deploy dir)


| File                                                            | Role                                              |
| --------------------------------------------------------------- | ------------------------------------------------- |
| `loader.bin`                                                    | Download-boot (“Maskrom”) helper — `**db`** step  |
| `idblock.img`                                                   | IDBlock @ flash offset **64** sectors             |
| `uboot.img`                                                     | U-Boot @ flash offset **0x4000** sectors          |
| `core-image-minimal-elevator-hmi-em3566.rootfs-<timestamp>.wic` | Full eMMC image (GPT + partitions) @ offset **0** |


A stable symlink `**core-image-minimal-elevator-hmi-em3566.rootfs.wic`** may exist; prefer `**ls -t *.wic`** to pick the newest timestamped file.

---

## Step 1 — Enter Maskrom mode

1. Power **OFF** the board.
2. **Hold** the **RECOVERY** button on EM3566 v3.
3. Plug the **USB OTG** cable (**board → host**).
4. **Release** RECOVERY after ~**2** seconds.
5. Verify on the host:
  ```bash
   lsusb | grep 2207
  ```
  - `**2207:350a**` — **Maskrom** mode (normal for first `**db`**).
  - `**2207:0006`** — **Loader** mode — **skip** the `**db`** step below (see Step 3).

---

## Step 2 — Identify latest WIC

**⚠️ "Latest by file timestamp" is not the same thing as "the recommended/intended build."** This
`ls -t | head -1` trick is a reasonable fallback only when you're deliberately flashing whatever
you personally just finished building in this same session. For any other case — e.g. picking up
where a previous session left off — use the **CURRENT TEST TARGET** section above (or the newest
`diary/SESSION-LOG.md` entry) instead, and verify the SHA-256 against what that log names. This
project's deploy directory routinely accumulates diagnostic-only scratch builds (BIST tests,
register-probe builds) that can have a newer mtime than the actual intended test image — see the
2026-07-03 `diary/SESSION-LOG.md` entry for a concrete example of exactly this happening.

From the **repository root** (or any directory, using an explicit path):

```bash
DEPLOY=build/tmp/deploy/images/elevator-hmi-em3566
WIC=$(ls -t "$DEPLOY"/*.wic | head -1)
echo "Will flash: $WIC"
# Cross-check this against diary/SESSION-LOG.md's current target before trusting it.
```

After `**cd**` into `**$DEPLOY**` (Step 3), resolve again so the name is correct for `**wl**`:

```bash
cd "$DEPLOY"
WIC=$(ls -t *.wic | head -1)
echo "Will flash: $WIC"
```

---

## Step 3 — Flash (run from deploy directory)

```bash
cd build/tmp/deploy/images/elevator-hmi-em3566/
WIC=$(ls -t *.wic | head -1)
```

**Maskrom mode (`2207:350a`):**

```bash
sudo rkdeveloptool db loader.bin
sudo rkdeveloptool wl 0 "$WIC"
sudo rkdeveloptool wl 64 idblock.img
sudo rkdeveloptool wl 0x4000 uboot.img
sudo rkdeveloptool rd
```

**Loader mode (`2207:0006`) — skip `db`:**

```bash
sudo rkdeveloptool wl 0 "$WIC"
sudo rkdeveloptool wl 64 idblock.img
sudo rkdeveloptool wl 0x4000 uboot.img
sudo rkdeveloptool rd
```

**Note:** On some units, `**db`** returns *“The device does not support this operation!”* while the device still shows `**2207:350a`**. `**wl`** may still work — `**db` is not always required** for `**wl 0` (WIC)**; see lab notes in `[diary/PROGRESS.md](../diary/PROGRESS.md)` (2026-04-18 milestone).

---

## Step 4 — Serial console

On the **host** (not inside the container):

```bash
sudo minicom -D /dev/ttyACM0 -b 1500000
```

Settings: **8N1**, **no** hardware flow control, **no** software flow control.

*(If your debug UART enumerates as `**/dev/ttyUSB0`** or uses **115200** baud, match the port/baud from `[docs/BRINGUP-CHECKLIST.md](BRINGUP-CHECKLIST.md)` §4 / vendor docs.)*

---

## Step 5 — Post-flash validation (on board as `root`)

```bash
# Partition layout / labels:
lsblk -f

# Fix GPT backup header mismatch (run once after first flash if kernel warns):
sgdisk -e /dev/mmcblk0

# Display / DRM pipeline (expect defer noise if no panel):
dmesg | egrep -i "iodomain|vccio|vop|dsi|panel|jd9365|drm|defer"

# RAUC:
rauc status
```

---

## Hardware finding — carrier **`VCC3V3_LCD`** load switch (**EM3566 v3 reference**)

**Bench conclusion (**A1**, bring-up closure 2026-05-21):** DTS + kernel (**`TASK-132`** active‑low **`&vcc3v3_lcd0_n`** + **`TASK-133`** **`vcca_1v8`**) are **validated as correct**. **CON1 pin 13** was **~0 V** when enabling the LCD rail (software successfully drives **`GPIO0_C7`** for “ON”). **`VCC3V3_LCD`** (**pins 5/6**) did **not** rise to **~3.3 V** — observed **~0.8 V** on this prototype carrier (**no Panel B** ambiguity for that reading). Responsibility is shifted to **defective / non‑functional carrier load switch analogue hardware**, **not** further Yocto iteration.

**Tomorrow:** **`Plan B`** bypass **`VCC3V3_SYS` → pins 5/6** (**`BLK-013`**) or substitute a known‑good carrier. See **`../diary/BLOCKERS.md`**.

---

## TASK-132 / TASK-133 — Lab protocol (A1): prove the P-FET + stable `vcca_1v8`

**Gate:** Do **not** merge the display-rail task branch to **`develop`** until lab evidence clears **TASK-132** (**`PROGRESS`** / **`AGENTS.md`**). **Carrier hardware bypass** (**`BLK-013`**) is an accepted path when pins **5/6** never reach **3.3 V** despite **`TASK-133`** WIC + **`GPIO0_C7`** **~0 V**.

**Flash / git (2026-05-21):** Build from **`task/TASK-132-vcc3v3-lcd0-active-low-pfet`** (**session wrap-up**) — **`elevator-hmi-boardcon-em3566-v3.dts`** includes **TASK‑132** `&vcc3v3_lcd0_n` (active‑low **`GPIO0_C7`**) plus **TASK‑133** **`/delete-node/ LDO_REG7`** and board **`vcca_1v8`** (omit **TASK‑130**‑style PMIC‑only **`vcca`** on CM3566; those images risk DSI **`-517`** loops).

**Historical:** Separate branch **`task/TASK-133-revert-pmic-fix-pfet`** may match **`HEAD`** after merge; WIC must always bundle this combined DTS.

### Step 1: Build and flash

From repo root on a TASK-002-class host:

```bash
git fetch origin
git checkout task/TASK-132-vcc3v3-lcd0-active-low-pfet
kas shell kas/elevator-hmi.yml -c "bitbake virtual/kernel -c compile -f && bitbake virtual/kernel -c deploy -f"
kas shell kas/elevator-hmi.yml -c "bitbake core-image-minimal -c image_wic -f && bitbake core-image-minimal -c image_complete -f"
```

Flash the resulting **`*.wic`** with **`rkdeveloptool wl 0 …`** per **Step 3** above and **`BOOT` / `UBOOT`** blobs as your image requires.

### Step 2: No-load gate test (critical)

1. **Power off.** Unplug the **LMT101 FPC** from **CON1** (isolate carrier switch from panel faults).
2. Boot and log in.
3. **GPIO:** `grep vcc3v3-lcd0 /sys/kernel/debug/gpio`  
   - **Expected:** `gpio-23` … **`vcc3v3-lcd0-n`** … **`out lo`** (not **`hi`** after TASK-132).
4. **DMM:** **CON1 pin 13** (`LCD_PWREN_H`) to **GND** — **Expected:** **~0 V** (SoC drives gate **low** for **ON**).
5. **DMM:** **CON1 pin 5 or 6** (`VCC3V3_LCD`) to **GND** — **Expected:** **~3.3 V** (P-FET **on**, passing **`VCC3V3_SYS`**).  
   - **Defective reference carrier (**A1 diary**):** If **pins 13 ~0 V** but **5/6 ~0.8 V** (not ~3.3 V) with **`TASK‑133`** WIC, treat as **failed board load switch** — apply **Plan B** bypass (**§ Hardware finding**, **`BLK‑013`**), do **not** iterate Yocto for rail polarity.

### Step 3: Panel bring-up (software path after rails)

1. Power off, connect **LMT101** to **MIPI LCD**, power on.
2. `modetest -M rockchip -c` — note connector id (e.g. **191**).
3. `modetest -M rockchip -s <connector>:#0` (example: **`-s 191:#0`**).
4. `dmesg | grep -i jadard` — expect patch **0009** trace: `reset gpio = gpio-22`, `XRES assert` / `XRES release`, `init table: … cmds, rc=0`, then **`SLPOUT sent`** (0x11 after table), **`DISON sent`** (0x29 after 120 ms); no sustained **`-517`** defer loops.
5. **XRES scope gate (recommended):** dual capture **CON1 pin 11** + **FPC pin 5** during step 3 — **`~20 ms` LOW** on both. Full procedure: **`docs/LMT101-XRES-SCOPE-PROCEDURE.md`**. **libgpiod:** `gpiochip0` **line 22**; **`gpioset` → EBUSY** while driver bound is correct.

### Handoff / failure

| Result | Action |
|--------|--------|
| **Pin 13 ~0 V** and **5–6 ~3.3 V** (switch conducts) | Software rail validated on reference carrier → owner posts evidence → A1 TASK-132 **`[DONE]`** / merge **`develop`** (**`diary/PROGRESS.md`**). |
| **5–6 not ~3.3 V** after **`TASK-133`** WIC + gate above **or carrier bypass deployed** | **`BLK-013`** resolved (**closed 2026-05-21** — **`diary/BLOCKERS.md`:** permanent **`VCC3V3_SYS` → CON1 pins 5/6** bypass; **rail PM deferred** to production carrier). Continue **`modetest`** / **TASK-106**. If panel stays **black** with **~3.3 V** at **5–6**, treat as **DSI / MIPI lanes / `jadard` init** (**TASK-125**) — not residual power‑GPIO mapping. |

**Note (**A1**): With **Plan B**, **Step 2** item **5** may read **~3.3 V** from the jumper even when the FET path is defective; **`TASK-133`** DTS + TASK-132 GPIO checks remain recommended for reproducible images and successor boards.

---

## DTS baseline — `LCD` rail + **`vcca_1v8`** (**TASK-133**)

**CURRENT:** Board DT **`elevator-hmi-boardcon-em3566-v3.dts`**

- **`&vcc3v3_lcd0_n`** (**TASK-132**): **`/delete-property/ enable-active-high`**, **`gpio = <&gpio0 RK_PC7 GPIO_ACTIVE_LOW>`**, **`regulator-always-on`**, **`regulator-boot-on`** — EM3566 v3 **P-FET** gate active-low. **No `vin-supply`** (TASK-131 defer-storm lesson).
- **`&rk809`** / **`vcca_1v8`** (**TASK-133**): **`/delete-node/ LDO_REG7`** + board **`regulator-fixed`** **`vcca_1v8`** @ 1.8 V (CM3566 bring-up — do not rely on non-functional PMIC **LDO_REG7** for DSI PHY / **SARADC**).

**Bench:** **§ TASK-132 / TASK-133 — Lab protocol (A1)** above.

---

## Historical — TASK-129 / TASK-130 narrative

**TASK-129** branch had **`LDO_REG7`** delete + board **`vcca_1v8`** but not the finalized **TASK-132** **`vcc3v3_lcd0_n`** polarity. **TASK-130** briefly restored PMIC **`LDO_REG7`** — **TASK-133** rejects that for CM3566 and merges **TASK-129 PMIC architecture** + **TASK-132 LCD rail**. **Machine + bbappend:** single DTB (**`elevator-hmi-boardcon-em3566-v3.dtb`** on **`/boot`**).

Rebuild **`virtual/kernel`** (and WIC if flashing) **after this revert**, then flash the **new** **`rootfs-<timestamp>.wic`** plus **`idblock.img`** / **`uboot.img`** as in Step 3.

**Historical (do not follow on current tree):** First-pass **TASK-131** WICs with **`vin-supply`** on **`vcc3v3_lcd0_n`** and the **triple-DTB** swap doc caused bench confusion — see **`diary/PROGRESS.md`** / **`AGENTS.md`** TASK-131 archive.

**Lab isolation:** Power **off**, disconnect FPC from **CON1** if you need **CON1 pin 5 → pin 3 (GND)** with no panel load; log the reading next to **`dmesg`** when chasing rail / DRM issues.

---

## Known issues

- `**sudo` blocked inside container** — run `**rkdeveloptool`** from a **host** terminal with USB passthrough as needed.
- `**db`** fails with *does not support* — device may be in **Loader** mode; **skip `db`**, or `**wl**` may still succeed in Maskrom (see Step 3 note).
- **GPT** warning `*6075217 != 15155199`* (or similar backup-header mismatch) — **expected** once; run `**sgdisk -e /dev/mmcblk0`** then reboot.
- `**ttyACM0`: permission denied** — `sudo usermod -aG dialout "$USER"` then **re-login** (or use `sudo minicom`).

---

*Last updated — project doc; offsets align with EM3566 v3 lab validation in `[diary/PROGRESS.md](../diary/PROGRESS.md)`.*