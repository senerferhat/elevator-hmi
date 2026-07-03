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
# DISARMED for the production/vendor-match image: vendor (13 Jun) states BIST is a separate
# diagnostic, and E3,01 soft-resets the display engine (our H4a test: 0x0A=0x08) — it sabotages
# the normal video path. Re-enable only to build a dedicated BIST self-test image.
# SRC_URI += "file://0020-drm-panel-jadard-lmt101-fae-clock-bist-arm.patch"
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
