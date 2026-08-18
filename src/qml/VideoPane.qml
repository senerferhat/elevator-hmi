import QtQuick

// Empty video placeholder (design: Vertical Video / Landscape Video).
// SD-card playback is a later task; BLK-015 also blocks GStreamer/DRM video.
// Software-renderer safe: hatch is rotated Rectangles, not a shader.

Item {
    id: pane
    property var hmi
    clip: true

    readonly property color ink: hmi ? hmi.ink : "#E8ECF2"
    readonly property color inkMute: hmi ? hmi.inkMute : "#5C6573"
    readonly property color inkDim: hmi ? hmi.inkDim : "#9AA3B2"
    readonly property color red: hmi ? hmi.red : "#E85A4A"
    readonly property color line: hmi ? hmi.line : "#262B33"
    readonly property string monoFont: hmi ? hmi.monoFont : "Liberation Mono"

    Rectangle {
        anchors.fill: parent
        color: "#0B0D10"

        Item {
            anchors.fill: parent
            clip: true
            Repeater {
                model: 46
                delegate: Rectangle {
                    required property int index
                    width: 2
                    height: pane.height * 3
                    color: "#12151A"
                    x: index * 34 - 320
                    y: -pane.height
                    rotation: 30
                    transformOrigin: Item.TopLeft
                }
            }
        }

        Row {
            x: 20
            y: 18
            spacing: 8
            Rectangle {
                width: 8; height: 8; radius: 4
                color: pane.red
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "LIVE  ·  CH 04"
                color: pane.ink
                font.family: pane.monoFont
                font.pixelSize: 12
                font.letterSpacing: 2
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 20
            y: 18
            text: "SAFETY · 720P"
            color: pane.inkMute
            font.family: pane.monoFont
            font.pixelSize: 11
            font.letterSpacing: 2
        }

        Column {
            anchors.centerIn: parent
            spacing: 16

            Rectangle {
                width: 96; height: 96; radius: 48
                color: "transparent"
                border.color: pane.line
                border.width: 1
                anchors.horizontalCenter: parent.horizontalCenter

                Canvas {
                    anchors.centerIn: parent
                    width: 34; height: 38
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.fillStyle = pane.inkMute;
                        ctx.beginPath();
                        ctx.moveTo(4, 2);
                        ctx.lineTo(width - 2, height / 2);
                        ctx.lineTo(4, height - 2);
                        ctx.closePath();
                        ctx.fill();
                    }
                }
            }
            Text {
                text: "NO SOURCE"
                color: pane.inkDim
                font.family: pane.monoFont
                font.pixelSize: 15
                font.letterSpacing: 4
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "SD CARD · EMPTY"
                color: pane.inkMute
                font.family: pane.monoFont
                font.pixelSize: 11
                font.letterSpacing: 2
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        Row {
            x: 20
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            spacing: 12

            Repeater {
                model: ["PLAY", "UNMUTE"]
                delegate: Rectangle {
                    id: transportBtn
                    required property string modelData
                    width: 96; height: 40
                    color: "transparent"
                    border.color: pane.line
                    border.width: 1
                    radius: 2
                    Text {
                        anchors.centerIn: parent
                        text: transportBtn.modelData
                        color: pane.ink
                        font.family: pane.monoFont
                        font.pixelSize: 12
                        font.letterSpacing: 2
                    }
                }
            }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 30
            text: "—  NO CLIP LOADED  —"
            color: pane.inkMute
            font.family: pane.monoFont
            font.pixelSize: 11
            font.letterSpacing: 2
        }
    }
}
