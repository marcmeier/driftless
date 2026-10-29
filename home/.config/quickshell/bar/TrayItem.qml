import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.services

// One tray app (StatusNotifierItem), in the bar or in the tray's popup: left click activates the app
// (or opens its menu when that is all it has) · right click: its menu, drawn like the rest of the
// shell (in the tray's box: below the icons, so the box stays) · middle: its secondary action ·
// wheel: passed on. In the box it carries a pin as well.
Item {
    id: slot

    property var item: null
    property var bar: null
    property int iconSize: 16
    property bool inPopup: false
    property bool pinned: false
    property bool selected: false      // its menu is open below (in the box)
    readonly property bool hovered: mouse.containsMouse || pin.containsMouse
    readonly property string title: item ? (item.tooltipTitle || item.title || item.id) : ""

    signal activated
    signal pinClicked
    signal menuRequested

    Rectangle {
        anchors.fill: parent
        anchors.bottomMargin: slot.inPopup ? 0 : 1
        color: Theme.hover
        visible: slot.hovered || slot.selected
    }

    IconImage {
        anchors.centerIn: parent
        implicitSize: slot.iconSize
        source: slot.item ? slot.item.icon : ""
        opacity: slot.item && slot.item.status === Status.Passive ? 0.5 : 1
    }

    // asks for attention: a small square in the accent
    Rectangle {
        visible: !!slot.item && slot.item.status === Status.NeedsAttention
        width: 5
        height: 5
        color: Theme.accent
        x: parent.width / 2 + slot.iconSize / 2 - 4
        y: parent.height / 2 - slot.iconSize / 2 - 2
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        property real wheelRest: 0

        function openMenu() {
            if (!slot.item.hasMenu)
                return;
            if (slot.inPopup)
                slot.menuRequested();
            else
                slot.bar.togglePopup(slot, slot.bar.trayMenu, "tray:" + slot.item.id, { menu: slot.item.menu });
        }

        onClicked: e => {
            slot.bar.hideTip(slot);
            if (e.button === Qt.RightButton) {
                openMenu();
            } else if (e.button === Qt.MiddleButton) {
                slot.item.secondaryActivate();
            } else if (slot.item.onlyMenu) {
                openMenu();
            } else {
                slot.item.activate();
                slot.activated();
            }
        }
        onWheel: w => {
            wheelRest += w.angleDelta.y;
            if (Math.abs(wheelRest) >= 120) {
                slot.item.scroll(Math.trunc(wheelRest / 120), false);
                wheelRest = 0;
            }
        }
        onContainsMouseChanged: {
            const m = slot.item;
            if (slot.inPopup || !m)
                return;
            if (containsMouse && slot.title)
                slot.bar.showTip(slot, () => Apps.esc(slot.title)
                    + (m.tooltipDescription ? `<br><font color='${Theme.dim}'>${m.tooltipDescription}</font>` : ""));
            else
                slot.bar.hideTip(slot);
        }
    }

    // the pin (popup only): pinned apps stay in the bar; shown on hover, and always while pinned
    MouseArea {
        id: pin
        visible: slot.inPopup && (slot.hovered || slot.pinned)
        width: 12
        height: 12
        anchors.top: parent.top
        anchors.right: parent.right
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: slot.pinClicked()

        Icon {
            anchors.centerIn: parent
            size: 9
            text: slot.pinned ? "\u{F0403}" : "\u{F0931}"
            color: slot.pinned ? Theme.accent : pin.containsMouse ? Theme.text : Theme.dim
        }
    }
}
