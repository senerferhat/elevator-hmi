import QtQuick

Column {
    id: stat
    property string label: ""
    property string value: ""
    property string unit: ""
    property color valueColor: "#142033"
    spacing: 4

    Text {
        text: stat.label
        color: "#6A8198"
        font.family: "Liberation Mono"
        font.pixelSize: 10
        font.letterSpacing: 2
    }
    Row {
        spacing: 4
        Text {
            text: stat.value
            color: stat.valueColor
            font.family: "Liberation Mono"
            font.pixelSize: 18
            font.bold: true
        }
        Text {
            text: stat.unit
            color: "#6A8198"
            font.family: "Liberation Mono"
            font.pixelSize: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
        }
    }
}
