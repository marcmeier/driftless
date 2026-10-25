import QtQuick
import qs.services

// A bar that shows how much of something is used (0..100), in the accent, orange from 70, red from 90.
Rectangle {
    id: meter

    property real percent: 0
    property color tone: Theme.levelColor(percent)

    implicitWidth: 260
    implicitHeight: 4
    color: Theme.track

    Rectangle {
        width: parent.width * Math.min(meter.percent, 100) / 100
        height: parent.height
        color: meter.tone
    }
}
