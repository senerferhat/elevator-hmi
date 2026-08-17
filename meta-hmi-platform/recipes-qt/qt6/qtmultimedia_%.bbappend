# Mali CMake hole (HAVE_EGL false → skipped Gui-backed build) plus a
# feature this 2D HMI does not want.
#
# meta-qt6 defaults PACKAGECONFIG to spatialaudio_quick3d, which forces
# -DFEATURE_spatialaudio_quick3d=ON and DEPENDS on qtquick3d. We do not
# ship Quick3D (elevator floor UI is Qt Quick 2D). Configure then dies:
#   Feature "spatialaudio_quick3d": Forcing to ON breaks its condition
#   TARGET Qt::Quick3D not found
# Keep gstreamer/qml/spatialaudio. Drop only the Quick3D spatial backend.

require mali-egl-cmake.inc

PACKAGECONFIG:remove = "spatialaudio_quick3d"
