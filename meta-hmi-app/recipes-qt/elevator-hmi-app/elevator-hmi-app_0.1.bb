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

DEPENDS = "qtbase qtdeclarative qtdeclarative-native"

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
           file://main.qml \
           file://elevator-hmi.init \
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
}

RDEPENDS:${PN} += " \
    qtdeclarative \
    qtdeclarative-qmlplugins \
    qtbase-plugins \
    initscripts \
"
