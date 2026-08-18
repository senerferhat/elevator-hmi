// Elevator HMI — car display
//
// Target: LMT101SX006C, 800x1280 PORTRAIT, RK3566, Qt 6.8.
// Implements design/elevator-hmi "Elevator HMI Vertical" and "Vertical Video"
// at the panel's native 800×1280. Layout is selected from the command line
// (`elevator-hmi car` / `elevator-hmi video`, or the `hmi` helper) — there is
// no on-glass tweaks menu. The trip simulator (demo cycle) always runs.
//
// RENDERING CONSTRAINTS — READ BEFORE EDITING (see diary/BLOCKERS.md BLK-015):
// This runs under QT_QPA_PLATFORM=linuxfb with QT_QUICK_BACKEND=software, because
// KMS scanout does not reach this panel. There is NO OpenGL. That rules out:
//   - ShaderEffect / ShaderEffectSource
//   - layer.enabled / layer.effect (needs an FBO)
//   - Qt5Compat.GraphicalEffects (Glow, DropShadow, RadialGradient)
// Glows here are therefore built from stacked translucent rounded Rectangles,
// not blur effects. Rectangle gradients and Canvas DO work in the software
// renderer (Canvas confirmed on glass 2026-08-18).
//
// Per CLAUDE.md §8 the UI is QML only; every value below is mock state so the
// panel demos with no fieldbus present. Real data arrives later via Q_PROPERTY
// from the PAL backend.
//
// Deliberately plain QtQuick — no QtQuick.Controls or Layouts. Nothing here
// needs them, and staying off Controls keeps the image and RDEPENDS smaller.

import QtQuick
import QtQuick.Window

