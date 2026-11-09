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
    signal pinClicked(bool byKey)
    signal menuRequested(bool byKey)

    // in the bar a stop of the keyboard (Super+B) like every part (Seg): Enter does what a left
    // click does; what Bar.qml asks of a part. Registered once inPopup is known.
    readonly property bool interactive: !inPopup
    readonly property string tip: slot.item ? Apps.esc(slot.title)
        + (slot.item.tooltipDescription ? `<br><font color='${Theme.dim}'>${slot.item.tooltipDescription}</font>` : "") : ""
    signal clicked(int button)
    onClicked: button => button === Qt.RightButton ? mouse.openMenu() : mouse.primary()
    Component.onCompleted: if (bar && !inPopup) bar.registerSeg(slot)
    Component.onDestruction: if (bar && !inPopup) bar.unregisterSeg(slot)

    Rectangle {
        anchors.fill: parent
        anchors.bottomMargin: slot.inPopup ? 0 : 1
        color: Theme.hover
        opacity: slot.hovered || slot.selected ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.quick } }
    }

    // an icon name the icon theme does not know draws Qt's magenta squares: then the icon of the app's
    // desktop entry, else its glyph (Apps). Pixmaps, files and an app's own theme path stay as they come.
    readonly property string iconSource: {
        const src = Apps.knownIcon(item ? item.icon : "");
        if (src || !item)
            return src;
        const entry = DesktopEntries.heuristicLookup(item.id || item.title || "");
        return entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : "";
    }

    IconImage {
        visible: slot.iconSource !== ""
        anchors.centerIn: parent
        implicitSize: slot.iconSize
        source: slot.iconSource
        opacity: slot.item && slot.item.status === Status.Passive ? 0.5 : 1
    }
    Icon {
        visible: slot.iconSource === ""
        anchors.centerIn: parent
        text: Apps.lookup(slot.item ? slot.item.id : "").glyph
        size: slot.iconSize
        color: Theme.dim
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

        function openMenu(byKey) {
            if (!slot.item.hasMenu)
                return;
            if (slot.inPopup)
                slot.menuRequested(!!byKey);
            else
                slot.bar.togglePopup(slot, slot.bar.trayMenu, "tray:" + slot.item.id, { menu: slot.item.menu });
        }

        onClicked: e => {
            slot.bar.hideTip(slot);
            if (e.button === Qt.RightButton) {
                openMenu();
            } else if (e.button === Qt.MiddleButton) {
                slot.item.secondaryActivate();
            } else {
                primary();
            }
        }
        // a left click, Enter in the box
        function primary() {
            if (slot.item.onlyMenu) {
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
                slot.bar.showTip(slot, () => slot.tip);
            else
                slot.bar.hideTip(slot);
        }
    }

    // where the bar's keyboard is (Super+B): the line of a focus, as on every part
    Rectangle {
        anchors.fill: parent
        anchors.bottomMargin: 1
        visible: !slot.inPopup && !!slot.bar && slot.bar.navSeg === slot
        color: "transparent"
        border.width: 1
        border.color: Theme.accent
    }

    // the keyboard, in the box: Enter does what a click does, the menu key or Shift+F10 opens the
    // menu, P sets or takes the pin
    function takeFocus() {
        ring.forceActiveFocus();
    }
    FocusRing {
        id: ring
        visible: slot.inPopup
        inset: true
        onActivated: mouse.primary()
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Menu || (e.key === Qt.Key_F10 && (e.modifiers & Qt.ShiftModifier))) {
                mouse.openMenu(true);
                e.accepted = true;
            } else if (e.key === Qt.Key_P && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                slot.pinClicked(true);
                e.accepted = true;
            }
        }
    }

    // the pin (popup only): pinned apps stay in the bar; shown on hover or focus, and always while pinned
    MouseArea {
        id: pin
        visible: slot.inPopup && (slot.hovered || ring.activeFocus || slot.pinned)
        width: 12
        height: 12
        anchors.top: parent.top
        anchors.right: parent.right
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: slot.pinClicked(false)

        Icon {
            anchors.centerIn: parent
            size: 9
            text: slot.pinned ? "\u{F0403}" : "\u{F0931}"
            color: slot.pinned ? Theme.accent : pin.containsMouse ? Theme.text : Theme.dim
        }
    }
}
