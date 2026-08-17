// Elevator HMI — car display mockup
//
// Target: LMT101SX006C, 800x1280 PORTRAIT, RK3566 / Mali-G52, Qt 6.8 EGLFS.
// Per CLAUDE.md §8: UI is QML only. No C++ UI code. Any real data must arrive
// via Q_PROPERTY/signals from a C++ backend (Phase 2, over PAL) — everything
// animated here is a self-contained mockup so the panel can be demonstrated
// with no fieldbus present.
//
// Deliberately uses only QtQuick (no QtQuick.Controls): Controls and its styles
// are not in the recipe's DEPENDS/RDEPENDS, and adding them would grow the first
// Qt image for no benefit in a fixed-function HMI that has no generic widgets.

import QtQuick

Window {
    id: root
    visible: true
    // EGLFS gives a fullscreen surface; these are the panel's native portrait
    // dimensions so the layout is correct if it is ever run windowed on a host.
    width: 800
    height: 1280
    color: "#0d1117"
    title: "Elevator HMI"

    // ---- Mock state -------------------------------------------------------
    // Stands in for the future PAL-backed backend.
    property int currentFloor: 1
    property int targetFloor: 8
    // -1 down, 0 idle, +1 up
    property int direction: currentFloor === targetFloor ? 0
                                                         : (targetFloor > currentFloor ? 1 : -1)
    property bool doorsOpen: false

    readonly property color accent: "#4aa3ff"
    readonly property color dim: "#5b6673"

    // Drives the mock travel: move a floor at a time, pause and open doors on
    // arrival, then pick a new destination.
    Timer {
        interval: doorsOpen ? 2600 : 1100
        running: true
        repeat: true
        onTriggered: {
            if (root.doorsOpen) {
                root.doorsOpen = false;
                var next = root.currentFloor;
                while (next === root.currentFloor)
                    next = 1 + Math.floor(Math.random() * 12);
                root.targetFloor = next;
            } else if (root.currentFloor === root.targetFloor) {
                root.doorsOpen = true;
            } else {
                root.currentFloor += root.direction;
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 48
        spacing: 40

        // ---- Header -------------------------------------------------------
        Item {
            width: parent.width
            height: 64

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "CAR 1"
                color: root.dim
                font.pixelSize: 30
                font.letterSpacing: 4
                font.bold: true
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Rectangle {
                    width: 14; height: 14; radius: 7
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#3fb950"
                    // Slow pulse = "system alive". Also a useful visual check
                    // that the panel is genuinely refreshing, not showing a
                    // frozen last frame.
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 1400; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1.0;  duration: 1400; easing.type: Easing.InOutQuad }
                    }
                }
                Text {
                    text: "IN SERVICE"
                    color: root.dim
                    font.pixelSize: 24
                    font.letterSpacing: 2
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // ---- Direction arrow ----------------------------------------------
        Item {
            width: parent.width
            height: 180

            Canvas {
                id: arrow
                anchors.centerIn: parent
                width: 150
                height: 150
                // Repaint whenever travel state changes.
                property int dir: root.direction
                onDirChanged: requestPaint()
                visible: root.direction !== 0

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = root.accent;
                    ctx.beginPath();
                    if (dir > 0) {
                        ctx.moveTo(width / 2, 12);
                        ctx.lineTo(width - 12, height * 0.55);
                        ctx.lineTo(width * 0.68, height * 0.55);
                        ctx.lineTo(width * 0.68, height - 12);
                        ctx.lineTo(width * 0.32, height - 12);
                        ctx.lineTo(width * 0.32, height * 0.55);
                        ctx.lineTo(12, height * 0.55);
                    } else {
                        ctx.moveTo(width / 2, height - 12);
                        ctx.lineTo(width - 12, height * 0.45);
                        ctx.lineTo(width * 0.68, height * 0.45);
                        ctx.lineTo(width * 0.68, 12);
                        ctx.lineTo(width * 0.32, 12);
                        ctx.lineTo(width * 0.32, height * 0.45);
                        ctx.lineTo(12, height * 0.45);
                    }
                    ctx.closePath();
                    ctx.fill();
                }

                SequentialAnimation on opacity {
                    running: root.direction !== 0
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 600 }
                    NumberAnimation { to: 1.0;  duration: 600 }
                }
            }

            // Shown while stationary, in place of the arrow.
            Text {
                anchors.centerIn: parent
                visible: root.direction === 0
                text: root.doorsOpen ? "DOORS OPEN" : "READY"
                color: root.doorsOpen ? "#3fb950" : root.dim
                font.pixelSize: 40
                font.letterSpacing: 3
                font.bold: true
            }
        }

        // ---- Floor number (the dominant element) --------------------------
        Item {
            width: parent.width
            height: 420

            Text {
                id: floorText
                anchors.centerIn: parent
                text: root.currentFloor
                color: "white"
                font.pixelSize: 380
                font.bold: true

                // Brief scale pop on each floor change — makes motion obvious
                // from across a lobby, and confirms live rendering.
                // NOTE: deliberately NOT a `Behavior on text`. A Behavior
                // intercepts the property assignment and expects its animation
                // to produce the new value; an animation that only touches
                // `scale` would swallow the text update and the number would
                // never change. Trigger off the change signal instead.
                onTextChanged: floorPop.restart()

                SequentialAnimation {
                    id: floorPop
                    NumberAnimation { target: floorText; property: "scale"; to: 0.82; duration: 110 }
                    NumberAnimation { target: floorText; property: "scale"; to: 1.0;  duration: 190; easing.type: Easing.OutBack }
                }
            }
        }

        // ---- Floor ladder --------------------------------------------------
        Item {
            width: parent.width
            height: 90

            Row {
                anchors.centerIn: parent
                spacing: 10

                Repeater {
                    model: 12
                    delegate: Rectangle {
                        required property int index
                        readonly property int floorNumber: index + 1
                        width: 46
                        height: floorNumber === root.currentFloor ? 62 : 34
                        radius: 6
                        color: floorNumber === root.currentFloor ? root.accent
                             : floorNumber === root.targetFloor  ? "#294a6d"
                                                                 : "#1b2027"
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on color  { ColorAnimation  { duration: 220 } }

                        Text {
                            anchors.centerIn: parent
                            text: parent.floorNumber
                            color: parent.floorNumber === root.currentFloor ? "#0d1117" : root.dim
                            font.pixelSize: 20
                            font.bold: true
                        }
                    }
                }
            }
        }

        // ---- Footer / provenance -------------------------------------------
        // Static provenance line. QML has no reliable runtime accessor for the
        // Qt version (Qt.application.version is the *app* version), and the Qt
        // release is fixed by ADR-001 / the pinned meta-qt6 lts-6.8.7 branch,
        // so state it literally rather than inventing a lookup.
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "LMT101SX006C · 800×1280 · Qt 6.8 LTS · EGLFS"
            color: "#39414d"
            font.pixelSize: 22
        }
    }
}
