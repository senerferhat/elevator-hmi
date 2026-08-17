# Qt 6.8 + JeffyCN rockchip-libmali: CMake cannot detect EGL/GLESv2/GBM.
#
# rockchip-libmali installs mali-hook *wrappers* as libEGL.so / libGLESv2.so /
# libgbm.so. Those ELF files export ZERO EGL/GLES/GBM symbols — the real ones
# live in libmali.so (43 MB blob). CMake FindEGL/FindGLESv2 then link the
# wrapper; GNU ld --as-needed drops it (no useful symbols); HAVE_EGL and
# HAVE_GLESv2 fail; -DFEATURE_opengles2=ON / -DFEATURE_eglfs=ON abort
# configure ("Forcing to ON breaks its condition").
#
# egl.pc is correct (`-lmali-hook … -lmali`) which is why meson/autotools
# consumers work; CMake's Find* modules ignore pkg-config Libs and search
# by SONAME. Point the find-modules at libmali, which actually defines the
# symbols. Same approach as AGL meta-rockchip-extra's
# "HACK qtbase build using libmali" patch (FindEGL NAMES mali), without
# patching qtbase itself.
#
# Runtime DT_NEEDED becomes libmali.so.1. mali-hook is not on that link
# line; it exists for X11/Wayland eglGetDisplay selection, which this
# distro does not use (EGLFS/GBM only, MALI_PLATFORM=gbm).
#
# class-target only: native qtbase is built with no-opengl.

EXTRA_OECMAKE:append:class-target = " \
    -DEGL_LIBRARY=${STAGING_LIBDIR}/libmali.so \
    -DGLESv2_LIBRARY=${STAGING_LIBDIR}/libmali.so \
    -Dgbm_LIBRARY=${STAGING_LIBDIR}/libmali.so \
"
