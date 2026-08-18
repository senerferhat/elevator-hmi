import QtQuick

// Design: Elevator HMI.html (1280×800) and Elevator HMI Landscape Video.html.
// Rendered in a 1280×800 stage; main.qml rotates that stage 90°/270° onto the
// panel's native 800×1280 framebuffer (linuxfb, BLK-015).

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

    // ---- Landscape + video: left video, right compact HMI (640 | 640) ----
    Row {
        anchors.fill: parent
        visible: view.videoMode
        spacing: 0

        VideoPane {
            width: parent.width / 2
            height: parent.height
            hmi: view.hmi
        }

        Item {
            id: compactHmi
            width: parent.width / 2
            height: parent.height

            Item {
                id: compactBar
                width: parent.width
                height: 56

                Row {
                    x: 18
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Rectangle {
                        width: 7; height: 7; radius: 4
                        color: view.hmi.green
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "CAR"
                        color: view.hmi.inkDim
                        font.family: view.hmi.monoFont
                        font.pixelSize: 11
                        font.letterSpacing: 2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: view.car.carId
                        color: view.hmi.ink
                        font.family: view.hmi.monoFont
                        font.pixelSize: 11
                        font.letterSpacing: 2
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text {
                        text: view.hmi.clockHM
                        color: view.hmi.ink
                        font.family: view.hmi.monoFont
                        font.pixelSize: 22
                        font.bold: true
                    }
                    Text {
                        text: ":" + view.hmi.clockSec
                        color: view.hmi.inkDim
                        font.family: view.hmi.monoFont
                        font.pixelSize: 14
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
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
                id: compactHero
                anchors.top: compactBar.bottom
                width: parent.width
                height: 330

                FloorRail {
                    id: compactRail
                    width: 120
                    height: parent.height
                    hmi: view.hmi
                    compact: true
                }

                Item {
                    anchors.left: compactRail.right
                    anchors.right: parent.right
                    height: parent.height

                    Text {
                        id: compactLabel
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 12
                        text: "CURRENT FLOOR"
                        color: view.hmi.inkDim
                        font.family: view.hmi.monoFont
                        font.pixelSize: 11
                        font.letterSpacing: 4
                    }
                    Text {
                        id: compactNum
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: compactLabel.bottom
                        anchors.topMargin: -4
                        text: view.hmi.floorNames[view.car.currentIndex]
                        color: view.hmi.accent
                        font.family: view.hmi.monoFont
                        font.pixelSize: 140
                        font.bold: true
                        onTextChanged: compactPop.restart()
                        SequentialAnimation {
                            id: compactPop
                            NumberAnimation { target: compactNum; property: "scale"; to: 0.86; duration: 110 }
                            NumberAnimation { target: compactNum; property: "scale"; to: 1.0; duration: 200; easing.type: Easing.OutBack }
                        }
                    }
                    DirectionArrows {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: compactNum.bottom
                        anchors.topMargin: -8
                        hmi: view.hmi
                        arrowSize: 56
                        spacing: 28
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
                id: compactSub
                anchors.top: compactHero.bottom
                width: parent.width
                height: 38
                Row {
                    anchors.centerIn: parent
                    spacing: 22
                    Row {
                        spacing: 6
                        Text { text: "DEST"; color: view.hmi.inkMute; font.family: view.hmi.monoFont; font.pixelSize: 11; font.letterSpacing: 2 }
                        Text {
                            text: view.car.direction === 0 ? "—" : view.hmi.floorNames[view.car.destIndex]
                            color: view.hmi.amber
                            font.family: view.hmi.monoFont
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                    Row {
                        spacing: 6
                        Text { text: "SPEED"; color: view.hmi.inkMute; font.family: view.hmi.monoFont; font.pixelSize: 11; font.letterSpacing: 2 }
                        Text {
                            text: view.car.speedMs.toFixed(1) + " M/S"
                            color: view.hmi.ink
                            font.family: view.hmi.monoFont
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                    Row {
                        spacing: 6
                        Text { text: "ETA"; color: view.hmi.inkMute; font.family: view.hmi.monoFont; font.pixelSize: 11; font.letterSpacing: 2 }
                        Text {
                            text: "00:" + (view.car.etaSec < 10 ? "0" + view.car.etaSec : view.car.etaSec)
                            color: view.hmi.ink
                            font.family: view.hmi.monoFont
                            font.pixelSize: 11
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
                id: compactMid
                anchors.top: compactSub.bottom
                width: parent.width
                height: 140
                spacing: 0

                Card {
                    width: parent.width / 2
                    height: parent.height
                    title: "DOOR"
                    badge: view.car.doorPhase === "CLOSED" ? "LATCHED" : view.car.doorPhase
                    badgeColor: view.car.doorPhase === "OPEN" ? view.hmi.green : view.hmi.inkDim

                    Item {
                        anchors.fill: parent
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            spacing: 8
                            Rectangle {
                                width: view.car.doorPhase === "CLOSED" ? 20 : 6
                                height: 42
                                color: view.hmi.teal
                                Behavior on width { NumberAnimation { duration: 400 } }
                            }
                            Rectangle {
                                width: 22
                                height: 42
                                color: "transparent"
                                border.color: view.hmi.line
                                border.width: 1
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 2
                                    height: 20
                                    color: view.hmi.line
                                }
                            }
                            Rectangle {
                                width: view.car.doorPhase === "CLOSED" ? 20 : 6
                                height: 42
                                color: view.hmi.teal
                                Behavior on width { NumberAnimation { duration: 400 } }
                            }
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            text: view.car.doorPhase
                            color: view.hmi.ink
                            font.family: view.hmi.monoFont
                            font.pixelSize: 11
                            font.letterSpacing: 2
                        }
                    }
                }

                Card {
                    width: parent.width / 2
                    height: parent.height
                    title: "LOAD"
                    badge: view.car.loadPercent > 90 ? "OVERLOAD" : "NOMINAL"
                    badgeColor: view.car.loadPercent > 90 ? view.hmi.red : view.hmi.inkDim

                    Item {
                        anchors.fill: parent
                        Row {
                            spacing: 4
                            Text {
                                text: view.car.loadPercent
                                color: view.hmi.ink
                                font.family: view.hmi.monoFont
                                font.pixelSize: 24
                                font.bold: true
                            }
                            Text {
                                text: "%"
                                color: view.hmi.inkMute
                                font.family: view.hmi.monoFont
                                font.pixelSize: 12
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 3
                            }
                        }
                        Rectangle {
                            id: compactLoadBar
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 18
                            width: parent.width
                            height: 14
                            color: view.hmi.bgElev2
                            border.color: view.hmi.line
                            border.width: 1
                            Rectangle {
                                width: parent.width * view.car.loadPercent / 100
                                height: parent.height
                                color: view.car.loadPercent > 90 ? view.hmi.red : view.hmi.amber
                            }
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            text: view.car.loadKg + " / " + view.car.capacityKg + " KG"
                            color: view.hmi.inkDim
                            font.family: view.hmi.monoFont
                            font.pixelSize: 10
                        }
                    }
                }
            }

            Row {
                anchors.top: compactMid.bottom
                anchors.bottom: parent.bottom
                width: parent.width
                spacing: 0

                Card {
                    width: parent.width * 0.38
                    height: parent.height
                    title: "DIAGNOSTICS"
                    badge: "SYS"
                    Grid {
                        anchors.fill: parent
                        columns: 2
                        rowSpacing: 6
                        columnSpacing: 10
                        Stat { label: "MOTOR"; value: "42"; unit: "°C"; valueColor: view.hmi.amber }
                        Stat { label: "BRAKE"; value: view.car.moving ? "REL" : "HELD"; valueColor: view.hmi.amber }
                        Stat { label: "HOIST"; value: "8.4"; unit: "kN" }
                        Stat { label: "ENC"; value: "SYNC"; valueColor: view.hmi.amber }
                    }
                }
                Card {
                    width: parent.width * 0.32
                    height: parent.height
                    title: "ACTIVITY"
                    badge: "LOG"
                    Column {
                        anchors.fill: parent
                        spacing: 2
                        Repeater {
                            model: view.hmi.activityModel
                            delegate: Row {
                                required property string stamp
                                required property string floor
                                required property string what
                                spacing: 8
                                Text {
                                    text: stamp
                                    color: view.hmi.inkMute
                                    font.family: view.hmi.monoFont
                                    font.pixelSize: 9
                                }
                                Text {
                                    text: floor
                                    color: view.hmi.accent
                                    font.family: view.hmi.monoFont
                                    font.pixelSize: 9
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
                Card {
                    width: parent.width * 0.30
                    height: parent.height
                    title: "SERVICE"
                    badge: "OK"
                    badgeColor: view.hmi.green
                    Column {
                        anchors.fill: parent
                        spacing: 2
                        InfoRow { width: parent.width; label: "TRIPS"; value: "247" }
                        InfoRow { width: parent.width; label: "CYCLES"; value: "1.84M" }
                    }
                }
            }
        }
    }

    // ---- Full landscape 1280×800 (no video) --------------------------------
    Item {
        id: full
        anchors.fill: parent
        visible: !view.videoMode

        Item {
            id: topBar
            width: parent.width
            height: 72

            Row {
                x: 32
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14
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
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: view.car.building
                    color: view.hmi.inkDim
                    font.family: view.hmi.monoFont
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 10
                Text {
                    text: "MODE"
                    color: view.hmi.inkDim
                    font.family: view.hmi.monoFont
                    font.pixelSize: 12
                    font.letterSpacing: 3
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    width: fullModeText.implicitWidth + 24
                    height: 28
                    color: "transparent"
                    border.color: view.hmi.line
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        id: fullModeText
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
                    width: 48
                    height: 28
                    color: "transparent"
                    border.color: view.hmi.line
                    border.width: 1
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

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 32
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Text {
                    text: view.hmi.clockHM
                    color: view.hmi.ink
                    font.family: view.hmi.monoFont
                    font.pixelSize: 32
                    font.bold: true
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: ":" + view.hmi.clockSec
                        color: view.hmi.inkDim
                        font.family: view.hmi.monoFont
                        font.pixelSize: 14
                    }
                    Text {
                        text: view.hmi.clockDate
                        color: view.hmi.inkMute
                        font.family: view.hmi.monoFont
                        font.pixelSize: 10
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
            id: dock
            anchors.bottom: parent.bottom
            width: parent.width
            height: 200

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: view.hmi.lineSoft
            }

            Row {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                Card {
                    width: (parent.width - 32) * 0.38
                    height: parent.height
                    title: "DIAGNOSTICS"
                    badge: "SYSTEM"
                    Grid {
                        anchors.fill: parent
                        columns: 2
                        rowSpacing: 10
                        columnSpacing: 18
                        Stat { label: "MOTOR TEMP"; value: "42"; unit: "°C"; valueColor: view.hmi.amber }
                        Stat { label: "BRAKE"; value: view.car.moving ? "RELEASED" : "HELD"; valueColor: view.hmi.amber }
                        Stat { label: "HOIST"; value: "8.4"; unit: "kN" }
                        Stat { label: "DRIVE"; value: (view.car.speedMs * 20).toFixed(1); unit: "Hz" }
                        Stat { label: "POSITION"; value: "+" + (view.car.currentIndex * 3.2).toFixed(2); unit: "m" }
                        Stat { label: "ENCODER"; value: "SYNC"; valueColor: view.hmi.amber }
                    }
                }
                Card {
                    width: (parent.width - 32) * 0.34
                    height: parent.height
                    title: "ACTIVITY"
                    badge: "LOG"
                    Column {
                        anchors.fill: parent
                        spacing: 4
                        Repeater {
                            model: view.hmi.activityModel
                            delegate: Row {
                                required property string stamp
                                required property string floor
                                required property string what
                                spacing: 14
                                Text {
                                    text: stamp
                                    color: view.hmi.inkMute
                                    font.family: view.hmi.monoFont
                                    font.pixelSize: 11
                                }
                                Text {
                                    text: floor
                                    color: view.hmi.accent
                                    font.family: view.hmi.monoFont
                                    font.pixelSize: 11
                                    font.bold: true
                                    width: 22
                                }
                                Text {
                                    text: what
                                    color: view.hmi.inkDim
                                    font.family: view.hmi.monoFont
                                    font.pixelSize: 11
                                    font.letterSpacing: 1
                                }
                            }
                        }
                    }
                }
                Card {
                    width: (parent.width - 32) * 0.28
                    height: parent.height
                    title: "SERVICE"
                    badge: "OK"
                    badgeColor: view.hmi.green
                    Column {
                        anchors.fill: parent
                        spacing: 2
                        InfoRow { width: parent.width; label: "TRIPS TODAY"; value: "247" }
                        InfoRow { width: parent.width; label: "LAST SERVICE"; value: "14 Apr 2026" }
                        InfoRow { width: parent.width; label: "NEXT INSPECTION"; value: "12 May 2026"; valueColor: view.hmi.amber }
                        InfoRow { width: parent.width; label: "CYCLES"; value: "1.84M" }
                    }
                }
            }
        }

        FloorRail {
            id: fullRail
            anchors.top: topBar.bottom
            anchors.bottom: dock.top
            width: 140
            hmi: view.hmi
            compact: false
        }

        Item {
            id: rightPanel
            anchors.top: topBar.bottom
            anchors.bottom: dock.top
            anchors.right: parent.right
            width: 380

            Rectangle {
                anchors.left: parent.left
                width: 1
                height: parent.height
                color: view.hmi.lineSoft
            }

            Column {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                Card {
                    width: parent.width
                    height: (parent.height - 14) * 0.58
                    title: "DOOR"
                    badge: view.car.doorPhase === "CLOSED" ? "LATCHED" : view.car.doorPhase
                    badgeColor: view.car.doorPhase === "OPEN" ? view.hmi.green : view.hmi.inkDim

                    Item {
                        anchors.fill: parent

                        Item {
                            id: doorStage
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: parent.height - 28
                            clip: true

                            property real openFrac: view.car.doorPhase === "OPEN" ? 0.95
                                                  : view.car.doorPhase === "OPENING" ? 0.55
                                                  : view.car.doorPhase === "CLOSING" ? 0.30 : 0.0
                            Behavior on openFrac { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }

                            Rectangle {
                                anchors.fill: parent
                                color: "#FFFFFF"
                                border.color: view.hmi.lineSoft
                                border.width: 1
                            }

                            Row {
                                anchors.top: parent.top
                                width: parent.width
                                height: 8
                                Repeater {
                                    model: 32
                                    delegate: Rectangle {
                                        required property int index
                                        width: doorStage.width / 32
                                        height: 8
                                        color: index % 2 === 0 ? view.hmi.teal : "#FFFFFF"
                                    }
                                }
                            }
                            Row {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 8
                                Repeater {
                                    model: 32
                                    delegate: Rectangle {
                                        required property int index
                                        width: doorStage.width / 32
                                        height: 8
                                        color: index % 2 === 0 ? view.hmi.teal : "#FFFFFF"
                                    }
                                }
                            }

                            Rectangle {
                                x: -doorStage.openFrac * (doorStage.width * 0.48)
                                y: 8
                                width: doorStage.width / 2
                                height: doorStage.height - 16
                                color: view.hmi.teal
                                border.color: view.hmi.line
                                border.width: 1
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 2
                                    height: parent.height * 0.6
                                    color: view.hmi.teal
                                }
                            }
                            Rectangle {
                                x: doorStage.width / 2 + doorStage.openFrac * (doorStage.width * 0.48)
                                y: 8
                                width: doorStage.width / 2
                                height: doorStage.height - 16
                                color: view.hmi.teal
                                border.color: view.hmi.line
                                border.width: 1
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 2
                                    height: parent.height * 0.6
                                    color: view.hmi.teal
                                }
                            }
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            spacing: 8
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: view.car.doorPhase === "OPEN" ? view.hmi.green : view.hmi.amber
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: view.car.doorPhase
                                color: view.hmi.ink
                                font.family: view.hmi.monoFont
                                font.pixelSize: 12
                                font.letterSpacing: 2
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                Card {
                    width: parent.width
                    height: (parent.height - 14) * 0.42
                    title: "LOAD"
                    badge: view.car.loadPercent > 90 ? "OVERLOAD" : view.car.loadPercent > 70 ? "HIGH" : "NOMINAL"
                    badgeColor: view.car.loadPercent > 90 ? view.hmi.red : view.car.loadPercent > 70 ? view.hmi.amber : view.hmi.inkDim

                    Item {
                        anchors.fill: parent
                        Row {
                            id: fullLoadReadout
                            spacing: 4
                            Text {
                                text: view.car.loadPercent
                                color: view.hmi.ink
                                font.family: view.hmi.monoFont
                                font.pixelSize: 36
                                font.bold: true
                            }
                            Text {
                                text: "%"
                                color: view.hmi.inkMute
                                font.family: view.hmi.monoFont
                                font.pixelSize: 14
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 6
                            }
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: fullLoadReadout.verticalCenter
                            text: view.car.loadKg + " / " + view.car.capacityKg + " KG"
                            color: view.hmi.inkDim
                            font.family: view.hmi.monoFont
                            font.pixelSize: 12
                        }
                        Rectangle {
                            id: fullLoadBar
                            anchors.top: fullLoadReadout.bottom
                            anchors.topMargin: 16
                            width: parent.width
                            height: 18
                            color: view.hmi.bgElev2
                            border.color: view.hmi.line
                            border.width: 1
                            Rectangle {
                                width: parent.width * view.car.loadPercent / 100
                                height: parent.height
                                color: view.car.loadPercent > 90 ? view.hmi.red
                                     : view.car.loadPercent > 70 ? view.hmi.amber : view.hmi.green
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: fullHero
            anchors.top: topBar.bottom
            anchors.bottom: dock.top
            anchors.left: fullRail.right
            anchors.right: rightPanel.left

            Text {
                id: fullHeroLabel
                anchors.horizontalCenter: parent.horizontalCenter
                y: 28
                text: "CURRENT FLOOR"
                color: view.hmi.inkDim
                font.family: view.hmi.monoFont
                font.pixelSize: 13
                font.letterSpacing: 5
            }

            Text {
                id: fullHeroNum
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: fullHeroLabel.bottom
                anchors.topMargin: -8
                text: view.hmi.floorNames[view.car.currentIndex]
                color: view.hmi.accent
                font.family: view.hmi.monoFont
                font.pixelSize: 220
                font.bold: true
                onTextChanged: fullPop.restart()
                SequentialAnimation {
                    id: fullPop
                    NumberAnimation { target: fullHeroNum; property: "scale"; to: 0.86; duration: 110 }
                    NumberAnimation { target: fullHeroNum; property: "scale"; to: 1.0; duration: 200; easing.type: Easing.OutBack }
                }
            }

            DirectionArrows {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: fullHeroNum.bottom
                anchors.topMargin: -12
                hmi: view.hmi
                arrowSize: 72
                spacing: 48
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                spacing: 36
                Row {
                    spacing: 8
                    Text { text: "DEST"; color: view.hmi.inkMute; font.family: view.hmi.monoFont; font.pixelSize: 12; font.letterSpacing: 3 }
                    Text {
                        text: view.car.direction === 0 ? "—" : view.hmi.floorNames[view.car.destIndex]
                        color: view.hmi.amber
                        font.family: view.hmi.monoFont
                        font.pixelSize: 13
                        font.bold: true
                    }
                }
                Row {
                    spacing: 8
                    Text { text: "SPEED"; color: view.hmi.inkMute; font.family: view.hmi.monoFont; font.pixelSize: 12; font.letterSpacing: 3 }
                    Text {
                        text: view.car.speedMs.toFixed(1) + " M/S"
                        color: view.hmi.ink
                        font.family: view.hmi.monoFont
                        font.pixelSize: 13
                        font.bold: true
                    }
                }
                Row {
                    spacing: 8
                    Text { text: "ETA"; color: view.hmi.inkMute; font.family: view.hmi.monoFont; font.pixelSize: 12; font.letterSpacing: 3 }
                    Text {
                        text: "00:" + (view.car.etaSec < 10 ? "0" + view.car.etaSec : view.car.etaSec)
                        color: view.hmi.ink
                        font.family: view.hmi.monoFont
                        font.pixelSize: 13
                        font.bold: true
                    }
                }
            }
        }
    }
}
