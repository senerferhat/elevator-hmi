import QtQuick

// Up/down direction arrows. The active one is amber and pulses.
// Canvas is software-renderer safe (confirmed on glass 2026-08-18).

Row {
    id: arrows
    property var hmi
    property int arrowSize: 112
    spacing: 70

    readonly property var car: hmi ? hmi.car : null
    readonly property color amber: hmi ? hmi.amber : "#E8C84A"

    Repeater {
        model: [1, -1]
        delegate: Item {
            id: arrowSlot
            required property int modelData
            readonly property bool active: arrows.car && arrows.car.direction === modelData
            width: arrows.arrowSize
            height: arrows.arrowSize

            Rectangle {
                anchors.fill: parent
                anchors.margins: -14
                color: arrows.amber
                opacity: arrowSlot.active ? 0.10 : 0.0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 220 } }
            }

            Canvas {
                id: arrowCanvas
                anchors.fill: parent
                property bool lit: arrowSlot.active
                onLitChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = lit ? arrows.amber : "#39414D";
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
