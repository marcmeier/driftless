import QtQuick
import qs.services

// A button in a popup: a glyph and/or a word in a 1 px frame. `accent`: filled with the accent (the
// main action); `checked`: framed in the accent (the current choice); `flat`: no frame.
Rectangle {
    id: btn

    property string icon: ""
    property string text: ""
    property bool accent: false
    property bool checked: false
    property bool flat: false
    property int iconSize: 14
    property int padX: text ? 10 : 7
    signal clicked

    implicitWidth: row.implicitWidth + padX * 2
    implicitHeight: 28
    opacity: enabled ? 1 : 0.4
    color: accent ? Theme.accent : mouse.containsMouse ? Theme.hover : "transparent"
    border.width: accent || flat && !checked ? 0 : 1
    border.color: checked ? Theme.accent : Theme.border

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7
        Icon {
            visible: btn.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: btn.icon
            size: btn.iconSize
            color: btn.accent ? Theme.accentInk : btn.checked ? Theme.accent : Theme.text
        }
        Label {
            visible: btn.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: btn.text
            font.pixelSize: 12
            color: btn.accent ? Theme.accentInk : btn.checked ? Theme.accent : Theme.text
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
