// ElevatorHMI.qml
// Qt 6.5 / QtQuick.Controls 2  —  1280x800 10" LCD elevator HMI
// No QtWidgets. Touch-only: cursor hidden, all targets >= 60 px.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

ApplicationWindow {
    id: root
    width: 1280
    height: 800
    visible: true
    visibility: Window.FullScreen
    title: "Elevator HMI"
    color: "#0E1013"

    // Hide the mouse cursor globally
    Component.onCompleted: {
        root.cursor = Qt.BlankCursor
    }

    // ---------- Design tokens ----------
    readonly property color bg:        "#0E1013"
    readonly property color bgElev:    "#15181D"
    readonly property color bgElev2:   "#1C2028"
    readonly property color line:      "#262B33"
    readonly property color lineSoft:  "#1E232B"
    readonly property color ink:       "#E8ECF2"
    readonly property color inkDim:    "#8A93A2"
    readonly property color inkMute:   "#4E5663"
    readonly property color amber:     "#E8C84A"
    readonly property color amberDim:  "#6B5A1F"
    readonly property color red:       "#E85A4A"
    readonly property color green:     "#5AE89A"

    readonly property string monoFont: "JetBrains Mono"
    readonly property string uiFont:   "Inter"

    // ---------- State model ----------
    QtObject {
        id: carState
        property int    currentFloor: 12
        property int    destinationFloor: 14
        property string direction: "UP"            // "UP" | "DOWN" | "IDLE"
        property int    loadPercent: 64            // 0..100
        property int    loadKg: 1024
        property int    capacityKg: 1600
        property string doorPhase: "OPEN"          // CLOSED | OPENING | OPEN | CLOSING
        property int    doorHoldSec: 3
        property real   speedMs: 1.8
        property int    etaSec: 6
        property var    activeCalls: [14, 17, 20]
        property var    servedCalls: [9, 10, 11]
        property string mode: "NORMAL SERVICE"
        property string carId: "A-04"
    }

    // ---------- Live clock ----------
    property string clockTime: ""
    property string clockDate: ""
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date();
            var pad = function(n){ return n < 10 ? "0"+n : ""+n; };
            clockTime = pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":" + pad(d.getSeconds());
            var days   = ["SUN","MON","TUE","WED","THU","FRI","SAT"];
            var months = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"];
            clockDate = days[d.getDay()] + " · " + pad(d.getDate()) + " " +
                        months[d.getMonth()] + " " + d.getFullYear();
        }
    }

    // =====================================================
    // TOP BAR
    // =====================================================
    Rectangle {
        id: topBar
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 72
        color: "transparent"
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: lineSoft }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 32
            anchors.rightMargin: 32
            spacing: 24

            // Brand / car id
            RowLayout {
                spacing: 14
                Rectangle { width: 8; height: 8; radius: 4; color: green }
                Text { text: "CAR"; color: inkDim; font.family: monoFont; font.pixelSize: 13; font.letterSpacing: 2 }
                Text { text: carState.carId; color: ink; font.family: monoFont; font.pixelSize: 13; font.letterSpacing: 3; font.bold: true }
                Text { text: "·"; color: inkMute; font.pixelSize: 13 }
                Text { text: "TOWER NORTH"; color: inkDim; font.family: monoFont; font.pixelSize: 13; font.letterSpacing: 2 }
            }

            Item { Layout.fillWidth: true }

            // Status
            RowLayout {
                spacing: 10
                Text { text: "MODE"; color: inkDim; font.family: monoFont; font.pixelSize: 12; font.letterSpacing: 3 }
                Rectangle {
                    border.color: line; border.width: 1; color: "transparent"
                    implicitHeight: 28; implicitWidth: modeText.implicitWidth + 24
                    Text { id: modeText; anchors.centerIn: parent; text: carState.mode
                           color: amber; font.family: monoFont; font.pixelSize: 12; font.letterSpacing: 3 }
                }
                Text { text: "·"; color: inkMute }
                Text { text: "NEXT"; color: inkDim; font.family: monoFont; font.pixelSize: 12; font.letterSpacing: 3 }
                Rectangle {
                    border.color: line; border.width: 1; color: "transparent"
                    implicitHeight: 28; implicitWidth: nextText.implicitWidth + 24
                    Text { id: nextText; anchors.centerIn: parent; text: carState.destinationFloor
                           color: amber; font.family: monoFont; font.pixelSize: 12; font.letterSpacing: 3 }
                }
            }

            Item { Layout.fillWidth: true }

            // Clock
            ColumnLayout {
                spacing: 2
                Text { text: clockTime; color: ink; font.family: monoFont; font.pixelSize: 30
                       font.letterSpacing: 1; Layout.alignment: Qt.AlignRight }
                Text { text: clockDate; color: inkDim; font.family: monoFont; font.pixelSize: 11
                       font.letterSpacing: 3; Layout.alignment: Qt.AlignRight }
            }
        }
    }

    // =====================================================
    // LEFT FLOOR RAIL
    // =====================================================
    Rectangle {
        id: rail
        anchors { top: topBar.bottom; bottom: dock.top; left: parent.left }
        width: 132
        color: "transparent"
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: lineSoft }

        Text {
            id: railHeader
            text: "FLOORS"
            anchors.top: parent.top; anchors.topMargin: 18
            anchors.left: parent.left; anchors.leftMargin: 24
            color: inkMute; font.family: monoFont; font.pixelSize: 10; font.letterSpacing: 3
        }

        // vertical progress line
        Rectangle {
            x: 80; y: railHeader.y + railHeader.height + 12
            width: 2; height: parent.height - 56
            color: line
            Rectangle {
                width: parent.width; height: parent.height * 0.56
                color: amber
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: amber }
                }
            }
        }

        ListView {
            anchors.top: railHeader.bottom; anchors.topMargin: 12
            anchors.left: parent.left; anchors.leftMargin: 24
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            interactive: false
            spacing: 0
            model: {
                // floors 17 down to 7, centered on current
                var list = [];
                for (var i = 17; i >= 7; --i) list.push(i);
                return list;
            }
            delegate: Item {
                width: rail.width - 24
                height: 56
                property bool isCurrent: modelData === carState.currentFloor
                property bool isCall:    carState.activeCalls.indexOf(modelData) !== -1
                property bool isServed:  carState.servedCalls.indexOf(modelData) !== -1

                Text {
                    id: numText
                    text: modelData
                    x: 0; width: 40
                    horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: monoFont; font.pixelSize: 16
                    font.bold: isCurrent
                    color: isCurrent ? amber : (isCall ? ink : (isServed ? inkDim : inkMute))
                }
                Rectangle {
                    x: 54; anchors.verticalCenter: parent.verticalCenter
                    width: isCurrent ? 16 : 10
                    height: isCurrent ? 4 : 2
                    color: isCurrent ? amber : (isServed ? amberDim : (isCall ? ink : inkMute))
                }
                Rectangle {
                    visible: isCurrent
                    x: 76; anchors.verticalCenter: parent.verticalCenter
                    width: 14; height: 14; radius: 7
                    color: amber
                    // simple pulse halo
                    Rectangle { anchors.centerIn: parent; width: 22; height: 22; radius: 11
                                color: "transparent"; border.color: amber; border.width: 2; opacity: 0.35 }
                }
                Rectangle {
                    visible: isCall && !isCurrent
                    x: 76; anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: callTxt.implicitWidth + 10; implicitHeight: 16
                    border.color: line; border.width: 1; color: "transparent"
                    Text { id: callTxt; anchors.centerIn: parent; text: "CALL"
                           color: inkDim; font.family: monoFont; font.pixelSize: 9; font.letterSpacing: 2 }
                }
            }
        }
    }

    // =====================================================
    // HERO CURRENT FLOOR
    // =====================================================
    Item {
        id: hero
        anchors { top: topBar.bottom; bottom: dock.top; left: rail.right; right: rightPanel.left }

        Text {
            id: heroLabel
            text: "CURRENT FLOOR"
            anchors.top: parent.top; anchors.topMargin: 36
            anchors.horizontalCenter: parent.horizontalCenter
            color: inkMute; font.family: monoFont; font.pixelSize: 12; font.letterSpacing: 4
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 32

            // Down arrow
            Item {
                Layout.preferredWidth: 72; Layout.preferredHeight: 72
                opacity: carState.direction === "DOWN" ? 1.0 : 0.35
                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d"); ctx.reset();
                        ctx.fillStyle = carState.direction === "DOWN" ? amber : inkMute;
                        ctx.beginPath();
                        var w = width, h = height;
                        ctx.moveTo(w*0.5, h*0.9);
                        ctx.lineTo(w*0.1, h*0.4);
                        ctx.lineTo(w*0.3, h*0.4);
                        ctx.lineTo(w*0.3, h*0.1);
                        ctx.lineTo(w*0.7, h*0.1);
                        ctx.lineTo(w*0.7, h*0.4);
                        ctx.lineTo(w*0.9, h*0.4);
                        ctx.closePath();
                        ctx.fill();
                    }
                }
            }

            // Giant floor number
            Text {
                text: carState.currentFloor
                color: amber
                font.family: monoFont
                font.pixelSize: 360
                font.weight: Font.Medium
                font.letterSpacing: -10
                style: Text.Normal
                // glow via layer effect
                layer.enabled: true
            }

            // Up arrow
            Item {
                Layout.preferredWidth: 72; Layout.preferredHeight: 72
                opacity: carState.direction === "UP" ? 1.0 : 0.35
                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d"); ctx.reset();
                        ctx.fillStyle = carState.direction === "UP" ? amber : inkMute;
                        ctx.beginPath();
                        var w = width, h = height;
                        ctx.moveTo(w*0.5, h*0.1);
                        ctx.lineTo(w*0.9, h*0.6);
                        ctx.lineTo(w*0.7, h*0.6);
                        ctx.lineTo(w*0.7, h*0.9);
                        ctx.lineTo(w*0.3, h*0.9);
                        ctx.lineTo(w*0.3, h*0.6);
                        ctx.lineTo(w*0.1, h*0.6);
                        ctx.closePath();
                        ctx.fill();
                    }
                }
            }
        }

        RowLayout {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 36
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 36
            Row {
                spacing: 8
                Text { text: "DEST";  color: inkMute; font.family: monoFont; font.pixelSize: 13; font.letterSpacing: 3 }
                Text { text: carState.destinationFloor; color: amber; font.family: monoFont; font.pixelSize: 13; font.letterSpacing: 3; font.bold: true }
            }
            Row {
                spacing: 8
                Text { text: "SPEED"; color: inkMute; font.family: monoFont; font.pixelSize: 13; font.letterSpacing: 3 }
                Text { text: carState.speedMs.toFixed(1) + " m/s"; color: ink; font.family: monoFont; font.pixelSize: 13; font.letterSpacing: 3 }
            }
            Row {
                spacing: 8
                Text { text: "ETA"; color: inkMute; font.family: monoFont; font.pixelSize: 13; font.letterSpacing: 3 }
                Text { text: "00:" + (carState.etaSec < 10 ? "0"+carState.etaSec : carState.etaSec)
                       color: ink; font.family: monoFont; font.pixelSize: 13; font.letterSpacing: 3 }
            }
        }
    }

    // =====================================================
    // RIGHT PANEL: Door + Load
    // =====================================================
    Rectangle {
        id: rightPanel
        anchors { top: topBar.bottom; bottom: dock.top; right: parent.right }
        width: 380
        color: "transparent"
        Rectangle { anchors.left: parent.left; width: 1; height: parent.height; color: lineSoft }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 24

            // ---- Door card ----
            Rectangle {
                Layout.fillWidth: true
                color: bgElev
                border.color: line; border.width: 1
                implicitHeight: 300

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    RowLayout {
                        Text { text: "DOOR"; color: inkMute; font.family: monoFont; font.pixelSize: 11; font.letterSpacing: 3 }
                        Item { Layout.fillWidth: true }
                        Text { text: carState.doorPhase; color: amber; font.family: monoFont; font.pixelSize: 11; font.letterSpacing: 3 }
                    }

                    // Door stage
                    Rectangle {
                        id: doorStage
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        color: "#0A0C10"
                        border.color: lineSoft; border.width: 1
                        clip: true

                        // interior glow
                        Rectangle {
                            anchors.fill: parent; anchors.margins: 10
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#0E1116" }
                                GradientStop { position: 1.0; color: "#07080B" }
                            }
                        }

                        // safety stripes (top & bottom)
                        Row {
                            id: stripesTop
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            height: 10; spacing: 0
                            Repeater {
                                model: 40
                                Rectangle { width: doorStage.width / 40; height: 10
                                            color: (index % 2 === 0) ? amber : "#000" }
                            }
                        }
                        Row {
                            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                            height: 10; spacing: 0
                            Repeater {
                                model: 40
                                Rectangle { width: doorStage.width / 40; height: 10
                                            color: (index % 2 === 0) ? amber : "#000" }
                            }
                        }

                        // Animated door panels
                        property real openAmount: 0.0   // 0 = closed, 1 = open

                        Rectangle {
                            id: doorLeft
                            x: -doorStage.openAmount * (doorStage.width * 0.48)
                            y: 10
                            width: doorStage.width / 2
                            height: doorStage.height - 20
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#20252E" }
                                GradientStop { position: 1.0; color: "#171A20" }
                            }
                            border.color: "#2A2F38"; border.width: 1
                            Rectangle { anchors.right: parent.right; anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 2; height: parent.height * 0.6; color: amberDim }
                        }
                        Rectangle {
                            id: doorRight
                            x: doorStage.width / 2 + doorStage.openAmount * (doorStage.width * 0.48)
                            y: 10
                            width: doorStage.width / 2
                            height: doorStage.height - 20
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#20252E" }
                                GradientStop { position: 1.0; color: "#171A20" }
                            }
                            border.color: "#2A2F38"; border.width: 1
                            Rectangle { anchors.left: parent.left; anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 2; height: parent.height * 0.6; color: amberDim }
                        }

                        // Continuous door-cycle animation
                        SequentialAnimation on openAmount {
                            loops: Animation.Infinite
                            running: true
                            PropertyAnimation { to: 0.0; duration: 400 }
                            PauseAnimation   { duration: 200 }
                            PropertyAnimation { to: 1.0; duration: 1200; easing.type: Easing.InOutQuad }
                            PauseAnimation   { duration: 1800 }   // dwell open
                            PropertyAnimation { to: 0.0; duration: 1200; easing.type: Easing.InOutQuad }
                            PauseAnimation   { duration: 1200 }
                        }

                        // Phase text follows animation
                        Connections {
                            target: doorStage
                            function onOpenAmountChanged() {
                                if (doorStage.openAmount > 0.95) carState.doorPhase = "OPEN";
                                else if (doorStage.openAmount < 0.05) carState.doorPhase = "CLOSED";
                                // otherwise leave phase as last transition state; a real impl would use a state machine
                            }
                        }
                    }

                    // Door status line
                    RowLayout {
                        spacing: 10
                        Rectangle {
                            width: 10; height: 10; radius: 5; color: amber
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                PropertyAnimation { to: 0.4; duration: 800 }
                                PropertyAnimation { to: 1.0; duration: 800 }
                            }
                        }
                        Text { text: carState.doorPhase === "OPEN" ? "OPEN" : (carState.doorPhase === "CLOSED" ? "LATCHED" : carState.doorPhase)
                               color: ink; font.family: monoFont; font.pixelSize: 13; font.letterSpacing: 3 }
                        Item { Layout.fillWidth: true }
                        Text { text: carState.doorPhase === "OPEN" ? ("HOLD " + carState.doorHoldSec + "s") : "—"
                               color: inkDim; font.family: monoFont; font.pixelSize: 12; font.letterSpacing: 2 }
                    }
                }
            }

            // ---- Load card ----
            Rectangle {
                Layout.fillWidth: true
                color: bgElev
                border.color: line; border.width: 1
                implicitHeight: 170

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    RowLayout {
                        Text { text: "LOAD"; color: inkMute; font.family: monoFont; font.pixelSize: 11; font.letterSpacing: 3 }
                        Item { Layout.fillWidth: true }
                        Text { text: carState.loadPercent < 80 ? "NOMINAL" : "OVERLOAD"
                               color: carState.loadPercent < 80 ? amber : red
                               font.family: monoFont; font.pixelSize: 11; font.letterSpacing: 3 }
                    }

                    RowLayout {
                        Text {
                            text: carState.loadPercent + "%"
                            color: ink; font.family: monoFont; font.pixelSize: 40; font.weight: Font.Medium
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: carState.loadKg + " / " + carState.capacityKg + " kg"
                            color: inkDim; font.family: monoFont; font.pixelSize: 13; font.letterSpacing: 2
                        }
                    }

                    // Load bar
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 18
                        color: bgElev2
                        border.color: line; border.width: 1
                        Rectangle {
                            width: parent.width * (carState.loadPercent / 100)
                            height: parent.height
                            color: carState.loadPercent < 80 ? amber : red
                            Behavior on width { NumberAnimation { duration: 300 } }
                        }
                        // tick overlay
                        Row {
                            anchors.fill: parent; spacing: 0
                            Repeater {
                                model: 10
                                Rectangle { width: parent.width/10; height: parent.height; color: "transparent"
                                            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: "#000"; opacity: 0.55 } }
                            }
                        }
                    }

                    RowLayout {
                        Text { text: "0";    color: inkMute; font.family: monoFont; font.pixelSize: 10; font.letterSpacing: 2 }
                        Item { Layout.fillWidth: true }
                        Text { text: "50";   color: inkMute; font.family: monoFont; font.pixelSize: 10; font.letterSpacing: 2 }
                        Item { Layout.fillWidth: true }
                        Text { text: "75";   color: amber;   font.family: monoFont; font.pixelSize: 10; font.letterSpacing: 2 }
                        Item { Layout.fillWidth: true }
                        Text { text: "100%"; color: red;     font.family: monoFont; font.pixelSize: 10; font.letterSpacing: 2 }
                    }
                }
            }
        }
    }

    // =====================================================
    // BOTTOM DOCK: car-call buttons + operations
    // =====================================================
    Rectangle {
        id: dock
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 220
        color: "transparent"
        Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: lineSoft }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 24

            // Car calls grid
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

                RowLayout {
                    Text { text: "CAR CALLS"; color: inkMute; font.family: monoFont; font.pixelSize: 11; font.letterSpacing: 3 }
                    Item { Layout.fillWidth: true }
                    Text { text: carState.activeCalls.length + " ACTIVE"; color: inkMute; font.family: monoFont; font.pixelSize: 11; font.letterSpacing: 3 }
                }

                GridLayout {
                    columns: 5
                    columnSpacing: 12
                    rowSpacing: 12
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Repeater {
                        model: [
                            { label: "9",     value: 9,  special: false },
                            { label: "10",    value: 10, special: false },
                            { label: "11",    value: 11, special: false },
                            { label: "12",    value: 12, special: false },
                            { label: "14",    value: 14, special: false },
                            { label: "15",    value: 15, special: false },
                            { label: "17",    value: 17, special: false },
                            { label: "20",    value: 20, special: false },
                            { label: "LOBBY", value: 0,  special: true  },
                            { label: "B1",    value: -1, special: true  }
                        ]
                        delegate: Button {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 60
                            property bool lit: carState.activeCalls.indexOf(modelData.value) !== -1
                            background: Rectangle {
                                color: lit ? "#1B1A10" : bgElev
                                border.color: lit ? amber : line
                                border.width: 1
                                Rectangle {
                                    visible: lit
                                    x: parent.width - 14; y: 6
                                    width: 6; height: 6; radius: 3; color: amber
                                }
                            }
                            contentItem: Text {
                                text: modelData.label
                                color: lit ? amber : (modelData.special ? inkDim : ink)
                                font.family: monoFont
                                font.pixelSize: modelData.special ? 14 : 24
                                font.letterSpacing: modelData.special ? 3 : 1
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: {
                                var i = carState.activeCalls.indexOf(modelData.value);
                                if (i === -1) carState.activeCalls.push(modelData.value);
                                else carState.activeCalls.splice(i, 1);
                                carState.activeCalls = carState.activeCalls.slice(); // trigger binding
                            }
                        }
                    }
                }
            }

            // Operations
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

                RowLayout {
                    Text { text: "OPERATIONS"; color: inkMute; font.family: monoFont; font.pixelSize: 11; font.letterSpacing: 3 }
                    Item { Layout.fillWidth: true }
                    Text { text: "TOUCH"; color: inkMute; font.family: monoFont; font.pixelSize: 11; font.letterSpacing: 3 }
                }

                GridLayout {
                    columns: 4; columnSpacing: 12; rowSpacing: 12
                    Layout.fillWidth: true; Layout.fillHeight: true

                    Repeater {
                        model: [
                            { label: "OPEN",  kind: "open"  },
                            { label: "CLOSE", kind: "close" },
                            { label: "HOLD",  kind: "hold"  },
                            { label: "ALARM", kind: "alarm" }
                        ]
                        delegate: Button {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 60
                            background: Rectangle {
                                color: bgElev
                                border.color: modelData.kind === "alarm" ? Qt.rgba(0.91,0.35,0.29,0.5) : line
                                border.width: 1
                            }
                            contentItem: Text {
                                text: modelData.label
                                color: modelData.kind === "alarm" ? red
                                       : modelData.kind === "hold" ? amber : ink
                                font.family: uiFont
                                font.pixelSize: 15
                                font.letterSpacing: 2
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: {
                                if (modelData.kind === "alarm") console.log("ALARM pressed");
                                else if (modelData.kind === "open")  carState.doorPhase = "OPENING";
                                else if (modelData.kind === "close") carState.doorPhase = "CLOSING";
                                else if (modelData.kind === "hold")  carState.doorHoldSec += 3;
                            }
                        }
                    }
                }

                RowLayout {
                    Text { text: "INTERCOM · 24/7 DISPATCH"; color: inkMute
                           font.family: monoFont; font.pixelSize: 11; font.letterSpacing: 3 }
                    Item { Layout.fillWidth: true }
                    Text { text: "CAR " + carState.carId + " · FW 6.5.2"; color: inkMute
                           font.family: monoFont; font.pixelSize: 11; font.letterSpacing: 3 }
                }
            }
        }
    }
}
