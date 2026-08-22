cmake_minimum_required(VERSION 3.16)
project(elevator-hmi LANGUAGES CXX)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Multimedia)

qt_standard_project_setup()

add_executable(elevator-hmi
    main.cpp
    MediaBackend.cpp
    MediaBackend.h
    VideoSurface.cpp
    VideoSurface.h
)
target_link_libraries(elevator-hmi PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::Multimedia
)

install(TARGETS elevator-hmi RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES
    main.qml
    PortraitView.qml
    LandscapeView.qml
    FloorRail.qml
    VideoPane.qml
    SimpleView.qml
    DirectionArrows.qml
    Card.qml
    Stat.qml
    InfoRow.qml
    DESTINATION ${CMAKE_INSTALL_DATADIR}/elevator-hmi)
