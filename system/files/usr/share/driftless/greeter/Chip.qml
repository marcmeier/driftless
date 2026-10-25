import QtQuick

// A quiet button at the bottom of the login screen: an icon and maybe a word, on a grey on hover.
Rectangle {
    id: chip
    required property var theme
    property string icon
    property string label
    property bool clickable: true
    signal clicked
    width: chipRow.implicitWidth + 16
    height: 26
    color: clickable && chipMouse.containsMouse ? chip.theme.hover : "transparent"
    Row {
        id: chipRow
        anchors.centerIn: parent
        spacing: 8
        Text {
            anchors.verticalCenter: parent.verticalCenter
            font.family: chip.theme.font
            font.pixelSize: 14
            color: chip.clickable && chipMouse.containsMouse ? chip.theme.text : chip.theme.dim
            text: chip.icon
            renderType: Text.NativeRendering
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: chip.label !== ""
            font.family: chip.theme.font
            font.pixelSize: 12
            color: chip.clickable && chipMouse.containsMouse ? chip.theme.text : chip.theme.dim
            text: chip.label
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
        }
    }
    MouseArea {
        id: chipMouse
        anchors.fill: parent
        enabled: chip.clickable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
