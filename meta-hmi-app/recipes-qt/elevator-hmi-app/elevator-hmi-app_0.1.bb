# Elevator HMI Qt 6 / QML application.
#
# QML sources are NOT kept here: per CLAUDE.md §8 ("All QML files in src/qml/,
# mirrored in meta-hmi-app recipe") the canonical UI lives in the repo's
# top-level src/qml/, exposed to this recipe by ELEVATOR_HMI_QML_DIR from
# meta-hmi-app/conf/layer.conf. C++/CMake/init glue stays in files/.

SUMMARY = "Elevator HMI Qt 6 / QML application (car display)"
LICENSE = "CLOSED"
LIC_FILES_CHKSUM = "file://COPYING;md5=6efe49454b90c8ab6739746e8eab1771"

inherit qt6-cmake update-rc.d

# src/qml first so the canonical UI sources win, then the recipe's own files/.
FILESEXTRAPATHS:prepend := "${ELEVATOR_HMI_QML_DIR}:"
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

DEPENDS = "qtbase qtdeclarative qtdeclarative-native qtmultimedia"

# Same Mali CMake hole as qtbase (see meta-hmi-platform qtbase_%.bbappend):
# JeffyCN mali-hook wrappers export no EGL/GLES symbols, so find_package(Qt6 Gui)
# fails ("dependency GLESv2 could not be found") even though Qt6GuiConfig.cmake
# is in the sysroot. Point FindEGL/FindGLESv2 at libmali.
EXTRA_OECMAKE:append = " \
    -DEGL_LIBRARY=${STAGING_LIBDIR}/libmali.so \
    -DGLESv2_LIBRARY=${STAGING_LIBDIR}/libmali.so \
    -Dgbm_LIBRARY=${STAGING_LIBDIR}/libmali.so \
"

SRC_URI = "file://CMakeLists.txt \
           file://main.cpp \
           file://MediaBackend.h \
           file://MediaBackend.cpp \
           file://VideoSurface.h \
           file://VideoSurface.cpp \
           file://main.qml \
           file://PortraitView.qml \
           file://LandscapeView.qml \
           file://FloorRail.qml \
           file://VideoPane.qml \
           file://DirectionArrows.qml \
           file://Card.qml \
           file://Stat.qml \
           file://InfoRow.qml \
           file://elevator-hmi.init \
           file://hmi \
           file://sdcard-mount \
           file://99-sdcard.rules \
           file://COPYING \
           "

S = "${WORKDIR}"

# sysvinit autostart. This distro is sysvinit (poky default, INIT_MANAGER
# unset), so there is no .service unit; the init script exports the Qt
# environment itself because /etc/environment.d is inert here and
# /etc/profile.d only covers login shells.
INITSCRIPT_NAME = "elevator-hmi"
# Runlevel 5 only: start after the normal multi-user bring-up.
INITSCRIPT_PARAMS = "defaults 99 01"

do_install:append() {
    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${WORKDIR}/elevator-hmi.init ${D}${sysconfdir}/init.d/elevator-hmi
    install -d ${D}${bindir} ${D}${sbindir}
    install -m 0755 ${WORKDIR}/hmi ${D}${bindir}/hmi
    install -m 0755 ${WORKDIR}/sdcard-mount ${D}${sbindir}/sdcard-mount
    install -d ${D}${sysconfdir}/udev/rules.d
    install -m 0644 ${WORKDIR}/99-sdcard.rules ${D}${sysconfdir}/udev/rules.d/99-sdcard.rules
}

# CMake installs the QML tree to ${datadir}/elevator-hmi (see CMakeLists.txt
# and main.cpp, which loads /usr/share/elevator-hmi/main.qml). Poky's default
# FILES:${PN} is bindir/libdir/sysconfdir only, so do_package QA fails with
# installed-vs-shipped unless this directory is listed.
FILES:${PN} += "${datadir}/elevator-hmi"

RDEPENDS:${PN} += " \
    qtdeclarative \
    qtdeclarative-qmlplugins \
    qtbase-plugins \
    initscripts \
    udev \
    dosfstools \
    qtmultimedia \
    qtmultimedia-plugins \
"

# Runtime decode path for the SD video demo. There is NO H.264 decoder in this
# image: gstreamer1.0-libav is LICENSE_FLAGS="commercial" and installing it is a
# licensing decision for the product owner, not a build detail. jpegdec is in
# plugins-good and is already here, so demo clips must be MJPEG. See
# docs/FLASH-PROCEDURE.md for the exact ffmpeg command.
RDEPENDS:${PN} += " \
    gstreamer1.0-plugins-good-jpeg \
    gstreamer1.0-plugins-good-isomp4 \
    gstreamer1.0-plugins-good-avi \
    gstreamer1.0-plugins-good-matroska \
    gstreamer1.0-plugins-base-videoconvertscale \
"
