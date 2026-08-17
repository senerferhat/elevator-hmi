# Target qtdeclarative 6.8.3 was built without Qt Quick:
#   "Qt Quick modules not built due to not finding the qtshadertools 'qsb' tool."
# Two stacked causes:
# 1. Same Mali CMake hole as qtbase (HAVE_EGL false) so target qtshadertools
#    shipped an empty package — no Qt6ShaderToolsConfig.cmake in the sysroot.
# 2. qtdeclarative's own HAVE_EGL also fails, and find_package(Qt6ShaderTools)
#    looks at the TARGET sysroot. Without (1) fixed, Quick stays off.
#
# QT_HOST_PATH_CMAKE_DIR helps find Qt6::qsb (host tool);
# mali-egl-cmake.inc makes target qtshadertools / this recipe see EGL.

require mali-egl-cmake.inc

EXTRA_OECMAKE:append:class-target = " \
    -DQT_HOST_PATH_CMAKE_DIR=${RECIPE_SYSROOT_NATIVE}${libdir}/cmake \
"
