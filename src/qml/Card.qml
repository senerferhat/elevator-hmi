import QtQuick

// Bordered panel chrome used by DOOR / LOAD / DIAGNOSTICS / SERVICE / ACTIVITY.
// Colours are the design tokens (hardcoded so this file does not depend on a
// singleton). Software-renderer safe: no layer, no ShaderEffect.

Rectangle {
    id: card
    property string title: ""
    property string badge: ""
    property color badgeColor: "#9AA3B2"
    default property alias content: body.data

    color: "#15181D"
    border.color: "#1E232B"
    border.width: 1
    radius: 2

    Text {
        x: 18
        y: 16
        text: card.title
        color: "#9AA3B2"
        font.family: "Liberation Mono"
        font.pixelSize: 11
        font.letterSpacing: 3
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 18
        y: 16
        text: card.badge
        color: card.badgeColor
        font.family: "Liberation Mono"
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
