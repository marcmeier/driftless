import QtQuick
import Quickshell.Services.SystemTray
import qs.services

// The tray (StatusNotifierItem), folded away: the apps pinned to the bar, then an arrow that opens
// all of them in a small box (bar/TrayPopup.qml), where the pins are set. The arrow carries the
// accent square while a folded app asks for attention. services/Tray.qml decides what shows.
Item {
    id: tray

    property var bar: null
    readonly property bool compact: bar ? bar.compact : false
    readonly property var items: bar ? Tray.items(bar) : []
    readonly property var pinned: items.filter(i => Tray.isPinned(i))
    readonly property var folded: items.filter(i => !Tray.isPinned(i))
    readonly property bool calling: folded.some(i => i.status === Status.NeedsAttention)
    property bool shown: items.length > 0

    implicitWidth: row.implicitWidth + (compact ? 6 : 8)
    implicitHeight: Theme.barHeight
    visible: shown

    Row {
        id: row
        x: tray.compact ? 3 : 4
        height: parent.height
        spacing: 0

        Repeater {
            model: tray.pinned

            delegate: TrayItem {
                required property var modelData
                item: modelData
                bar: tray.bar
                iconSize: tray.compact ? 15 : 16
                width: iconSize + (tray.compact ? 12 : 14)
                height: parent.height
            }
        }

        Seg {
            id: more
            bar: tray.bar
            padL: tray.compact ? 5 : 6
            padR: tray.compact ? 5 : 6
            popupKey: "tray"
            popupComponent: Component {
                TrayPopup {}
            }
            tip: tray.folded.length ? `${tray.folded.length} more ${tray.folded.length === 1 ? "app" : "apps"} in the tray` : "Tray"
            onClicked: togglePopup()

            Item {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: arrow.width
                implicitHeight: arrow.height

                Icon {
                    id: arrow
                    text: "\u{F0140}"
                    color: tray.calling ? Theme.accent : Theme.dim
                }
                Rectangle {
                    visible: tray.calling
                    width: 5
                    height: 5
                    color: Theme.accent
                    x: arrow.width - 4
                    y: 1
                }
            }
        }
    }
}
