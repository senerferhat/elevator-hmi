# Prevent the same Mali CMake hole (HAVE_EGL false → skipped Gui-backed
# build) on qtmultimedia, which is in elevator-hmi-image IMAGE_INSTALL.

require mali-egl-cmake.inc
