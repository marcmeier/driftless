import QtQuick
import qs.services

// A thing in the sync icon's popup that waits for you (SyncPopup.qml), in a frame of its own: a header
// line with what it is and a chevron, and below it, unfolded with a click on the header, what belongs
// to it (the children). So the list reads as part of "3 new packages", not as more of the popup. In the
// tone of the sync icon while it waits for you (warn), so it stands before the switches below.
Rectangle {
    id: fold

    property string text: ""
    property bool open: false
    property color tone: Theme.warn
    default property alias body: inner.data
    signal toggled

    width: parent ? parent.width : 0
    height: head.height + (open ? inner.implicitHeight + 12 : 0)
    color: "transparent"
    border.width: 1
    border.color: Qt.alpha(tone, 0.6)

    Rectangle {
        id: head
        x: 1
        y: 1
        width: parent.width - 2
        height: 32
        color: Qt.alpha(fold.tone, mouse.containsMouse ? 0.2 : 0.12)

        Label {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            text: fold.text
            bold: true
            color: fold.tone
        }
        Icon {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: fold.open ? "\u{F0143}" : "\u{F0140}"
            size: 14
            color: Theme.dim
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: fold.toggled()
        }
    }

    Column {
        id: inner
        visible: fold.open
        x: 10
        y: head.height + 6
        width: fold.width - 20
    }
}
