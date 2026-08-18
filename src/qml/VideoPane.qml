import QtQuick
import ElevatorHmi

// Video / advertising pane (design: Vertical Video / Landscape Video).
//
// Two media paths, and only one of them can reach the glass today:
//
//   IMAGES — LIVE. `Image` is a raster blit, so stills decode and display fine
//     under the software renderer on linuxfb. This is the ad slideshow.
//
//   CLIPS — SOFTWARE-DECODED (DEMO ONLY). BLK-015 blocks the VPU/DRM-plane path,
//     so frames are decoded on the CPU and blitted through VideoSurface into the
//     same framebuffer. There is no H.264 decoder in this image (libav is
//     LICENSE_FLAGS=commercial), so demo clips must be MJPEG. If a clip cannot be
//     decoded the pane says so instead of sitting blank.
//
// Stage 2 (after BLK-015): put VideoOutput in this same well so it inherits the
// landscape rotation. Do NOT use a separate kmssink overlay — a DRM plane lives
// in physical 800×1280 coordinates and would not follow QML `rotation`.
//
// Software-renderer safe: hatch is rotated Rectangles, no shaders.

Item {
    id: pane
    property var hmi
    clip: true

    readonly property var src: media
    readonly property bool haveCard: src && src.mounted
    readonly property int clipCount: src ? src.clipCount : 0
    readonly property string clipName: src ? src.clipName : ""
    readonly property string cardStatus: src ? src.status : "NO CARD"

    readonly property int imageCount: src ? src.imageCount : 0
    readonly property bool haveImages: src ? src.hasImages : false
    readonly property string imageName: src ? src.imageName : ""
    readonly property int imageIndex: src ? src.imageIndex : 0

    readonly property color ink: hmi ? hmi.ink : "#142033"
    readonly property color inkMute: hmi ? hmi.inkMute : "#6A8198"
    readonly property color inkDim: hmi ? hmi.inkDim : "#3A5168"
    readonly property color red: hmi ? hmi.red : "#E11D48"
    readonly property color green: hmi ? hmi.green : "#059669"
    readonly property color amber: hmi ? hmi.amber : "#F97316"
    readonly property color line: hmi ? hmi.line : "#B7C9DC"
    readonly property color well: hmi ? hmi.bgElev2 : "#DCE8F4"
    readonly property color hatch: hmi ? hmi.lineSoft : "#D0DCEC"
    readonly property string monoFont: hmi ? hmi.monoFont : "Liberation Mono"

    // True once a still is actually decoded — only then do we hide the chrome
    // underneath. A file that fails to decode must NOT leave a blank pane.
    readonly property bool showingVideo: src ? src.videoShowing : false
    readonly property string videoError: src ? src.videoError : ""
    // Video wins the well when it is decoding; stills are the fallback.
    readonly property bool showingImage: slide.status === Image.Ready && pane.haveImages
                                         && !pane.showingVideo
    readonly property bool showingMedia: pane.showingVideo || pane.showingImage

    readonly property color statusDot: pane.cardStatus === "READY" ? pane.green
                                       : pane.cardStatus === "EMPTY" ? pane.amber
                                       : pane.red

    readonly property string statusLabel: {
        if (pane.cardStatus !== "READY")
            return pane.cardStatus === "EMPTY" ? "SD · EMPTY" : "NO CARD";
        var bits = [];
        if (pane.imageCount > 0)
            bits.push(pane.imageCount + (pane.imageCount === 1 ? " AD" : " ADS"));
        if (pane.clipCount > 0)
            bits.push(pane.clipCount + (pane.clipCount === 1 ? " CLIP" : " CLIPS"));
        return "READY · " + bits.join(" · ");
    }

    // Centre plate text, shown only when there is no still on screen.
    readonly property string subLabel: {
        if (!pane.haveCard)
            return "NO CARD";
        if (pane.clipCount > 0 && pane.videoError !== "")
            return "MJPEG ONLY — NO H.264 DECODER";
        if (pane.clipCount > 0)
            return pane.clipName.toUpperCase();
        return "SD CARD · EMPTY";
    }

    readonly property string footerLabel: {
        if (pane.showingVideo)
            return "—  " + pane.clipName.toUpperCase() + "  —";
        if (pane.showingImage)
            return "—  " + pane.imageName.toUpperCase() + "  —";
        if (pane.clipCount > 0 && pane.videoError !== "")
            return "—  " + pane.clipName.toUpperCase() + "  ·  CANNOT DECODE  —";
        if (pane.clipCount > 0)
            return "—  " + pane.clipName.toUpperCase() + "  ·  DECODING…  —";
        return "—  NO CLIP LOADED  —";
    }

    Rectangle {
        anchors.fill: parent
        color: pane.well

        // ---- Hatch (visible whenever there is no decoded frame) ----------
        Item {
            anchors.fill: parent
            clip: true
            visible: !pane.showingMedia
            Repeater {
                model: 46
                delegate: Rectangle {
                    required property int index
                    width: 2
                    height: pane.height * 3
                    color: pane.hatch
                    x: index * 34 - 320
                    y: -pane.height
                    rotation: 30
                    transformOrigin: Item.TopLeft
                }
            }
        }

        // ---- Video (software-decoded, demo only) --------------------------
        VideoSurface {
            anchors.fill: parent
            backend: pane.src
            visible: pane.showingVideo
        }

        // ---- Ad slideshow (LIVE path) ------------------------------------
        Image {
            id: slide
            anchors.fill: parent
            source: pane.src ? pane.src.imageSource : ""
            asynchronous: true
            // Ads are large photos and this board has 2 GB with no GPU; cap the
            // decode to the pane so a 12 MP JPEG does not allocate 48 MB.
            sourceSize.width: Math.max(1, Math.round(pane.width))
            sourceSize.height: Math.max(1, Math.round(pane.height))
            // Fill the well: an ad with letterboxing looks like a bug on a
            // fixed-function display.
            fillMode: Image.PreserveAspectCrop
            cache: false
            visible: pane.showingImage

            // Fade each slide in. The source swap itself is instant, so animate
            // on the Ready transition rather than on the property.
            onStatusChanged: if (status === Image.Ready) slideFade.restart()
            NumberAnimation {
                id: slideFade
                target: slide
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 400
                easing.type: Easing.InOutQuad
            }
        }

        // ---- Header ------------------------------------------------------
        Row {
            x: 20
            y: 18
            spacing: 8
            Rectangle {
                width: 8; height: 8; radius: 4
                color: pane.statusDot
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: pane.statusLabel
                color: pane.showingMedia ? "white" : pane.ink
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
            text: pane.showingVideo ? "PLAYING · SOFTWARE DECODE"
                  : pane.showingImage ? ((pane.imageIndex + 1) + " / " + pane.imageCount)
                  : "SAFETY · 720P"
            color: pane.showingMedia ? "white" : pane.inkMute
            font.family: pane.monoFont
            font.pixelSize: 11
            font.letterSpacing: 2
        }

        // ---- NO SOURCE plate (hidden while a still is up) ------------------
        Column {
            anchors.centerIn: parent
            spacing: 16
            visible: !pane.showingMedia

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
                text: pane.subLabel
                color: pane.inkMute
                font.family: pane.monoFont
                font.pixelSize: 11
                font.letterSpacing: 2
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // ---- Transport (decorative: no touch controller wired) -------------
        Row {
            x: 20
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            spacing: 12
            visible: !pane.showingMedia

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

        // ---- Footer caption ------------------------------------------------
        // Over a photo this needs its own backing or it becomes unreadable.
        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 14
            anchors.bottomMargin: 24
            width: footer.implicitWidth + 20
            height: footer.implicitHeight + 12
            radius: 2
            color: pane.showingMedia ? Qt.rgba(0, 0, 0, 0.45) : "transparent"

            Text {
                id: footer
                anchors.centerIn: parent
                text: pane.footerLabel
                color: pane.showingMedia ? "white" : pane.inkMute
                font.family: pane.monoFont
                font.pixelSize: 11
                font.letterSpacing: 2
            }
        }
    }
}
