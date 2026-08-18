import QtQuick

Item {
    id: info
    property string label: ""
    property string value: ""
    property color valueColor: "#E8ECF2"
    height: 26

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: info.label
        color: "#9AA3B2"
        font.family: "Liberation Mono"
        font.pixelSize: 11
        font.letterSpacing: 2
    }
    Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: info.value
        color: info.valueColor
        font.family: "Liberation Mono"
        font.pixelSize: 12
        font.bold: true
    }
}
