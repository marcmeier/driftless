import QtQuick
import qs.services

// A group of widgets on the bar: no box of its own in the plain look, only its children in a row.
Rectangle {
    id: pill

    default property alias content: row.data
    property var bar: null
    readonly property bool compact: bar ? bar.compact : false
    property bool shown: true
    property int padding: compact ? 3 : 4
    property alias spacing: row.spacing
    readonly property alias row: row

    implicitHeight: Theme.barHeight
    implicitWidth: row.implicitWidth + padding * 2
    width: implicitWidth
    visible: shown
    color: "transparent"
    clip: true

    Row {
        id: row
        x: pill.padding
        height: parent.height
        spacing: 0
    }
}
