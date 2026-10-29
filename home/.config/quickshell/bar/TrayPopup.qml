import QtQuick
import qs.services

// The tray's box: every tray app in a small grid of bar-sized icons, the pinned ones (also in the
// bar) first. The pin on an icon (on hover) keeps it in the bar or folds it back in here. A click
// activates the app and closes the box; a right click opens its menu below the icons, the icons stay
// usable (another right click switches to that app's menu, the same one closes it).
Item {
    id: root

    property var popup
    property var bar
    readonly property int pad: 4
    readonly property var all: bar ? Tray.items(bar) : []
    readonly property var items: all.filter(i => Tray.isPinned(i)).concat(all.filter(i => !Tray.isPinned(i)))
    property var chosen: null
    readonly property var menuItem: chosen && all.includes(chosen) ? chosen : null

    implicitWidth: menuItem ? Math.max(grid.implicitWidth, 220) : grid.implicitWidth
    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: 4

        Grid {
            id: grid
            // centred, so the icons stay where they were when the menu widens the box
            anchors.horizontalCenter: parent.horizontalCenter
            columns: Math.max(1, Math.min(6, root.items.length))

            Repeater {
                model: root.items

                delegate: TrayItem {
                    required property var modelData
                    item: modelData
                    bar: root.bar
                    inPopup: true
                    pinned: Tray.isPinned(modelData)
                    selected: root.menuItem === modelData
                    iconSize: root.bar && root.bar.compact ? 15 : 16
                    width: iconSize + 14
                    height: Theme.barHeight
                    onActivated: root.popup.close()
                    onPinClicked: Tray.togglePin(modelData)
                    onMenuRequested: root.chosen = root.menuItem === modelData ? null : modelData
                }
            }
        }

        Rectangle {
            visible: !!root.menuItem
            width: parent.width
            height: 1
            color: Theme.separator
        }

        // the app's name over its menu
        Label {
            visible: !!root.menuItem
            x: 6
            width: parent.width - 12
            small: true
            dim: true
            elide: Text.ElideRight
            text: root.menuItem ? (root.menuItem.tooltipTitle || root.menuItem.title || root.menuItem.id) : ""
        }

        TrayMenu {
            visible: !!root.menuItem
            width: parent.width
            popup: root.popup
            bar: root.bar
            menu: root.menuItem ? root.menuItem.menu : null
        }
    }
}
