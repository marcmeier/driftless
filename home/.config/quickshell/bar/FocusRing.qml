import QtQuick
import qs.services

// What makes a control reachable from the keyboard: put it inside the control. Tab stops here, a
// 1 px line in the accent shows it (a little outside, so it is not taken for `checked`; `inset` for
// rows that fill the popup), Enter and Space do what a click does, the arrows step (a slider, a
// segmented choice). The mouse never gives it focus, so the line only shows for the keyboard. In a
// list that scrolls, the list follows it.
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

    // in a list that scrolls (sound apps, events, settings, notifications): bring it into view
    onActiveFocusChanged: {
        if (!activeFocus)
            return;
        let f = parent;
        while (f && !("flickableDirection" in f))
            f = f.parent;
        if (!f || f.contentHeight <= f.height)
            return;
        const y = ring.mapToItem(f.contentItem, 0, 0).y;
        const top = -f.topMargin, bottom = f.contentHeight - f.height + f.bottomMargin;
        if (y - 4 < f.contentY)
            f.contentY = Math.max(top, y - 4);
        else if (y + ring.height + 4 > f.contentY + f.height)
            f.contentY = Math.min(bottom, y + ring.height + 4 - f.height);
    }

    Rectangle {
        visible: ring.activeFocus
        anchors.fill: parent
        anchors.margins: ring.inset ? 0 : -3
        color: "transparent"
        border.width: 1
        border.color: Theme.accent
    }
}
