import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.services
import "../bar"

// The power menu (SUPER + SHIFT + M, the power button in the bar; wlogout before): lock, log out,
// suspend, reboot, shut down as a plain list in the middle of the focused screen, which it covers in
// the desk colour. Keys: the letter of a row, arrows and Enter, Esc or a click beside the list to go back.
//   quickshell ipc -p ~/.config/quickshell call power toggle      (open, close)
Scope {
    id: root

    property bool open: false
    property int current: 0

    readonly property var items: [
        { key: "L", glyph: "\u{F033E}", text: "Lock", danger: false, run: () => Session.lock() },
        { key: "E", glyph: "\u{F0343}", text: "Log out", danger: true, run: () => Session.logout() },
        { key: "U", glyph: "\u{F04B2}", text: "Suspend", danger: false, run: () => Session.suspend() },
        { key: "R", glyph: "\u{F0709}", text: "Reboot", danger: false, run: () => Session.reboot() },
        { key: "S", glyph: "\u{F0425}", text: "Shut down", danger: true, run: () => Session.poweroff() }
    ]

    function show() {
        if (Session.locked)
            return;
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        const target = Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0];
        if (target && win.screen !== target)
            win.screen = target;
        current = 0;
        uptime.reload();
        open = true;
    }
    function hide() {
        open = false;
    }
    function pick(i) {
        hide();
        items[i].run();
    }

    Connections {
        target: Session
        function onLockRequested() {
            root.hide();
        }
        function onPowerMenuRequested() {
            root.open ? root.hide() : root.show();
        }
    }

    IpcHandler {
        target: "power"
        function toggle(): void {
            root.open ? root.hide() : root.show();
        }
        function open(): void {
            root.show();
        }
        function close(): void {
            root.hide();
        }
    }

    // "up 3 h 12 min"
    FileView {
        id: uptime
        path: "/proc/uptime"
        readonly property int seconds: Math.floor(parseFloat(text()) || 0)
    }
    FileView {
        id: hostname
        path: "/etc/hostname"
    }
    function since(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return "up " + (d > 0 ? d + " d " + h + " h" : h > 0 ? h + " h " + m + " min" : m + " min");
    }

    PanelWindow {
        id: win

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: root.open
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "driftless-power"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            id: backdrop
            anchors.fill: parent
            color: Theme.scrim

            MouseArea {
                anchors.fill: parent
                onClicked: root.hide()
            }
        }

        Item {
            id: keys
            anchors.fill: parent
            focus: root.open
            Keys.onPressed: e => {
                const n = root.items.length;
                if (e.key === Qt.Key_Escape)
                    root.hide();
                else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab || e.key === Qt.Key_Down)
                    root.current = (root.current + 1) % n;
                else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab || e.key === Qt.Key_Up)
                    root.current = (root.current + n - 1) % n;
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
                    root.pick(root.current);
                else {
                    const i = root.items.findIndex(it => it.key === e.text.toUpperCase());
                    if (i >= 0)
                        root.pick(i);
                    else
                        return;
                }
                e.accepted = true;
            }
        }

        Column {
            anchors.centerIn: parent
            width: 260
            spacing: 8

            // who, where and since when
            Label {
                small: true
                dim: true
                text: Feeds.userName + "  ·  " + hostname.text().trim() + "  ·  " + root.since(uptime.seconds)
            }

            Rectangle {
                width: parent.width
                height: list.implicitHeight + 8
                color: Theme.card
                border.width: 1
                border.color: Theme.cardBorder

                Column {
                    id: list
                    y: 4
                    width: parent.width

                    Repeater {
                        model: root.items

                        Rectangle {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool active: root.current === index
                            readonly property color fill: modelData.danger ? Theme.crit : Theme.accent

                            x: 1
                            width: list.width - 2
                            height: 28
                            color: active ? fill : "transparent"

                            Label {
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.text
                                color: row.active ? Theme.accentInk : Theme.text
                            }
                            Label {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.key.toLowerCase()
                                color: row.active ? Theme.accentInk : Theme.dim
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.current = row.index
                                onClicked: root.pick(row.index)
                            }
                        }
                    }
                }
            }

            Label {
                small: true
                color: Theme.faint
                text: "↑ ↓  choose  ·  Enter  ·  Esc  back"
            }
        }
    }
}