Window {
    id: root
    visible: true
    width: 800
    height: 1280
    color: root.bg
    title: "Elevator HMI"

    // ---- Design tokens (from the HTML design) -----------------------------
    readonly property color bg:       "#0E1013"
    readonly property color bgElev:   "#15181D"
    readonly property color bgElev2:  "#1C2028"
    readonly property color line:     "#262B33"
    readonly property color lineSoft: "#1E232B"
    readonly property color ink:      "#E8ECF2"
    readonly property color inkDim:   "#9AA3B2"
    readonly property color inkMute:  "#5C6573"
    readonly property color amber:    "#E8C84A"
    readonly property color amberHi:  "#F5E080"
    readonly property color amberDim: "#6B5A1F"
    readonly property color red:      "#E85A4A"
    readonly property color green:    "#5AE89A"

    // Substitutes for the design's JetBrains Mono / Inter. The image ships
    // liberation-fonts (see elevator-hmi-image.bb); fontconfig will fall back
    // if a name is missing rather than rendering blank Text (that looked like
    // a dead panel on 2026-08-18).
    readonly property string monoFont: "Liberation Mono"
    readonly property string uiFont:   "Liberation Sans"

    // "car" = full portrait HMI. "video" = HTML "Vertical Video" with the
    // top half reserved for SD-card playback (empty placeholder for now).
    // The C++ binary (and the `hmi` helper) pass this as argv[1].
    property string layout: {
        var args = Qt.application.arguments;
        for (var i = 1; i < args.length; ++i) {
            if (args[i] === "car" || args[i] === "video")
                return args[i];
            if (args[i].indexOf("--layout=") === 0)
                return args[i].substring(9);
        }
        return "car";
    }
    property bool videoMode: layout === "video"

    // Demo-cycle phase, driven by the trip simulator. Replaces the old
    // TWEAKS control: the panel always animates a car, no operator menu.
    property string demoPhase: "IDLE"

    // =====================================================================
    // Mock car state
    // =====================================================================
    readonly property var floorNames: ["B1", "L", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]

    QtObject {
        id: car
        property int currentIndex: 6            // index into floorNames -> "5"
        property int destIndex: 6
        property real speedMs: 0.0
        property int etaSec: 0
        property int loadPercent: 0
        property int capacityKg: 1600
        // CLOSED | OPENING | OPEN | CLOSING
        property string doorPhase: "CLOSED"
        property string mode: "NORMAL SERVICE"
        property string carId: "A-04"
        property string building: "TOWER NORTH"

        readonly property int loadKg: Math.round(capacityKg * loadPercent / 100)
        // -1 down, 0 idle, +1 up
        readonly property int direction: destIndex === currentIndex ? 0
                                                                    : (destIndex > currentIndex ? 1 : -1)
        readonly property bool moving: direction !== 0 && doorPhase === "CLOSED"
    }

    // ---- Clock ------------------------------------------------------------
    property string clockHM: "--:--"
    property string clockSec: "--"
    property string clockDate: ""

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const d = new Date();
            const pad = n => n < 10 ? "0" + n : "" + n;
            root.clockHM = pad(d.getHours()) + ":" + pad(d.getMinutes());
            root.clockSec = pad(d.getSeconds());
            const days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
            const months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
            root.clockDate = days[d.getDay()] + " · " + pad(d.getDate()) + " " +
                             months[d.getMonth()] + " " + d.getFullYear();
        }
    }

    // ---- Activity log -----------------------------------------------------
    ListModel { id: activityModel }

    function logEvent(floorLabel, text) {
        const d = new Date();
        const pad = n => n < 10 ? "0" + n : "" + n;
        activityModel.insert(0, {
            stamp: pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":" + pad(d.getSeconds()),
            floor: floorLabel,
            what: text
        });
        // The dock only has room for a few rows; keep the model from growing
        // without bound over a 24/7 run.
        while (activityModel.count > 5)
            activityModel.remove(activityModel.count - 1);
    }

    // =====================================================================
    // Trip simulation
    //
    // A small state machine so the demo behaves like a car instead of merely
    // animating: travel a floor at a time, open doors on arrival, dwell, pick a
    // new destination. Also drives load, speed and ETA so the readouts move.
    // =====================================================================
    Timer {
        id: sim
        interval: 900
        running: true
        repeat: true

        onTriggered: {
            if (car.doorPhase === "OPENING") {
                car.doorPhase = "OPEN";
                root.demoPhase = "DWELL";
                interval = 2600;
                return;
            }
            if (car.doorPhase === "OPEN") {
                car.doorPhase = "CLOSING";
                root.demoPhase = "DOOR";
                interval = 900;
                return;
            }
            if (car.doorPhase === "CLOSING") {
                car.doorPhase = "CLOSED";
                // Pick a new destination that is not where we already are.
                let next = car.currentIndex;
                while (next === car.currentIndex)
                    next = Math.floor(Math.random() * root.floorNames.length);
                car.destIndex = next;
                car.loadPercent = Math.min(100, Math.max(0,
                    car.loadPercent + Math.floor(Math.random() * 50) - 20));
                root.logEvent(root.floorNames[car.currentIndex], "DOOR CYCLE");
                root.demoPhase = (next === car.currentIndex) ? "IDLE" : "TRAVEL";
                interval = 900;
                return;
            }

            // doorPhase === "CLOSED"
            if (car.currentIndex === car.destIndex) {
                car.speedMs = 0.0;
                car.etaSec = 0;
                car.doorPhase = "OPENING";
                root.demoPhase = "DOOR";
                root.logEvent(root.floorNames[car.currentIndex], "ARRIVED · IDLE");
                interval = 900;
                return;
            }

            root.demoPhase = "TRAVEL";
            car.currentIndex += car.direction;
            const remaining = Math.abs(car.destIndex - car.currentIndex);
            car.speedMs = remaining === 0 ? 0.0 : Math.min(2.5, 0.8 + remaining * 0.35);
            car.etaSec = remaining * 3;
            interval = 900;
        }
    }

    Component.onCompleted: {
        logEvent(floorNames[car.currentIndex], "CAR CALL ACCEPTED");
        logEvent(floorNames[car.currentIndex], "SYSTEM READY");
    }

    // =====================================================================
    // Reusable pieces. Inline components keep this to the single main.qml the
    // recipe installs, without repeating the card chrome five times.
    // =====================================================================

    // A bordered panel with a title row: DOOR / LOAD / DIAGNOSTICS / SERVICE /
    // ACTIVITY all use it.
    component Card: Rectangle {
        id: card
        property string title: ""
        property string badge: ""
        property color badgeColor: root.inkDim
        default property alias content: body.data

        color: root.bgElev
        border.color: root.lineSoft
        border.width: 1
        radius: 2

        Text {
            x: 18
            y: 16
            text: card.title
            color: root.inkDim
            font.family: root.monoFont
            font.pixelSize: 11
            font.letterSpacing: 3
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 18
            y: 16
            text: card.badge
            color: card.badgeColor
            font.family: root.monoFont
            font.pixelSize: 11
            font.letterSpacing: 2
        }
        Item {
            id: body
            anchors.fill: parent
            anchors.topMargin: 42
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.bottomMargin: 14
        }
    }

    // Label-over-value pair used inside DIAGNOSTICS.
    component Stat: Column {
        id: stat
        property string label: ""
        property string value: ""
        property string unit: ""
        property color valueColor: root.ink
        spacing: 4

        Text {
            text: stat.label
            color: root.inkMute
            font.family: root.monoFont
            font.pixelSize: 10
            font.letterSpacing: 2
        }
        Row {
            spacing: 4
            Text {
                text: stat.value
                color: stat.valueColor
                font.family: root.monoFont
                font.pixelSize: 18
                font.bold: true
            }
            Text {
                text: stat.unit
                color: root.inkMute
                font.family: root.monoFont
                font.pixelSize: 10
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
            }
        }
    }

    // Key/value row used inside SERVICE.
    component InfoRow: Item {
        id: info
        property string label: ""
        property string value: ""
        property color valueColor: root.ink
        height: 26

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: info.label
            color: root.inkDim
            font.family: root.monoFont
            font.pixelSize: 11
            font.letterSpacing: 2
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: info.value
            color: info.valueColor
            font.family: root.monoFont
            font.pixelSize: 12
            font.bold: true
        }
    }

    // =====================================================================
    // Decorative frame corners (design: .corner tl/tr/bl/br)
    // =====================================================================
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
            x: modelData.hx === 0 ? 10 : root.width - width - 10
            y: modelData.hy === 0 ? 10 : root.height - height - 10

            Rectangle {
                width: parent.width
                height: 1
                color: root.line
                x: 0
                y: corner.modelData.hy === 0 ? 0 : corner.height - 1
            }
            Rectangle {
                width: 1
                height: parent.height
                color: root.line
                y: 0
                x: corner.modelData.hx === 0 ? 0 : corner.width - 1
            }
        }
    }

    // =====================================================================
    // Layout
    // =====================================================================
    Column {
        id: page
        anchors.fill: parent
        anchors.topMargin: 16
        anchors.bottomMargin: 10
        spacing: 0

        // ---- VIDEO PANE (videoMode only) ---------------------------------
        Item {
            id: videoPane
            width: parent.width
            height: root.videoMode ? 600 : 0
            visible: root.videoMode
            clip: true

            Rectangle {
                anchors.fill: parent
                color: "#0B0D10"

                // Diagonal hatch for the "no signal" fill. Rotated bars rather
                // than a shader, since there is no GL here.
                Item {
                    anchors.fill: parent
                    clip: true
                    Repeater {
                        model: 46
                        delegate: Rectangle {
                            required property int index
                            width: 2
                            height: videoPane.height * 3
                            color: "#12151A"
                            x: index * 34 - 320
                            y: -videoPane.height
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
                        color: root.red
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "LIVE  ·  CH 04"
                        color: root.ink
                        font.family: root.monoFont
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
                    color: root.inkMute
                    font.family: root.monoFont
                    font.pixelSize: 11
                    font.letterSpacing: 2
                }

                // NO SOURCE placeholder
                Column {
                    anchors.centerIn: parent
                    spacing: 16

                    Rectangle {
                        width: 96; height: 96; radius: 48
                        color: "transparent"
                        border.color: root.line
                        border.width: 1
                        anchors.horizontalCenter: parent.horizontalCenter

                        Canvas {
                            anchors.centerIn: parent
                            width: 34; height: 38
                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.reset();
                                ctx.fillStyle = root.inkMute;
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
                        color: root.inkDim
                        font.family: root.monoFont
                        font.pixelSize: 15
                        font.letterSpacing: 4
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: "SD CARD · EMPTY"
                        color: root.inkMute
                        font.family: root.monoFont
                        font.pixelSize: 11
                        font.letterSpacing: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                // Transport controls
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
                            border.color: root.line
                            border.width: 1
                            radius: 2
                            Text {
                                anchors.centerIn: parent
                                text: transportBtn.modelData
                                color: root.ink
                                font.family: root.monoFont
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
                    color: root.inkMute
                    font.family: root.monoFont
                    font.pixelSize: 11
                    font.letterSpacing: 2
                }
            }
        }

        // ---- TOP BAR ------------------------------------------------------
        Item {
            width: parent.width
            height: 60

            Row {
                x: 22
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: root.green
                    anchors.verticalCenter: parent.verticalCenter
                    // Slow pulse doubles as a "this panel really is refreshing"
                    // indicator — a frozen last frame is otherwise very hard to
                    // distinguish from a live one (see BLK-014).
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 1400; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1.0; duration: 1400; easing.type: Easing.InOutQuad }
                    }
                }
                Text {
                    text: "CAR"
                    color: root.inkDim
                    font.family: root.monoFont
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: car.carId
                    color: root.ink
                    font.family: root.monoFont
                    font.pixelSize: 13
                    font.letterSpacing: 3
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "·"
                    color: root.inkMute
                    font.pixelSize: 13
                    visible: !root.videoMode
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: car.building
                    color: root.inkDim
                    font.family: root.monoFont
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    visible: !root.videoMode
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    text: root.clockHM
                    color: root.ink
                    font.family: root.monoFont
                    font.pixelSize: 30
                    font.bold: true
                    anchors.bottom: parent.bottom
                }
                Text {
                    text: ":" + root.clockSec
                    color: root.inkDim
                    font.family: root.monoFont
                    font.pixelSize: 17
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                }
                Text {
                    text: root.clockDate
                    color: root.inkMute
                    font.family: root.monoFont
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
                color: root.lineSoft
            }
        }

        // ---- MODE ROW -----------------------------------------------------
        Item {
            width: parent.width
            height: root.videoMode ? 0 : 52
            visible: !root.videoMode

            Row {
                anchors.centerIn: parent
                spacing: 12

                Text {
                    text: "MODE"
                    color: root.inkDim
                    font.family: root.monoFont
                    font.pixelSize: 12
                    font.letterSpacing: 3
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    width: modeText.implicitWidth + 34
                    height: 30
                    color: "transparent"
                    border.color: root.line
                    border.width: 1
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        id: modeText
                        anchors.centerIn: parent
                        text: car.mode
                        color: root.amber
                        font.family: root.monoFont
                        font.pixelSize: 12
                        font.letterSpacing: 3
                    }
                }
                Text {
                    text: "·"
                    color: root.inkMute
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "NEXT"
                    color: root.inkDim
                    font.family: root.monoFont
                    font.pixelSize: 12
                    font.letterSpacing: 3
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    width: 46
                    height: 30
                    color: "transparent"
                    border.color: root.line
                    border.width: 1
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: car.direction === 0 ? "—" : root.floorNames[car.destIndex]
                        color: root.amber
                        font.family: root.monoFont
                        font.pixelSize: 12
                        font.letterSpacing: 2
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: root.lineSoft
            }
        }

        // ---- HERO: floor rail + current floor ------------------------------
        Item {
            id: hero
            width: parent.width
            height: root.videoMode ? 296 : 556

            // -- Floor rail --
            Item {
                id: rail
                width: 190
                height: parent.height
                clip: true

                Text {
                    x: 52
                    y: 8
                    text: "FLOORS"
                    color: root.inkDim
                    font.family: root.monoFont
                    font.pixelSize: 10
                    font.letterSpacing: 3
                    visible: !root.videoMode
                }

                Item {
                    id: railBody
                    x: 0
                    y: root.videoMode ? 10 : 32
                    width: parent.width
                    height: rail.height - y - 12

                    readonly property int slots: root.floorNames.length
                    readonly property real slotH: height / slots
                    // Index 0 is the lowest floor, so it sits at the BOTTOM.
                    function yFor(idx) {
                        return height - (idx + 0.5) * slotH;
                    }

                    // Track
                    Rectangle {
                        x: 128
                        y: railBody.slotH / 2
                        width: 1
                        height: railBody.height - railBody.slotH
                        color: root.line
                    }

                    // Travel segment: current -> destination.
                    Rectangle {
                        x: 127
                        width: 3
                        color: root.amber
                        opacity: 0.85
                        y: Math.min(railBody.yFor(car.currentIndex), railBody.yFor(car.destIndex))
                        height: Math.abs(railBody.yFor(car.destIndex) - railBody.yFor(car.currentIndex))
                        visible: car.direction !== 0
                        Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                    }

                    // Floor ticks + labels
                    Repeater {
                        model: root.floorNames.length
                        delegate: Item {
                            id: floorSlot
                            required property int index
                            readonly property bool isCurrent: index === car.currentIndex
                            width: rail.width
                            height: railBody.slotH
                            y: railBody.height - (index + 1) * railBody.slotH

                            Text {
                                x: 88
                                width: 26
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignRight
                                text: root.floorNames[floorSlot.index]
                                color: floorSlot.isCurrent ? root.amber : root.inkMute
                                font.family: root.monoFont
                                font.pixelSize: floorSlot.isCurrent ? 14 : 12
                                font.bold: floorSlot.isCurrent
                            }
                            Rectangle {
                                x: 122
                                anchors.verticalCenter: parent.verticalCenter
                                width: floorSlot.isCurrent ? 16 : 10
                                height: 1
                                color: floorSlot.isCurrent ? root.amber : root.line
                            }
                        }
                    }

                    // Car marker. The design's glow is a blur; with no GL we
                    // stack translucent circles to approximate it.
                    Item {
                        id: marker
                        x: 129
                        y: railBody.yFor(car.currentIndex)
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
                                color: root.amber
                                opacity: modelData.a
                            }
                        }
                        Rectangle {
                            width: 11; height: 11; radius: 6
                            x: -width / 2
                            y: -height / 2
                            color: root.amberHi
                        }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    width: 1
                    height: parent.height
                    color: root.lineSoft
                }
            }

            // -- Current floor --
            Item {
                anchors.left: rail.right
                anchors.right: parent.right
                height: parent.height

                Text {
                    id: heroLabel
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.videoMode ? 10 : 44
                    text: "CURRENT FLOOR"
                    color: root.inkDim
                    font.family: root.monoFont
                    font.pixelSize: 13
                    font.letterSpacing: 5
                }

                Text {
                    id: heroNum
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: heroLabel.bottom
                    anchors.topMargin: root.videoMode ? -6 : 4
                    text: root.floorNames[car.currentIndex]
                    color: root.amber
                    font.family: root.monoFont
                    font.pixelSize: root.videoMode ? 116 : 200
                    font.bold: true

                    // Scale pop on each change. NOT a `Behavior on text`: a
                    // Behavior intercepts the assignment and expects its
                    // animation to produce the new value, so animating `scale`
                    // there would swallow the text update entirely.
                    onTextChanged: floorPop.restart()
                    SequentialAnimation {
                        id: floorPop
                        NumberAnimation { target: heroNum; property: "scale"; to: 0.86; duration: 110 }
                        NumberAnimation { target: heroNum; property: "scale"; to: 1.0; duration: 200; easing.type: Easing.OutBack }
                    }
                }

                // Direction arrows: up and down, the active one lit.
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: heroNum.bottom
                    anchors.topMargin: root.videoMode ? 0 : 16
                    spacing: root.videoMode ? 40 : 70

                    Repeater {
                        model: [1, -1]
                        delegate: Item {
                            id: arrowSlot
                            required property int modelData
                            readonly property bool active: car.direction === modelData
                            width: root.videoMode ? 74 : 112
                            height: root.videoMode ? 74 : 136

                            // Lit backing plate behind the active arrow.
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -14
                                color: root.amber
                                opacity: arrowSlot.active ? 0.10 : 0.0
                                visible: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: 220 } }
                            }

                            Canvas {
                                id: arrowCanvas
                                anchors.fill: parent
                                // Canvas does not track bindings used inside
                                // onPaint, so repaint explicitly when lit flips.
                                property bool lit: arrowSlot.active
                                onLitChanged: requestPaint()
                                onPaint: {
                                    const ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.fillStyle = lit ? root.amber : "#39414D";
                                    const w = width, h = height;
                                    ctx.beginPath();
                                    if (arrowSlot.modelData > 0) {
                                        ctx.moveTo(w / 2, 0);
                                        ctx.lineTo(w, h * 0.52);
                                        ctx.lineTo(w * 0.68, h * 0.52);
                                        ctx.lineTo(w * 0.68, h);
                                        ctx.lineTo(w * 0.32, h);
                                        ctx.lineTo(w * 0.32, h * 0.52);
                                        ctx.lineTo(0, h * 0.52);
                                    } else {
                                        ctx.moveTo(w / 2, h);
                                        ctx.lineTo(w, h * 0.48);
                                        ctx.lineTo(w * 0.68, h * 0.48);
                                        ctx.lineTo(w * 0.68, 0);
                                        ctx.lineTo(w * 0.32, 0);
                                        ctx.lineTo(w * 0.32, h * 0.48);
                                        ctx.lineTo(0, h * 0.48);
                                    }
                                    ctx.closePath();
                                    ctx.fill();
                                }
                            }

                            SequentialAnimation on opacity {
                                running: arrowSlot.active
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.45; duration: 620 }
                                NumberAnimation { to: 1.0; duration: 620 }
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: root.lineSoft
            }
        }

        // ---- DEST / SPEED / ETA -------------------------------------------
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
                        color: root.inkDim
                        font.family: root.monoFont
                        font.pixelSize: 12
                        font.letterSpacing: 3
                    }
                    Text {
                        text: car.direction === 0 ? "—" : root.floorNames[car.destIndex]
                        color: root.ink
                        font.family: root.monoFont
                        font.pixelSize: 13
                        font.bold: true
                    }
                }
                Row {
                    spacing: 10
                    Text {
                        text: "SPEED"
                        color: root.inkDim
                        font.family: root.monoFont
                        font.pixelSize: 12
                        font.letterSpacing: 3
                    }
                    Text {
                        text: car.speedMs.toFixed(1) + " M/S"
                        color: root.ink
                        font.family: root.monoFont
                        font.pixelSize: 13
                        font.bold: true
                    }
                }
                Row {
                    spacing: 10
                    Text {
                        text: "ETA"
                        color: root.inkDim
                        font.family: root.monoFont
                        font.pixelSize: 12
                        font.letterSpacing: 3
                    }
                    Text {
                        text: "00:" + (car.etaSec < 10 ? "0" + car.etaSec : car.etaSec)
                        color: root.ink
                        font.family: root.monoFont
                        font.pixelSize: 13
                        font.bold: true
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: root.lineSoft
            }
        }

        // ---- DOOR | LOAD ---------------------------------------------------
        Row {
            width: parent.width
            height: 196
            spacing: 0

            // DOOR
            Card {
                width: parent.width / 2
                height: parent.height
                title: "DOOR"
                badge: car.doorPhase === "CLOSED" ? "LATCHED" : car.doorPhase
                badgeColor: car.doorPhase === "OPEN" ? root.green : root.inkDim

                Item {
                    anchors.fill: parent

                    // Door leaves sliding apart.
                    Item {
                        id: doorGfx
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        width: 120
                        height: 74

                        readonly property real openFrac: car.doorPhase === "OPEN" ? 1.0
                                                       : car.doorPhase === "OPENING" ? 0.6
                                                       : car.doorPhase === "CLOSING" ? 0.35 : 0.0
                        Behavior on openFrac { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }

                        // Shaft behind the leaves
                        Rectangle {
                            anchors.centerIn: parent
                            width: 26
                            height: parent.height
                            color: "transparent"
                            border.color: root.line
                            border.width: 1
                            Rectangle {
                                anchors.centerIn: parent
                                width: 2
                                height: parent.height - 18
                                color: root.amberDim
                            }
                        }

                        Rectangle {
                            width: 26
                            height: parent.height
                            color: root.amberDim
                            x: doorGfx.width / 2 - 16 - width - doorGfx.openFrac * 24
                        }
                        Rectangle {
                            width: 26
                            height: parent.height
                            color: root.amberDim
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
                            color: car.doorPhase === "OPEN" ? root.green : root.amber
                        }
                        Text {
                            text: car.doorPhase
                            color: root.ink
                            font.family: root.monoFont
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
                        color: root.inkMute
                        font.family: root.monoFont
                        font.pixelSize: 13
                    }
                }
            }

            // LOAD
            Card {
                width: parent.width / 2
                height: parent.height
                title: "LOAD"
                badge: car.loadPercent > 90 ? "OVERLOAD" : car.loadPercent > 70 ? "HIGH" : "NOMINAL"
                badgeColor: car.loadPercent > 90 ? root.red : car.loadPercent > 70 ? root.amber : root.inkDim

                Item {
                    anchors.fill: parent

                    Row {
                        id: loadReadout
                        spacing: 4
                        Text {
                            text: car.loadPercent
                            color: root.ink
                            font.family: root.monoFont
                            font.pixelSize: 32
                            font.bold: true
                        }
                        Text {
                            text: "%"
                            color: root.inkMute
                            font.family: root.monoFont
                            font.pixelSize: 13
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 5
                        }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: loadReadout.verticalCenter
                        text: car.loadKg + " / " + car.capacityKg + " KG"
                        color: root.inkDim
                        font.family: root.monoFont
                        font.pixelSize: 12
                    }

                    // Segmented bar
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
                                readonly property bool on: car.loadPercent > index * 10
                                color: seg.on ? (car.loadPercent > 90 ? root.red
                                                : car.loadPercent > 70 ? root.amber : root.green)
                                              : root.bgElev2
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
                                color: modelData.f === 1.0 ? root.red : root.inkMute
                                font.family: root.monoFont
                                font.pixelSize: 9
                                x: tick.modelData.f * (loadScale.width - tick.width)
                            }
                        }
                    }
                }
            }
        }

        // ---- DIAGNOSTICS | SERVICE (hidden in video mode) -------------------
        Row {
            width: parent.width
            height: root.videoMode ? 0 : 190
            visible: !root.videoMode
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

                    Stat { label: "MOTOR TEMP"; value: "42"; unit: "°C"; valueColor: root.amber }
                    Stat { label: "BRAKE"; value: car.moving ? "RELEASED" : "HELD"; valueColor: root.amber }
                    Stat { label: "HOIST"; value: "8.4"; unit: "kN" }
                    Stat { label: "DRIVE"; value: (car.speedMs * 20).toFixed(1); unit: "Hz" }
                    Stat { label: "POSITION"; value: "+" + (car.currentIndex * 3.2).toFixed(2); unit: "m" }
                    Stat { label: "ENCODER"; value: "SYNC"; valueColor: root.amber }
                }
            }

            Card {
                id: serviceCard
                width: parent.width / 2
                height: parent.height
                title: "SERVICE"
                badge: "OK"
                badgeColor: root.green

                Column {
                    id: serviceCol
                    anchors.fill: parent
                    spacing: 2

                    InfoRow { width: serviceCol.width; label: "TRIPS TODAY"; value: "247" }
                    InfoRow { width: serviceCol.width; label: "LAST SERVICE"; value: "14 Apr 2026" }
                    InfoRow { width: serviceCol.width; label: "NEXT INSPECTION"; value: "12 May 2026"; valueColor: root.amber }
                    InfoRow { width: serviceCol.width; label: "CYCLES"; value: "1.84M" }
                }
            }
        }

        // ---- ACTIVITY LOG (hidden in video mode) ---------------------------
        Card {
            width: parent.width
            height: root.videoMode ? 0 : 112
            visible: !root.videoMode
            title: "ACTIVITY"
            badge: "LOG"

            Column {
                anchors.fill: parent
                spacing: 3

                Repeater {
                    model: activityModel
                    delegate: Row {
                        id: logRow
                        required property string stamp
                        required property string floor
                        required property string what
                        spacing: 20

                        Text {
                            text: logRow.stamp
                            color: root.inkMute
                            font.family: root.monoFont
                            font.pixelSize: 11
                        }
                        Text {
                            text: logRow.floor
                            color: root.amber
                            font.family: root.monoFont
                            font.pixelSize: 11
                            font.bold: true
                            width: 22
                        }
                        Text {
                            text: logRow.what
                            color: root.inkDim
                            font.family: root.monoFont
                            font.pixelSize: 11
                            font.letterSpacing: 1
                        }
                    }
                }
            }
        }
    }

    // ---- DEMO CYCLE (replaces the HTML tweaks control) --------------------
    // Always-on trip simulator. Layout switching is a CLI concern (`hmi car`
    // / `hmi video`), not an on-glass button — the panel has no touch.
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        width: demoLabel.implicitWidth + 28
        height: 36
        radius: 2
        z: 50
        color: root.bgElev
        border.color: root.line
        border.width: 1

        Text {
            id: demoLabel
            anchors.centerIn: parent
            text: "DEMO  ·  " + root.demoPhase
            color: root.amber
            font.family: root.monoFont
            font.pixelSize: 11
            font.letterSpacing: 2
        }
    }
}
