import QtQuick

// Design: Elevator HMI Vertical.html + Vertical Video.html — 800×1280.
// `hmi` is the Window (tokens, car, clock, activity log).

Item {
    id: view
    required property var hmi

    readonly property bool videoMode: hmi.videoMode
    readonly property var car: hmi.car

    Repeater {
        model: [
            { hx: 0, hy: 0 }, { hx: 1, hy: 0 },
            { hx: 0, hy: 1 }, { hx: 1, hy: 1 }
        ]
        delegate: Item {
            id: corner
            required property var modelData
            z: 100
            width: 22
            height: 22
            x: modelData.hx === 0 ? 10 : view.width - width - 10
            y: modelData.hy === 0 ? 10 : view.height - height - 10

            Rectangle {
                width: parent.width
                height: 1
                color: view.hmi.line
                x: 0
                y: corner.modelData.hy === 0 ? 0 : corner.height - 1
            }
            Rectangle {
                width: 1
                height: parent.height
                color: view.hmi.line
                y: 0
                x: corner.modelData.hx === 0 ? 0 : corner.width - 1
            }
        }
    }

    Column {
        id: page
        anchors.fill: parent
        anchors.topMargin: 16
        anchors.bottomMargin: 10
        spacing: 0

        VideoPane {
            width: parent.width
            height: view.videoMode ? 600 : 0
            visible: view.videoMode
            hmi: view.hmi
        }

        Item {
            width: parent.width
            height: 60

            Row {
                x: 22
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: view.hmi.green
                    anchors.verticalCenter: parent.verticalCenter
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 1400; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1.0; duration: 1400; easing.type: Easing.InOutQuad }
                    }
                }
                Text {
                    text: "CAR"
                    color: view.hmi.inkDim
                    font.family: view.hmi.monoFont
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: view.car.carId
                    color: view.hmi.ink
                    font.family: view.hmi.monoFont
                    font.pixelSize: 13
                    font.letterSpacing: 3
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "·"
                    color: view.hmi.inkMute
                    font.pixelSize: 13
                    visible: !view.videoMode
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: view.car.building
                    color: view.hmi.inkDim
                    font.family: view.hmi.monoFont
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    visible: !view.videoMode
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    text: view.hmi.clockHM
                    color: view.hmi.ink
                    font.family: view.hmi.monoFont
                    font.pixelSize: 30
                    font.bold: true
                    anchors.bottom: parent.bottom
                }
                Text {
                    text: ":" + view.hmi.clockSec
                    color: view.hmi.inkDim
                    font.family: view.hmi.monoFont
                    font.pixelSize: 17
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                }
                Text {
                    text: view.hmi.clockDate
                    color: view.hmi.inkMute
                    font.family: view.hmi.monoFont
                    font.pixelSize: 10
                    font.letterSpacing: 2
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 5
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: view.hmi.lineSoft
            }
        }

        Item {
            width: parent.width
            height: view.videoMode ? 0 : 52
            visible: !view.videoMode

            Row {
                anchors.centerIn: parent
                spacing: 12

                Text {
                    text: "MODE"
                    color: view.hmi.inkDim
                    font.family: view.hmi.monoFont
                    font.pixelSize: 12
                    font.letterSpacing: 3
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    width: modeText.implicitWidth + 34
                    height: 30
                    color: "transparent"
                    border.color: view.hmi.line
                    border.width: 1
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        id: modeText
                        anchors.centerIn: parent
                        text: view.car.mode
                        color: view.hmi.accent
                        font.family: view.hmi.monoFont
                        font.pixelSize: 12
                        font.letterSpacing: 3
                    }
                }
                Text {
                    text: "·"
                    color: view.hmi.inkMute
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "NEXT"
                    color: view.hmi.inkDim
                    font.family: view.hmi.monoFont
                    font.pixelSize: 12
                    font.letterSpacing: 3
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    width: 46
                    height: 30
                    color: "transparent"
                    border.color: view.hmi.line
                    border.width: 1
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: view.car.direction === 0 ? "—" : view.hmi.floorNames[view.car.destIndex]
                        color: view.hmi.amber
                        font.family: view.hmi.monoFont
                        font.pixelSize: 12
                        font.letterSpacing: 2
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: view.hmi.lineSoft
            }
        }

        Item {
            id: hero
            width: parent.width
            height: view.videoMode ? 296 : 556

            FloorRail {
                id: rail
                width: 190
                height: parent.height
                hmi: view.hmi
                compact: view.videoMode
            }

            Item {
                anchors.left: rail.right
                anchors.right: parent.right
                height: parent.height

                Text {
                    id: heroLabel
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: view.videoMode ? 10 : 44
                    text: "CURRENT FLOOR"
                    color: view.hmi.inkDim
                    font.family: view.hmi.monoFont
                    font.pixelSize: 13
                    font.letterSpacing: 5
                }

                Text {
                    id: heroNum
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: heroLabel.bottom
                    anchors.topMargin: view.videoMode ? -6 : 4
                    text: view.hmi.floorNames[view.car.currentIndex]
                    color: view.hmi.accent
                    font.family: view.hmi.monoFont
                    font.pixelSize: view.videoMode ? 116 : 200
                    font.bold: true
                    onTextChanged: floorPop.restart()
                    SequentialAnimation {
                        id: floorPop
                        NumberAnimation { target: heroNum; property: "scale"; to: 0.86; duration: 110 }
                        NumberAnimation { target: heroNum; property: "scale"; to: 1.0; duration: 200; easing.type: Easing.OutBack }
                    }
                }

                DirectionArrows {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: heroNum.bottom
                    anchors.topMargin: view.videoMode ? 0 : 16
                    hmi: view.hmi
                    arrowSize: view.videoMode ? 74 : 112
                    spacing: view.videoMode ? 40 : 70
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: view.hmi.lineSoft
            }
        }

        Item {
            width: parent.width
            height: 50

            Row {
                anchors.centerIn: parent
                spacing: 44

                Row {
                    spacing: 10
                    Text {
                        text: "DEST"
                        color: view.hmi.inkDim
                        font.family: view.hmi.monoFont
                        font.pixelSize: 12
                        font.letterSpacing: 3
                    }
                    Text {
                        text: view.car.direction === 0 ? "—" : view.hmi.floorNames[view.car.destIndex]
                        color: view.hmi.ink
                        font.family: view.hmi.monoFont
                        font.pixelSize: 13
                        font.bold: true
                    }
                }
                Row {
                    spacing: 10
                    Text {
                        text: "SPEED"
                        color: view.hmi.inkDim
                        font.family: view.hmi.monoFont
                        font.pixelSize: 12
                        font.letterSpacing: 3
                    }
                    Text {
                        text: view.car.speedMs.toFixed(1) + " M/S"
                        color: view.hmi.ink
                        font.family: view.hmi.monoFont
                        font.pixelSize: 13
                        font.bold: true
                    }
                }
                Row {
                    spacing: 10
                    Text {
                        text: "ETA"
                        color: view.hmi.inkDim
                        font.family: view.hmi.monoFont
                        font.pixelSize: 12
                        font.letterSpacing: 3
                    }
                    Text {
                        text: "00:" + (view.car.etaSec < 10 ? "0" + view.car.etaSec : view.car.etaSec)
                        color: view.hmi.ink
                        font.family: view.hmi.monoFont
                        font.pixelSize: 13
                        font.bold: true
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: view.hmi.lineSoft
            }
        }

        Row {
            width: parent.width
            height: 196
            spacing: 0

            Card {
                width: parent.width / 2
                height: parent.height
                title: "DOOR"
                badge: view.car.doorPhase === "CLOSED" ? "LATCHED" : view.car.doorPhase
                badgeColor: view.car.doorPhase === "OPEN" ? view.hmi.green : view.hmi.inkDim

                Item {
                    anchors.fill: parent

                    Item {
                        id: doorGfx
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        width: 120
                        height: 74

                        readonly property real openFrac: view.car.doorPhase === "OPEN" ? 1.0
                                                       : view.car.doorPhase === "OPENING" ? 0.6
                                                       : view.car.doorPhase === "CLOSING" ? 0.35 : 0.0
                        Behavior on openFrac { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 26
                            height: parent.height
                            color: "transparent"
                            border.color: view.hmi.line
                            border.width: 1
                            Rectangle {
                                anchors.centerIn: parent
                                width: 2
                                height: parent.height - 18
                                color: view.hmi.teal
                            }
                        }

                        Rectangle {
                            width: 26
                            height: parent.height
                            color: view.hmi.teal
                            x: doorGfx.width / 2 - 16 - width - doorGfx.openFrac * 24
                        }
                        Rectangle {
                            width: 26
                            height: parent.height
                            color: view.hmi.teal
                            x: doorGfx.width / 2 + 16 + doorGfx.openFrac * 24
                        }
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        spacing: 10

                        Rectangle {
                            width: 8; height: 8; radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: view.car.doorPhase === "OPEN" ? view.hmi.green : view.hmi.amber
                        }
                        Text {
                            text: view.car.doorPhase
                            color: view.hmi.ink
                            font.family: view.hmi.monoFont
                            font.pixelSize: 13
                            font.bold: true
                            font.letterSpacing: 2
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        text: "—"
                        color: view.hmi.inkMute
                        font.family: view.hmi.monoFont
                        font.pixelSize: 13
                    }
                }
            }

            Card {
                width: parent.width / 2
                height: parent.height
                title: "LOAD"
                badge: view.car.loadPercent > 90 ? "OVERLOAD" : view.car.loadPercent > 70 ? "HIGH" : "NOMINAL"
                badgeColor: view.car.loadPercent > 90 ? view.hmi.red : view.car.loadPercent > 70 ? view.hmi.amber : view.hmi.inkDim

                Item {
                    anchors.fill: parent

                    Row {
                        id: loadReadout
                        spacing: 4
                        Text {
                            text: view.car.loadPercent
                            color: view.hmi.ink
                            font.family: view.hmi.monoFont
                            font.pixelSize: 32
                            font.bold: true
                        }
                        Text {
                            text: "%"
                            color: view.hmi.inkMute
                            font.family: view.hmi.monoFont
                            font.pixelSize: 13
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 5
                        }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: loadReadout.verticalCenter
                        text: view.car.loadKg + " / " + view.car.capacityKg + " KG"
                        color: view.hmi.inkDim
                        font.family: view.hmi.monoFont
                        font.pixelSize: 12
                    }

                    Row {
                        id: loadBar
                        anchors.top: loadReadout.bottom
                        anchors.topMargin: 24
                        width: parent.width
                        height: 18
                        spacing: 2

                        Repeater {
                            model: 10
                            delegate: Rectangle {
                                id: seg
                                required property int index
                                width: (loadBar.width - 9 * 2) / 10
                                height: loadBar.height
                                readonly property bool on: view.car.loadPercent > index * 10
                                color: seg.on ? (view.car.loadPercent > 90 ? view.hmi.red
                                                : view.car.loadPercent > 70 ? view.hmi.amber : view.hmi.green)
                                              : view.hmi.bgElev2
                                Behavior on color { ColorAnimation { duration: 220 } }
                            }
                        }
                    }

                    Item {
                        id: loadScale
                        anchors.top: loadBar.bottom
                        anchors.topMargin: 6
                        width: parent.width
                        height: 14

                        Repeater {
                            model: [
                                { t: "0", f: 0.0 }, { t: "25", f: 0.25 },
                                { t: "50", f: 0.5 }, { t: "75", f: 0.75 },
                                { t: "100%", f: 1.0 }
                            ]
                            delegate: Text {
                                id: tick
                                required property var modelData
                                text: modelData.t
                                color: modelData.f === 1.0 ? view.hmi.red : view.hmi.inkMute
                                font.family: view.hmi.monoFont
                                font.pixelSize: 9
                                x: tick.modelData.f * (loadScale.width - tick.width)
                            }
                        }
                    }
                }
            }
        }

        Row {
            width: parent.width
            height: view.videoMode ? 0 : 190
            visible: !view.videoMode
            spacing: 0

            Card {
                width: parent.width / 2
                height: parent.height
                title: "DIAGNOSTICS"
                badge: "SYSTEM"

                Grid {
                    anchors.fill: parent
                    columns: 2
                    rowSpacing: 16
                    columnSpacing: 22

                    Stat { label: "MOTOR TEMP"; value: "42"; unit: "°C"; valueColor: view.hmi.amber }
                    Stat { label: "BRAKE"; value: view.car.moving ? "RELEASED" : "HELD"; valueColor: view.hmi.amber }
                    Stat { label: "HOIST"; value: "8.4"; unit: "kN" }
                    Stat { label: "DRIVE"; value: (view.car.speedMs * 20).toFixed(1); unit: "Hz" }
                    Stat { label: "POSITION"; value: "+" + (view.car.currentIndex * 3.2).toFixed(2); unit: "m" }
                    Stat { label: "ENCODER"; value: "SYNC"; valueColor: view.hmi.amber }
                }
            }

            Card {
                id: serviceCard
                width: parent.width / 2
                height: parent.height
                title: "SERVICE"
                badge: "OK"
                badgeColor: view.hmi.green

                Column {
                    id: serviceCol
                    anchors.fill: parent
                    spacing: 2

                    InfoRow { width: serviceCol.width; label: "TRIPS TODAY"; value: "247" }
                    InfoRow { width: serviceCol.width; label: "LAST SERVICE"; value: "14 Apr 2026" }
                    InfoRow { width: serviceCol.width; label: "NEXT INSPECTION"; value: "12 May 2026"; valueColor: view.hmi.amber }
                    InfoRow { width: serviceCol.width; label: "CYCLES"; value: "1.84M" }
                }
            }
        }

        Card {
            width: parent.width
            height: view.videoMode ? 0 : 112
            visible: !view.videoMode
            title: "ACTIVITY"
            badge: "LOG"

            Column {
                anchors.fill: parent
                spacing: 3

                Repeater {
                    model: view.hmi.activityModel
                    delegate: Row {
                        id: logRow
                        required property string stamp
                        required property string floor
                        required property string what
                        spacing: 20

                        Text {
                            text: logRow.stamp
                            color: view.hmi.inkMute
                            font.family: view.hmi.monoFont
                            font.pixelSize: 11
                        }
                        Text {
                            text: logRow.floor
                            color: view.hmi.accent
                            font.family: view.hmi.monoFont
                            font.pixelSize: 11
                            font.bold: true
                            width: 22
                        }
                        Text {
                            text: logRow.what
                            color: view.hmi.inkDim
                            font.family: view.hmi.monoFont
                            font.pixelSize: 11
                            font.letterSpacing: 1
                        }
                    }
                }
            }
        }
    }
}
