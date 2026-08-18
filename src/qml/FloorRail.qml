import QtQuick

// Floor rail + car marker. Used by both portrait and landscape heroes.
// Index 0 is the lowest floor and sits at the BOTTOM of the track.

Item {
    id: rail
    property var hmi
    property bool compact: false

    readonly property var floorNames: hmi ? hmi.floorNames : []
    readonly property var car: hmi ? hmi.car : null
    readonly property color amber: hmi ? hmi.amber : "#E8C84A"
    readonly property color amberHi: hmi ? hmi.amberHi : "#F5E080"
    readonly property color inkDim: hmi ? hmi.inkDim : "#9AA3B2"
    readonly property color inkMute: hmi ? hmi.inkMute : "#5C6573"
    readonly property color line: hmi ? hmi.line : "#262B33"
    readonly property color lineSoft: hmi ? hmi.lineSoft : "#1E232B"
    readonly property string monoFont: hmi ? hmi.monoFont : "Liberation Mono"

    Text {
        x: compact ? 18 : 52
        y: 8
        text: "FLOORS"
        color: rail.inkDim
        font.family: rail.monoFont
        font.pixelSize: 10
        font.letterSpacing: 3
        visible: !rail.compact
    }

    Item {
        id: railBody
        x: 0
        y: rail.compact ? 10 : 32
        width: parent.width
        height: rail.height - y - 12

        readonly property int slots: Math.max(1, rail.floorNames.length)
        readonly property real slotH: height / slots
        readonly property real trackX: rail.width * 0.68

        function yFor(idx) {
            return height - (idx + 0.5) * slotH;
        }

        Rectangle {
            x: railBody.trackX
            y: railBody.slotH / 2
            width: 1
            height: railBody.height - railBody.slotH
            color: rail.line
        }

        Rectangle {
            x: railBody.trackX - 1
            width: 3
            color: rail.amber
            opacity: 0.85
            visible: rail.car && rail.car.direction !== 0
            y: rail.car ? Math.min(railBody.yFor(rail.car.currentIndex), railBody.yFor(rail.car.destIndex)) : 0
            height: rail.car ? Math.abs(railBody.yFor(rail.car.destIndex) - railBody.yFor(rail.car.currentIndex)) : 0
            Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        }

        Repeater {
            model: rail.floorNames.length
            delegate: Item {
                id: floorSlot
                required property int index
                readonly property bool isCurrent: rail.car && index === rail.car.currentIndex
                width: rail.width
                height: railBody.slotH
                y: railBody.height - (index + 1) * railBody.slotH

                Text {
                    x: railBody.trackX - 40
                    width: 26
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    text: rail.floorNames[floorSlot.index]
                    color: floorSlot.isCurrent ? rail.amber : rail.inkMute
                    font.family: rail.monoFont
                    font.pixelSize: floorSlot.isCurrent ? 14 : 12
                    font.bold: floorSlot.isCurrent
                }
                Rectangle {
                    x: railBody.trackX - 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: floorSlot.isCurrent ? 16 : 10
                    height: 1
                    color: floorSlot.isCurrent ? rail.amber : rail.line
                }
            }
        }

        Item {
            id: marker
            x: railBody.trackX + 1
            y: rail.car ? railBody.yFor(rail.car.currentIndex) : 0
            Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

            Repeater {
                model: [
                    { d: 30, a: 0.10 },
                    { d: 22, a: 0.18 },
                    { d: 15, a: 0.35 }
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: modelData.d
                    height: modelData.d
                    radius: modelData.d / 2
                    x: -width / 2
                    y: -height / 2
                    color: rail.amber
                    opacity: modelData.a
                }
            }
            Rectangle {
                width: 11; height: 11; radius: 6
                x: -width / 2
                y: -height / 2
                color: rail.amberHi
            }
        }
    }

    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: rail.lineSoft
    }
}
