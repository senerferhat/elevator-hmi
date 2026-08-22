# Elevator HMI — kernel patches for linux-rockchip (meta-rockchip BSP recipe).
# Applies JD9365DA-H3 panel driver + DT binding backported from Linux v6.2 (TASK-004).
# TASK-110 fixes: cfg fragment replaces KERNEL_CONFIG:append; do_configure copies DTS files.

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://0001-drm-panel-add-jadard-jd9365da-h3-driver-backport-6.1.99.patch"
SRC_URI += "file://0002-drm-panel-jadard-lmt101sx006c-compatible-optional-reset.patch"
SRC_URI += "file://0003-drm-panel-jadard-lmt101sx006c-vendor-init.patch"
SRC_URI += "file://0004-drm-panel-jadard-lmt101-vendor-enable-seq.patch"
SRC_URI += "file://0005-drm-panel-jadard-lmt101sx006c-init-timing.patch"
SRC_URI += "file://0006-drm-panel-jadard-use-generic-write-for-init.patch"
SRC_URI += "file://0007-drm-panel-jadard-lmt101sx006c-reset-powerup-delay.patch"
SRC_URI += "file://0008-drm-panel-jadard-lmt101sx006c-timing-final.patch"
SRC_URI += "file://0009-drm-panel-jadard-lmt101-bringup-trace.patch"
SRC_URI += "file://0010-drm-panel-jadard-lmt101-vendor-q1-dsi-diag.patch"
SRC_URI += "file://0011-drm-panel-jadard-lmt101-fae-bist-clock-seq.patch"
SRC_URI += "file://0014-drm-panel-jadard-lmt101-fae-bist-v2-delay-noburst.patch"
# FAE BUILD B (clock fix) — active in tree; flash …rootfs-fae-clock.wic (vendor Test 1)
# SRC_URI += "file://0012-drm-panel-jadard-lmt101-fae-bist-desc.patch"
SRC_URI += "file://0013-drm-panel-jadard-lmt101-fae-clock-desc.patch"
# DIAG15: DCS read-back 0x04/0x0F/0x45 (post-DISON) — BUILD B extension; stack on 0011+0013
SRC_URI += "file://0015-drm-panel-jadard-lmt101-diag15-dcs-readback.patch"
# TASK-139 H-pkt: init burst DCS framing (revert 0006 generic_write for init only)
SRC_URI += "file://0018-drm-panel-jadard-lmt101-dcs-init.patch"
# TASK-140 VENDOR-CLOCK-MATCH: non-burst -> 420 Mbps (PLL_CLOCK=420) + Q1 20ms XRES low
SRC_URI += "file://0019-drm-panel-jadard-lmt101-vendor-clock-match.patch"
# Vendor TEST 2: arm BIST self-test on top of full FAE_CLOCK init (diagnostic image ONLY).
# E3,01 soft-resets the display engine (our H4a test: 0x0A=0x08) — it sabotages the normal
# video path. ENABLED 2026-07-22 per vendor 7/7 request: dedicated BIST image on the
# clean-reads 468 Mbps base (DIAG15 reads land before BIST arm). DISABLED again 2026-07-23:
# BIST verdict recorded (black, both panels); current build is the INIT-IN-PREPARE video test.
# SRC_URI += "file://0020-drm-panel-jadard-lmt101-fae-clock-bist-arm.patch"
# 0021 INIT-IN-PREPARE (2026-07-23 root-cause candidate): vendor bring-up moved to prepare()
# so it runs in DSI command mode BEFORE video starts (this vendor kernel switches to video
# mode before drm_panel_enable; enable()-time init rides live-video blanking). Kill test in
# docs/FLASH-PROCEDURE.md.
SRC_URI += "file://0021-drm-panel-jadard-lmt101-init-in-prepare.patch"

