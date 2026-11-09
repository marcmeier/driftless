import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.services

// The notification cards at the top right of the focused screen, right below the bar, newest on top
// (four at most). They slide in from the edge, leave after their time (not while the pointer is on
// them) and stay in the bell's list. Do not disturb lets only critical ones through.
//   quickshell ipc -p ~/.config/quickshell call notifications dnd toggle    (on, off, toggle)
//   quickshell ipc -p ~/.config/quickshell call notifications clear
Scope {
    id: root

    // a new card shows on the screen you are working on (the ones still there come along)
    function place() {
        Actions.toFocusedScreen(win);
    }
    Connections {
        target: Notifs.popups
        function onRowsInserted() {
            root.place();
        }
    }

    IpcHandler {
        target: "notifications"

        // on, off or toggle; answers the state
        function dnd(mode: string): string {
            Notifs.setDnd(mode === "on" ? true : mode === "off" ? false : !Notifs.dnd);
            return Notifs.dnd ? "on" : "off";
        }
        function clear(): void {
            Notifs.clear();
        }
        // "3 (1 new), do not disturb off"
        function state(): string {
            return `${Notifs.count} (${Notifs.unread} new), do not disturb ${Notifs.dnd ? "on" : "off"}`;
        }
    }

    PanelWindow {
        id: win

        anchors {
            top: true
            right: true
        }
        margins.top: Theme.barGap + Theme.barHeight + 8
        // room around the cards for their shadows; the cards keep their place under the bar's end
        margins.right: 0
        implicitWidth: 440 + Theme.barSide + 16
        // tall enough for four cards; only the cards take clicks (mask), the rest lets them through
        implicitHeight: Math.round((screen ? screen.height : 1200) * 0.8)
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: (Notifs.popups.count > 0 || list.count > 0 || hideDelay.running) && !Notifs.listOpen
        mask: Region {
            item: list.contentItem
        }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "driftless-notifications"
        // keys only after a click into a card's answer field (OnDemand never takes them on its own)
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        // a moment before the window goes (the list may refill at once), and the last card slides out
        Timer {
            id: hideDelay
            interval: Theme.leave + 50
            running: Notifs.popups.count === 0
        }

        ListView {
            id: list
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: Theme.barSide
            interactive: false
            spacing: 8
            model: Notifs.popups

            // a new card fades in and slides the last few pixels from the side
            add: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.enter
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "x"
                    from: 2 * Theme.rise
                    to: 0
                    duration: Theme.enter
                    easing.type: Easing.OutCubic
                }
            }
            // and one that goes slides out to the side while it fades
            remove: Transition {
                NumberAnimation {
                    property: "opacity"
                    to: 0
                    duration: Theme.leave
                    easing.type: Easing.InCubic
                }
                NumberAnimation {
                    property: "x"
                    to: 12 * Theme.rise
                    duration: Theme.leave
                    easing.type: Easing.InCubic
                }
            }
            displaced: Transition {
                NumberAnimation {
                    property: "y"
                    duration: Theme.enter
                    easing.type: Easing.OutCubic
                }
            }

            delegate: NotifCard {
                width: ListView.view.width
                popup: true
                onExpired: Notifs.hidePopup(nid)
            }

        }
    }
}
