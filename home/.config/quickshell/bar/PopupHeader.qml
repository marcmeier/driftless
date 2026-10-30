import QtQuick
import qs.services

// The first line of a popup, the same in each (the sync icon's popup set it): its sign, dimmed, and
// its name in bold on the left; on the right in small how it stands, or a control (the children, a
// switch or a button) in its place.
Item {
    id: head

    property string icon: ""            // a glyph; none: the driftless mark
    property string title: ""
    property string status: ""
    property color statusColor: Theme.faint
    default property alias control: slot.data

    width: parent ? parent.width : 0
    height: Math.max(22, slot.childrenRect.height)

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        DriftlessMark {
            visible: head.icon === ""
            anchors.verticalCenter: parent.verticalCenter
            size: 16
            color: Theme.dim
        }
        Icon {
            visible: head.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: head.icon
            size: 16
            color: Theme.dim
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: head.title
            bold: true
        }
    }
    Label {
        visible: slot.children.length === 0
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        small: true
        color: head.statusColor
        text: head.status
    }
    Item {
        id: slot
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
}
