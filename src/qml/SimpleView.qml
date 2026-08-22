import QtQuick

// Media-first layouts: the video is the point, the HMI is reduced to what a
// passenger actually needs mid-ride — the floor number and the direction.
//
//   showStrip = true   narrow info strip aside, video fills the rest
//   showStrip = false  fullscreen video, no strip at all
//
// Both are used portrait (800x1280) and landscape (1280x800, rotated onto the
// panel by main.qml). Landscape gives by far the most usable picture for 16:9
// source: the video well is then ~1000x800 or the full 1280x800.
//
// The pane runs in cinema mode: letterbox, not crop, and no status chrome.
// Cropping a 16:9 clip into a portrait well would discard most of the frame.
//
// Software-renderer safe (BLK-015 / linuxfb): no shaders, no layers.

Item {
    id: view
    required property var hmi
    property bool showStrip: true

    readonly property var car: view.hmi.car
    // Wide enough for a legible floor number, never so wide it eats the video.
    readonly property int stripW: view.showStrip
        ? Math.round(Math.min(320, Math.max(180, view.width * 0.24)))
        : 0

    // Black ground: letterbox bars must not show the theme colour.
    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    Rectangle {
        id: strip
        width: view.stripW
        height: parent.height
        visible: view.showStrip
        color: view.hmi.bg

        Rectangle {
            anchors.right: parent.right
            width: 1
            height: parent.height
            color: view.hmi.line
        }

        Column {
            anchors.centerIn: parent
            width: parent.width
            spacing: Math.round(view.stripW * 0.10)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "FLOOR"
                color: view.hmi.inkDim
                font.family: view.hmi.monoFont
                font.pixelSize: Math.round(view.stripW * 0.10)
                font.letterSpacing: 4
            }

            Text {
                id: floorNum
                anchors.horizontalCenter: parent.horizontalCenter
                text: view.hmi.floorNames[view.car.currentIndex]
                color: view.hmi.accent
                font.family: view.hmi.monoFont
                font.pixelSize: Math.round(view.stripW * 0.62)
                font.bold: true

                // Scale pop on arrival. NOT a `Behavior on text`: a Behavior
                // intercepts the assignment and expects its animation to produce
                // the new value, so animating `scale` there would swallow the
                // text update entirely.
                onTextChanged: floorPop.restart()
                SequentialAnimation {
                    id: floorPop
                    NumberAnimation { target: floorNum; property: "scale"; to: 0.84; duration: 110 }
                    NumberAnimation { target: floorNum; property: "scale"; to: 1.0; duration: 210; easing.type: Easing.OutBack }
                }
            }

            DirectionArrows {
                anchors.horizontalCenter: parent.horizontalCenter
                hmi: view.hmi
                arrowSize: Math.round(view.stripW * 0.30)
                spacing: Math.round(view.stripW * 0.12)
            }
        }
    }

    VideoPane {
        x: view.stripW
        width: parent.width - view.stripW
        height: parent.height
        hmi: view.hmi
        fitMedia: true
        showChrome: false
    }
}