# BLK-015: replace drivers/gpu/drm/rockchip/ with Boardcon's rkr5 BSP version.
# Measured on target: the driver programs the scanout address AND writes the
# correct VP1 cfg_done latch (0x8002) every frame at 60 Hz, and the hardware
# still never latches. That rules out our DTS and userspace. meta-rockchip pins
# a linux-rockchip that is not this board's BSP; the vendor's vop2 driver is
# 28 KB larger and carries a FIFO-underrun handler, aclk-rate management, an
# iommu fault handler and its own fbdev implementation that we lack entirely.
# Full rationale in the patch header. Panel patches above are unaffected: they
# touch drivers/gpu/drm/panel/.
# BLK-015: replace drivers/gpu/drm/rockchip/ with Boardcon's rkr5 BSP version.
# Measured on target (rockchipdrm debug=9): the driver programs the scanout
# address AND writes the correct VP1 cfg_done (0x8002) every frame at 60 Hz, and
# the hardware still never latches. That rules out our DTS and userspace.
# meta-rockchip pins a linux-rockchip that is not this board's BSP; the vendor's
# vop2 driver is 28 KB larger and carries a FIFO-underrun handler
# (POST_BUF_EMPTY), aclk-rate management, an iommu fault handler and its own
# fbdev implementation that we lack entirely. Full rationale in the patch header.
# Panel patches above are unaffected: they touch drivers/gpu/drm/panel/.
# PARKED — WORK IN PROGRESS, DO NOT ENABLE WITHOUT FINISHING THE PORT.
# The vendor drm/rockchip depends on symbols spread across the vendor kernel:
#   enum rockchip_drm_error_event_type -> include/uapi/drm/rockchip_drm.h  (DONE,
#                                          included in the patch)
#   SYS_STATUS_MULTIVP / SYS_STATUS_SINGLEVP -> include/dt-bindings/soc/
#                                          rockchip-system-status.h        (TODO)
#   ROCKCHIP_VOP2_PHY_ID_INVALID          -> include/dt-bindings/display/   (TODO)
# i.e. this is a different kernel, not a drop-in directory. Enabling it as-is
# fails do_compile. Left parked so the tree stays buildable.
# SRC_URI += "file://0030-drm-rockchip-backport-boardcon-rkr5-bsp.patch"
# 0022 BIST-IN-PREPARE (2026-07-23, diagnostic-only): vendor TEST 2 arm as a one-shot
# test, 2s observation dwell, no return-to-video path. SUPERSEDED 2026-08-07 by 0024
# (master-image two-phase flow). Kept in tree for history; do not re-enable alongside 0024.
# SRC_URI += "file://0022-drm-panel-jadard-lmt101-bist-in-prepare.patch"
# 0023 POWER-DELAY test (2026-08-07): 10ms -> 250ms rail-settle hypothesis. FALSIFIED
# (still black at 25x vendor's stated delay) — not retained. Kept in tree for history.
# SRC_URI += "file://0023-drm-panel-jadard-lmt101-power-delay-250ms.patch"
# 0024 MASTER IMAGE (2026-08-07, owner decision: every boot, always): full BIST
# self-test in command mode (zero video ever sent), then a SECOND independent XRES
# power-cycle + clean re-init before normal video. Required because E3,01 (BIST
# enable) soft-resets the display engine — the second reset is a genuine "reboot the
# LCD", entirely in software, no system reboot involved. Vendor's original 10ms
# power-on delay retained (0023's 250ms was an experiment, not a fix). Supersedes
# 0022 and 0023 — do not enable either alongside this patch.
# DISABLED 2026-08-07 after BLK-014 was RESOLVED. The panel works with 0021 alone
# (proven: white/half framebuffer fills displayed correctly on glass). 0024's BIST
# phase arms E3,01, which leaves the panel degraded even after its second XRES
# reset -- measured 0x0A=0x08 / 0x0F=0x00 vs the healthy 0x1C / 0xC0 seen with
# 0021 alone. BIST also never produced a visible pattern on this panel under any
# condition tested, so it has no diagnostic value here. Do not re-enable for any
# image intended to actually display.
# SRC_URI += "file://0024-drm-panel-jadard-lmt101-master-image-bist-then-video.patch"
# H4a test: ELIMINATED 2026-06-10 — E3,01 causes panel soft-reset (0x0A=0x08), not booster enable
# SRC_URI += "file://0016-drm-panel-jadard-lmt101-h4a-e3-booster-enable.patch"
# FAE BUILD A v2 (BIST + 500ms + no burst): comment 0013, enable 0012+0014
# SRC_URI += "file://0012-drm-panel-jadard-lmt101-fae-bist-desc.patch"
SRC_URI += "file://elevator-hmi-lmt101sx006c-panel.dtsi"
SRC_URI += "file://elevator-hmi-boardcon-em3566-v3.dts"
SRC_URI:append = " file://elevator-hmi-panel.cfg file://elevator-hmi.cfg"

# Copy DTS/DTSI files from WORKDIR into the kernel source tree so the build
# system can resolve KERNEL_DEVICETREE and the #include in the board DTS.
do_configure:append() {
    install -m 0644 ${WORKDIR}/elevator-hmi-lmt101sx006c-panel.dtsi \
        ${S}/arch/arm64/boot/dts/rockchip/
    install -m 0644 ${WORKDIR}/elevator-hmi-boardcon-em3566-v3.dts \
        ${S}/arch/arm64/boot/dts/rockchip/
}
