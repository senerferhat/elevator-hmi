# TASK-103: Rockchip BSP image outputs (ext4 + WIC + postprocess) for RK3566 bring-up.
inherit rockchip-image

WKS_FILE = "${ELEVATOR_HMI_EMMC_WKS}"
IMAGE_OVERHEAD_FACTOR = "1.1"

IMAGE_INSTALL:append = " rauc elevator-hmi-rauc-system-conf gptfdisk libdrm-tests util-linux test-display libgpiod libgpiod-tools"

# Prevent rauc-conf (upstream example system.conf) from being pulled in as a
# weak dependency of rauc — it conflicts with our elevator-hmi-rauc-system-conf.
BAD_RECOMMENDATIONS += "rauc-conf"

# rockchip-image do_fixup_wks uses grep to find file=*.img references.
# grep exits 1 on zero matches; set -e in the run script kills the task.
# Our WKS uses --source keywords only — no file=*.img lines — so the
# grep always returns 1. Override to no-op without modifying meta-rockchip.
do_fixup_wks() {
    :
}

# do_image_wic_ufs creates a UFS 4K-sector image variant from rockchip-image.
# This project uses eMMC (mmcblk0), not UFS. Disable to no-op.
do_image_wic_ufs() {
    :
}
