// Elevator HMI — car display
//
// Target: LMT101SX006C, native 800×1280 PORTRAIT, RK3566, Qt 6.8.
// Product installs all four design/elevator-hmi variants:
//   portrait           Elevator HMI Vertical.html          800×1280
//   portrait-video     Elevator HMI Vertical Video.html    800×1280
//   landscape          Elevator HMI.html                   1280×800
//   landscape-video    Elevator HMI Landscape Video.html   1280×800
//
// Physical scanout stays 800×1280. Landscape stages are 1280×800 Items
// rotated 90° or 270° (see --rot / `hmi rot`) onto that framebuffer.
// Do not use QT_QPA_FB_ROTATION: linuxfb already writes the boot-latched
// /dev/fb0 (BLK-015); a plugin-level rotate is an extra untested path.
//
// Layout is selected from the command line (`elevator-hmi portrait`,
// aliases `car`/`video`, or the `hmi` helper). No on-glass tweaks menu.
// The trip simulator (demo cycle) always runs.
//
// RENDERING CONSTRAINTS — READ BEFORE EDITING (see diary/BLOCKERS.md BLK-015):
// This runs under QT_QPA_PLATFORM=linuxfb with QT_QUICK_BACKEND=software.
// There is NO OpenGL. That rules out ShaderEffect, layer.enabled, and
// Qt5Compat.GraphicalEffects. Rectangle gradients and Canvas DO work.

import QtQuick
import QtQuick.Window

Window {
    id: root
    visible: true
    width: 800
    height: 1280
    color: root.bg
    title: "Elevator HMI"

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

    readonly property string monoFont: "Liberation Mono"
    readonly property string uiFont:   "Liberation Sans"

    function canonicalLayout(s) {
        if (s === "car" || s === "vertical" || s === "portrait")
            return "portrait";
        if (s === "video" || s === "vertical-video" || s === "portrait-video")
            return "portrait-video";
        if (s === "landscape" || s === "landscape-car")
            return "landscape";
        if (s === "landscape-video")
            return "landscape-video";
        return "";
    }

    property string layout: {
        var args = Qt.application.arguments;
        var found = "portrait";
        for (var i = 1; i < args.length; ++i) {
            var a = args[i];
            if (a.indexOf("--layout=") === 0) {
                var c = canonicalLayout(a.substring(9));
                if (c !== "")
                    found = c;
            } else {
                var d = canonicalLayout(a);
                if (d !== "")
                    found = d;
            }
        }
        return found;
    }
    property bool videoMode: layout.indexOf("video") !== -1
    property bool landscape: layout.indexOf("landscape") === 0

    // 90 = clockwise. If the car mount is the other way up: `hmi rot 270`.
    property int stageRotation: {
        var args = Qt.application.arguments;
        var rot = 90;
        for (var i = 1; i < args.length; ++i) {
            var a = args[i];
            if (a.indexOf("--rot=") === 0) {
                var n = parseInt(a.substring(6), 10);
                if (n === 90 || n === 270)
                    rot = n;
            }
        }
        return rot;
    }

    property string demoPhase: "IDLE"
    readonly property var floorNames: ["B1", "L", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]

    // Exposed via alias so PortraitView / LandscapeView can bind to it
    // (QML ids are component-scoped and not visible across files).
    QtObject {
        id: carObj
        property int currentIndex: 6
        property int destIndex: 6
        property real speedMs: 0.0
        property int etaSec: 0
        property int loadPercent: 0
        property int capacityKg: 1600
        property string doorPhase: "CLOSED"
        property string mode: "NORMAL SERVICE"
        property string carId: "A-04"
        property string building: "TOWER NORTH"

        readonly property int loadKg: Math.round(capacityKg * loadPercent / 100)
        readonly property int direction: destIndex === currentIndex ? 0
                                                                    : (destIndex > currentIndex ? 1 : -1)
        readonly property bool moving: direction !== 0 && doorPhase === "CLOSED"
    }
    property alias car: carObj

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

    ListModel { id: activityModelObj }
    property alias activityModel: activityModelObj

    function logEvent(floorLabel, text) {
        const d = new Date();
        const pad = n => n < 10 ? "0" + n : "" + n;
        activityModelObj.insert(0, {
            stamp: pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":" + pad(d.getSeconds()),
            floor: floorLabel,
            what: text
        });
        while (activityModelObj.count > 5)
            activityModelObj.remove(activityModelObj.count - 1);
    }

    Timer {
        id: sim
        interval: 900
        running: true
        repeat: true

        onTriggered: {
            if (root.car.doorPhase === "OPENING") {
                root.car.doorPhase = "OPEN";
                root.demoPhase = "DWELL";
                interval = 2600;
                return;
            }
            if (root.car.doorPhase === "OPEN") {
                root.car.doorPhase = "CLOSING";
                root.demoPhase = "DOOR";
                interval = 900;
                return;
            }
            if (root.car.doorPhase === "CLOSING") {
                root.car.doorPhase = "CLOSED";
                let next = root.car.currentIndex;
                while (next === root.car.currentIndex)
                    next = Math.floor(Math.random() * root.floorNames.length);
                root.car.destIndex = next;
                root.car.loadPercent = Math.min(100, Math.max(0,
                    root.car.loadPercent + Math.floor(Math.random() * 50) - 20));
                root.logEvent(root.floorNames[root.car.currentIndex], "DOOR CYCLE");
                root.demoPhase = (next === root.car.currentIndex) ? "IDLE" : "TRAVEL";
                interval = 900;
                return;
            }

            if (root.car.currentIndex === root.car.destIndex) {
                root.car.speedMs = 0.0;
                root.car.etaSec = 0;
                root.car.doorPhase = "OPENING";
                root.demoPhase = "DOOR";
                root.logEvent(root.floorNames[root.car.currentIndex], "ARRIVED · IDLE");
                interval = 900;
                return;
            }

            root.demoPhase = "TRAVEL";
            root.car.currentIndex += root.car.direction;
            const remaining = Math.abs(root.car.destIndex - root.car.currentIndex);
            root.car.speedMs = remaining === 0 ? 0.0 : Math.min(2.5, 0.8 + remaining * 0.35);
            root.car.etaSec = remaining * 3;
            interval = 900;
        }
    }

    Component.onCompleted: {
        logEvent(floorNames[car.currentIndex], "CAR CALL ACCEPTED");
        logEvent(floorNames[car.currentIndex], "SYSTEM READY");
        stage.setSource(root.landscape ? "LandscapeView.qml" : "PortraitView.qml",
                        { "hmi": root });
    }

    // Landscape content is 1280×800, centered then rotated so it fills the
    // native 800×1280 window. Portrait content is 800×1280 unrotated.
    Item {
        id: stageHost
        anchors.centerIn: parent
        width: root.landscape ? 1280 : 800
        height: root.landscape ? 800 : 1280
        rotation: root.landscape ? root.stageRotation : 0

        Loader {
            id: stage
            anchors.fill: parent
            onStatusChanged: {
                if (status === Loader.Error)
                    console.error("HMI view failed to load:", source)
            }
        }

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
}
