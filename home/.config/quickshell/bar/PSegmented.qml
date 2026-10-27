import QtQuick
import qs.services

// One choice out of a few, side by side in one 1 px frame (dark / light / auto): the current one raised
// and in the accent. `options`: [[value, word, glyph], ...] (the glyph may be left out); `picked(value)`
// on a click on another one; `current` follows the thing.
Rectangle {
    id: seg

    property var options: []
    property string current: ""
    signal picked(string value)

    implicitWidth: row.implicitWidth + 2
    implicitHeight: 28
    color: "transparent"
    border.width: 1
    border.color: Theme.border

    Row {
        id: row
        x: 1
        y: 1
        height: parent.height - 2
        Repeater {
            model: seg.options
            Rectangle {
                id: cell
                required property var modelData
                required property int index
                readonly property bool on: seg.current === modelData[0]
                width: cellRow.implicitWidth + 20
                height: row.height
                color: on ? Theme.raised : cellMouse.containsMouse ? Theme.hover : "transparent"

                // the line between two choices
                Rectangle {
                    visible: cell.index > 0
                    width: 1
                    height: parent.height
                    color: Theme.border
                }
                Row {
                    id: cellRow
                    anchors.centerIn: parent
                    spacing: 6
                    Icon {
                        visible: !!cell.modelData[2]
                        anchors.verticalCenter: parent.verticalCenter
                        text: cell.modelData[2] || ""
                        size: 13
                        color: cell.on ? Theme.accent : Theme.dim
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: cell.modelData[1]
                        font.pixelSize: 12
                        color: cell.on ? Theme.accent : Theme.text
                    }
                }
                MouseArea {
                    id: cellMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: cell.on ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: if (!cell.on) seg.picked(cell.modelData[0])
                }
            }
        }
    }
}
