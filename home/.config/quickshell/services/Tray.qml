pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick

// The tray apps for the bar (bar/TraySeg.qml, bar/TrayPopup.qml): which show at all, and which are
// pinned to stay in the bar (the rest waits in the popup). Pins are kept per machine (Prefs
// "trayPinned", by the apps' ids). blueman's icon stays out while the bar shows Bluetooth itself
// (bar/BluetoothSeg.qml). A few seconds after the start it takes back the tray apps that do not
// register again after a restart of the shell on their own (scripts/tray-adopt).
Singleton {
    id: tray

    readonly property var pinned: Prefs.trayPinned

    function items(bar) {
        const ownBluetooth = BarLayout.members("group/status", bar.variant).includes("bluetooth");
        return SystemTray.items.values.filter(i => !(ownBluetooth && i.id === "blueman"));
    }
    function isPinned(item) {
        return pinned.includes(item.id);
    }
    function togglePin(item) {
        Prefs.set("trayPinned", isPinned(item) ? pinned.filter(id => id !== item.id) : pinned.concat([item.id]));
    }

    Timer {
        interval: 3000
        running: true
        onTriggered: adopt.running = true
    }
    Process {
        id: adopt
        command: [Quickshell.shellDir + "/scripts/tray-adopt"]
    }
}
