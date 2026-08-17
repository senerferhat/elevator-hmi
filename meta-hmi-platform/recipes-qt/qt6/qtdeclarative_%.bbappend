# Target qtdeclarative 6.8.3 was built without Qt Quick:
#   "Qt Quick modules not built due to not finding the qtshadertools 'qsb' tool."
# The recipe already DEPENDS on qtshadertools-native, and qsb is at
# ${RECIPE_SYSROOT_NATIVE}/usr/bin/qsb. Qt's cmake still needs the host
# cmake dir spelled out so find_package(Qt6ShaderToolsTools) resolves
# Qt6::qsb when cross-compiling (QT_HOST_PATH alone was not enough here).
#
# Without Quick, elevator-hmi-app's find_package(Qt6 Quick) fails because
# Qt6QuickConfig.cmake is never installed.

EXTRA_OECMAKE:append:class-target = " \
    -DQT_HOST_PATH_CMAKE_DIR=${RECIPE_SYSROOT_NATIVE}${libdir}/cmake \
"
