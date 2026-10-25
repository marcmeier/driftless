import QtQuick
import Quickshell.Hyprland
import qs.services

// Workspaces 1 to 5 and a "…" button for the rest, straight from Hyprland's IPC. The active one is
// bright with an accent line below it (a grey one on a screen without focus), workspaces with windows
// are text, empty ones faint, urgent ones red. Click: go there · wheel: next/previous.
Pill {
    id: pill

    readonly property int last: 5
    readonly property var monitor: bar ? bar.monitor : null
    readonly property var activeWs: monitor && monitor.activeWorkspace ? monitor.activeWorkspace : Hyprland.focusedWorkspace
    readonly property int active: activeWs ? activeWs.id : 0
    // monitor.focused is not kept up to date by Quickshell: compare with the focused monitor instead
    readonly property bool focusedHere: !monitor || !Hyprland.focusedMonitor || Hyprland.focusedMonitor.name === monitor.name
    readonly property var all: Hyprland.workspaces.values

    function windows(id) {
        const w = all.find(w => w.id === id);
        return w ? w.toplevels.values.length : 0;
    }
    function urgent(id) {
        const w = all.find(w => w.id === id);
        return !!(w && (w.urgent || w.toplevels.values.some(t => t.urgent)));
    }
    readonly property var extra: all.filter(w => w.id > last && (w.toplevels.values.length > 0 || w.id === active))
                                    .map(w => w.id).sort((a, b) => a - b)

    padding: compact ? 3 : 4

    // after a start or reload of the shell Hyprland's state only comes with the next event, and a
    // request right at the start can get lost: ask again until the active workspace is known
    Timer {
        property int tries: 0
        running: pill.active === 0 && tries < 20
        interval: tries === 0 ? 0 : 500
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            tries++;
            Hyprland.refreshMonitors();
            Hyprland.refreshWorkspaces();
        }
    }

    Item {
        id: box
        implicitWidth: buttons.implicitWidth
        implicitHeight: Theme.barHeight

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            property real rest: 0
            onWheel: event => {
                rest += event.angleDelta.y;
                if (Math.abs(rest) >= 120) {
                    Actions.focusWorkspace(rest > 0 ? "e-1" : "e+1");
                    rest = 0;
                }
            }
        }

        Row {
            id: buttons
            height: parent.height
            spacing: 0

            Repeater {
                id: rep
                model: pill.last

                delegate: WsButton {
                    required property int index
                    num: index + 1
                    label: String(index + 1)
                    isActive: pill.active === num
                    occupied: pill.windows(num) > 0
                    isUrgent: pill.urgent(num) && !isActive
                    compact: pill.compact
                    onActivated: Actions.focusWorkspace(num)
                }
            }

            WsButton {
                id: more
                visible: pill.extra.length > 0
                num: 0
                label: pill.active > pill.last ? "…" + pill.active : "…"
                isActive: pill.active > pill.last
                occupied: true
                isUrgent: pill.extra.some(id => pill.urgent(id)) && !isActive
                compact: pill.compact
                tipText: "Workspaces: " + pill.extra.join(", ")
                bar: pill.bar
                onActivated: Actions.focusWorkspace("e+1")
                onSecondary: Actions.focusWorkspace("e-1")
            }
        }
    }

    component WsButton: Item {
        id: btn
        property int num
        property string label
        property bool isActive
        property bool occupied
        property bool isUrgent
        property bool compact
        readonly property bool focusedHere: pill.focusedHere
        property string tipText: ""
        property var bar: null
        signal activated
        signal secondary

        readonly property int pad: compact ? 6 : 8
        implicitWidth: Math.max(text.implicitWidth + pad * 2, compact ? 20 : 24)
        width: implicitWidth
        height: parent.height

        Rectangle {
            anchors.fill: parent
            anchors.bottomMargin: 1
            color: Theme.hover
            visible: mouse.containsMouse && !btn.isActive
        }
        // the line under the active (or urgent) one
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            height: 2
            visible: btn.isActive || btn.isUrgent
            color: btn.isUrgent ? Theme.crit : btn.focusedHere ? Theme.accent : Theme.dim
        }

        Label {
            id: text
            anchors.centerIn: parent
            text: btn.label
            bold: btn.isActive
            font.pixelSize: btn.compact ? 12 : 13
            color: btn.isUrgent ? Theme.crit : btn.isActive ? Theme.strong
                 : btn.occupied || mouse.containsMouse ? Theme.text : Theme.faint
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: e => e.button === Qt.RightButton ? btn.secondary() : btn.activated()
            onContainsMouseChanged: {
                if (!btn.bar || !btn.tipText)
                    return;
                if (containsMouse)
                    btn.bar.showTip(btn, () => btn.tipText);
                else
                    btn.bar.hideTip(btn);
            }
        }
    }
}
