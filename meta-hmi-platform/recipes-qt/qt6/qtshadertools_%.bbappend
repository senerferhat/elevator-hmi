# Target qtshadertools was an empty RPM: HAVE_EGL failed (mali-hook wrappers),
# so cmake skipped the build ("condition TARGET Qt::Gui is not met").
# qtdeclarative then cannot find Qt6ShaderTools and skips Qt Quick.

require mali-egl-cmake.inc
