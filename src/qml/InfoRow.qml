import QtQuick

Item {
    id: info
    property string label: ""
    property string value: ""
    property color valueColor: "#142033"
    height: 26

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: info.label
        color: "#3A5168"
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
