SUMMARY = "Elevator HMI Qt 6.8 / EGLFS image"
LICENSE = "CLOSED"
LIC_FILES_CHKSUM = "file://${THISDIR}/files/COPYING;md5=7e5e5df5b9771d704cbe2cd44fcd17b6"

inherit core-image rockchip-image

WKS_FILE = "${ELEVATOR_HMI_EMMC_WKS}"
IMAGE_OVERHEAD_FACTOR = "1.1"

# ---------------------------------------------------------------------------
# Rockchip WIC build fixes — ported from
# meta-hmi-platform/recipes-core/images/core-image-minimal.bbappend (TASK-103).
# Without these, any image inheriting rockchip-image FAILS to build here.
# ---------------------------------------------------------------------------

# rockchip-image do_fixup_wks greps for file=*.img references. grep exits 1 on
# zero matches and `set -e` in the task script then kills the task. Our WKS uses
# --source keywords only (no file=*.img lines), so that grep always returns 1.
# No-op it rather than modifying the read-only community layer.
do_fixup_wks() {
    :
}

# do_image_wic_ufs builds a UFS 4K-sector variant. This product is eMMC
# (mmcblk0), not UFS. No-op it.
do_image_wic_ufs() {
    :
}

# rauc pulls upstream rauc-conf (example system.conf) as a weak dependency; it
# conflicts with our elevator-hmi-rauc-system-conf.
BAD_RECOMMENDATIONS += "rauc-conf"

# TASK-109 lists packagegroup-qt6-minimal; meta-qt6 6.8 LTS provides packagegroup-qt6-essentials
# as the minimal qtbase+declarative (+tools) set instead.
IMAGE_INSTALL += " \
    packagegroup-qt6-essentials \
    qtbase \
    qtdeclarative \
    qtmultimedia \
    gstreamer1.0 \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    elevator-hmi-app \
"

# Parity with the proven bring-up image (core-image-minimal.bbappend) so this
# image is a drop-in replacement in the lab: RAUC A/B, partition tooling, and
# the DRM/GPIO diagnostics we actually used to bring the panel up. All are
# already in sstate from prior builds, so they cost little build time.
IMAGE_INSTALL += " \
    rauc \
    elevator-hmi-rauc-system-conf \
    gptfdisk \
    libdrm-tests \
    util-linux \
    libgpiod \
    libgpiod-tools \
"

# No X11, no Wayland, no display manager — EGLFS only.
# DISTRO_FEATURES x11/wayland already removed in meta-hmi-platform/conf/distro/elevator-hmi.conf (TASK-108).
# Do not repeat DISTRO_FEATURES:remove here — it cannot be reliably modified in an image recipe.

ROOTFS_POSTPROCESS_COMMAND:append = "elevator_hmi_qt_eglfs_env;"

elevator_hmi_qt_eglfs_env() {
    install -d ${IMAGE_ROOTFS}${sysconfdir}/profile.d
    printf '%s\n' 'export QT_QPA_PLATFORM=eglfs' > ${IMAGE_ROOTFS}${sysconfdir}/profile.d/qt-eglfs.sh
    chmod 0755 ${IMAGE_ROOTFS}${sysconfdir}/profile.d/qt-eglfs.sh

    # NOTE (2026-08-07): /etc/environment.d is a **systemd** mechanism and this
    # distro currently runs **sysvinit** (poky.conf default; INIT_MANAGER is not
    # set anywhere in meta-hmi-platform/conf or build/conf). This file is
    # therefore INERT today — the effective setting is the profile.d export
    # above, which applies to login shells. It is kept so the environment is
    # already correct if/when INIT_MANAGER is switched to systemd (see CLAUDE.md
    # §8, which assumes systemd for PAL and the watchdog, and AGENTS TASK-116).
    # Anything auto-starting the app must set QT_QPA_PLATFORM itself.
    install -d ${IMAGE_ROOTFS}${sysconfdir}/environment.d
    printf '%s\n' 'QT_QPA_PLATFORM=eglfs' > ${IMAGE_ROOTFS}${sysconfdir}/environment.d/90-qt-eglfs.conf
    chmod 0644 ${IMAGE_ROOTFS}${sysconfdir}/environment.d/90-qt-eglfs.conf
}
