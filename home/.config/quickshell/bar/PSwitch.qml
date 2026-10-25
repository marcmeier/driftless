import QtQuick
import qs.services

// An on/off switch in a popup (Wi-Fi, Bluetooth): a framed box, the square on the right and the box in
// the accent when on. `toggled()` on a click; `checked` follows the thing.
Rectangle {
    id: sw

    property bool checked: false
    signal toggled

    implicitWidth: 32
    implicitHeight: 16
    color: checked ? Theme.accent : "transparent"
    border.width: 1
    border.color: checked ? Theme.accent : Theme.fieldBorder

    Rectangle {
        width: 10
        height: 10
        y: 3
        x: sw.checked ? parent.width - width - 3 : 3
        color: sw.checked ? Theme.accentInk : Theme.dim
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled()
    }
}
