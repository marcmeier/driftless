import QtQuick

// The buttons at the foot of a popup or a part of it, on the right like every control in a popup, the
// one that confirms last. A button that opens something else (a window, a terminal) ends in "…".
Item {
    default property alias buttons: row.data

    width: parent ? parent.width : 0
    height: row.height

    Row {
        id: row
        anchors.right: parent.right
        spacing: 8
    }
}
