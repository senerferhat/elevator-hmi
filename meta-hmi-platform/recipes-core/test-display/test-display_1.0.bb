SUMMARY = "DSI panel modeset smoke script (modetest) for bring-up"
LICENSE = "MIT"
PV = "1.0.3"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

FILESEXTRAPATHS:prepend := "${THISDIR}/../images/files:"

SRC_URI = "file://test-display.sh"
S = "${WORKDIR}"

inherit allarch

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/test-display.sh ${D}${bindir}/test-display
}

FILES:${PN} = "${bindir}/test-display"

RDEPENDS:${PN} = "libdrm-tests util-linux"
