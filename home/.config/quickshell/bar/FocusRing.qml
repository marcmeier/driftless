import QtQuick
import qs.services

// What makes a control reachable from the keyboard: put it inside the control. Tab stops here, a
// 1 px line in the accent shows it (a little outside, so it is not taken for `checked`; `inset` for
// rows that fill the popup), Enter and Space do what a click does, the arrows step (a slider, a
// segmented choice). The mouse never gives it focus, so the line only shows for the keyboard.
Item {
    id: ring

    property bool inset: false
    signal activated
    signal stepped(int by)

    anchors.fill: parent
    activeFocusOnTab: true

    Keys.onReturnPressed: ring.activated()
    Keys.onEnterPressed: ring.activated()
    Keys.onSpacePressed: ring.activated()
    Keys.onLeftPressed: ring.stepped(-1)
    Keys.onRightPressed: ring.stepped(1)
    Keys.onDownPressed: ring.stepped(-1)
    Keys.onUpPressed: ring.stepped(1)

    Rectangle {
        visible: ring.activeFocus
        anchors.fill: parent
        anchors.margins: ring.inset ? 0 : -3
        color: "transparent"
        border.width: 1
        border.color: Theme.accent
    }
}
