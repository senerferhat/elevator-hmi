import QtQuick

// White card on the daylight field, with a colour stripe keyed off the title.
// Software-renderer safe: no layer, no ShaderEffect.

Rectangle {
    id: card
    property string title: ""
    property string badge: ""
    property color badgeColor: "#3A5168"
    default property alias content: body.data

    readonly property color stripe: {
        if (title === "DOOR") return "#0D9488"
        if (title === "LOAD") return "#F97316"
        if (title === "DIAGNOSTICS") return "#1D4ED8"
        if (title === "SERVICE") return "#059669"
        if (title === "ACTIVITY") return "#D97706"
        return "#1D4ED8"
    }

    color: "#FFFFFF"
    border.color: "#B7C9DC"
    border.width: 1
    radius: 6

    Rectangle {
        width: 7
        height: parent.height
        color: card.stripe
        radius: 6
        // Cover the right corners of the stripe so only the left is rounded.
        Rectangle {
            anchors.right: parent.right
            width: 4
            height: parent.height
            color: card.stripe
        }
    }

    Rectangle {
        x: 7
        width: parent.width - 7
        height: 42
        color: card.stripe
        opacity: 0.10
    }

    Text {
        x: 22
        y: 14
        text: card.title
        color: card.stripe
        font.family: "Liberation Mono"
        font.pixelSize: 12
        font.letterSpacing: 3
        font.bold: true
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 16
        y: 14
        text: card.badge
        color: card.badgeColor
        font.family: "Liberation Mono"
        font.pixelSize: 11
        font.letterSpacing: 2
        font.bold: true
    }
    Item {
        id: body
        anchors.fill: parent
        anchors.topMargin: 42
        anchors.leftMargin: 22
        anchors.rightMargin: 16
        anchors.bottomMargin: 14
    }
}
