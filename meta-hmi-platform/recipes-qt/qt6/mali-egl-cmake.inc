# JeffyCN mali-hook wrappers (libEGL.so / libGLESv2.so / libgbm.so) export
# ZERO symbols. The real eglGetDisplay / gl* live in libmali.so (43 MB blob).
# CMake FindEGL/FindGLESv2 link the wrapper; GNU ld --as-needed drops it;
# HAVE_EGL/HAVE_GLESv2 fail. Qt then treats Qt::Gui as missing and skips the
# module (qtshadertools: empty 6 KB RPM; qtdeclarative: "Qt Quick support no").
#
# egl.pc is correct (`-lmali-hook … -lmali`) which is why meson/autotools
# consumers work; CMake's Find* modules ignore pkg-config Libs and search
# by SONAME. Point the find-modules at libmali. Same idea as AGL's
# FindEGL NAMES mali hack, without patching qtbase.
#
# Runtime DT_NEEDED becomes libmali.so.1. mali-hook is not on that link
# line; it exists for X11/Wayland eglGetDisplay selection, which this
# distro does not use (EGLFS/GBM only, MALI_PLATFORM=gbm).
#
# Include from each target Qt recipe bbappend. Do not apply distro-wide:
# unused -D vars warn on unrelated cmake recipes. Native Qt is no-opengl
# and must not get these (class-target only).
#
# Follow-up (not this round): make rockchip-libmali's unversioned
# libEGL.so a real link to libmali so every CMake consumer works without
# per-recipe flags. That invalidates the qtbase sysroot (~20 min).

EXTRA_OECMAKE:append:class-target = " \
    -DEGL_LIBRARY=${STAGING_LIBDIR}/libmali.so \
    -DGLESv2_LIBRARY=${STAGING_LIBDIR}/libmali.so \
    -Dgbm_LIBRARY=${STAGING_LIBDIR}/libmali.so \
"
