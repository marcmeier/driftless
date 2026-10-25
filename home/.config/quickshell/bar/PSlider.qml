import QtQuick
import qs.services

// A level from 0 to 1: drag, click or turn the wheel. `moved(value)` while you change it; `value`
// follows the thing it controls.
Item {
    id: slider

    property real value: 0
    property bool dim: false
    property real step: 0.02
    readonly property real shown: drag.pressed ? dragValue : value
    property real dragValue: 0
    signal moved(real value)

    implicitWidth: 240
    implicitHeight: 22

    function set(v) {
        v = Math.max(0, Math.min(1, v));
        dragValue = v;
        moved(v);
    }

    // a 2 px line, the level in the accent (grey while muted), a small upright knob
    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 2
        color: Theme.track

        Rectangle {
            width: track.width * slider.shown
            height: parent.height
            color: slider.dim ? Theme.dim : Theme.accent
        }
    }

    Rectangle {
        id: knob
        width: drag.pressed || drag.containsMouse ? 4 : 2
        height: 12
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(slider.width - width, slider.width * slider.shown - width / 2))
        color: Theme.knob
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        anchors.topMargin: -4
        anchors.bottomMargin: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: m => slider.set(m.x / slider.width)
        onPositionChanged: m => {
            if (pressed)
                slider.set(m.x / slider.width);
        }
        onWheel: w => slider.set(slider.value + (w.angleDelta.y > 0 ? slider.step : -slider.step))
    }
}
