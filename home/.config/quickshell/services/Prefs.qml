pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// This machine's choices in the settings beyond the look and the bar (scripts/prefs.py writes them to
// ~/.local/state/driftless-shell/settings.json, only what was changed): the shell's own here, with
// their defaults; the idle times and the input options go to hypridle and Hyprland.
Singleton {
    id: prefs

    readonly property string script: Quickshell.shellDir + "/scripts/prefs.py"
    property var stored: ({})

    function value(key, fallback) {
        return stored[key] !== undefined ? stored[key] : fallback;
    }

    // the clock in the bar
    readonly property bool clock24: value("clock24", true)
    readonly property bool clockSeconds: value("clockSeconds", false)
    readonly property bool clockDate: value("clockDate", true)
    // the night light (services/NightLight.qml): off, sun (from sunset to sunrise) or on; its warmth in kelvin
    readonly property string nightLight: value("nightLight", "off")
    readonly property int nightTemp: value("nightTemp", 4000)
    // notifications that come while a fullscreen window is up wait for it (else they pop up)
    readonly property bool holdInFullscreen: value("holdInFullscreen", true)
    // the tray apps that stay in the bar, by their ids (the rest waits behind the arrow; services/Tray.qml)
    readonly property var trayPinned: value("trayPinned", [])
    // seconds, 0: never (the defaults are hypr/hypridle.conf's)
    readonly property int lockAfter: value("lockAfter", 600)
    readonly property int screenOffAfter: value("screenOffAfter", 900)

    // stored at once here, so the switch follows the click; the file confirms it
    function set(key, v) {
        stored = Object.assign({}, stored, { [key]: v });
        Actions.run([script, "set", key, String(v)]);
    }

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/driftless-shell/settings.json"
        watchChanges: true
        onFileChanged: reload()
        printErrors: false
        onLoaded: {
            try {
                prefs.stored = JSON.parse(text()) || {};
            } catch (e) {}  // half written: the next change event brings the rest
        }
        onLoadFailed: prefs.stored = {}
    }
}
