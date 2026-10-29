pragma Singleton

import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

// The tray apps for the bar (bar/TraySeg.qml, bar/TrayPopup.qml): which show at all, and which are
// pinned to stay in the bar (the rest waits in the popup). Pins are kept per machine (Prefs
// "trayPinned", by the apps' ids). blueman's icon stays out while the bar shows Bluetooth itself
// (bar/BluetoothSeg.qml).
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
}
