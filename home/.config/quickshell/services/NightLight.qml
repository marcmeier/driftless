pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// The night light (the settings, Displays): warmer colours from sunset to sunrise, or always. hyprsunset
// runs only while it is on and gives the screens their colours back when it ends; a new warmth reaches
// it through hyprctl. One process for all screens; it ends with the shell (it runs in
// driftless-shell.service's cgroup). Sunrise and sunset are today's from weather.py (as for the auto look).
Singleton {
    id: night

    property var sun: ({ sunrise: "07:00", sunset: "19:00" })
    property date now: new Date()

    function minutes(hhmm) {
        const p = String(hhmm).split(":");
        return Number(p[0]) * 60 + Number(p[1]);
    }
    readonly property bool dark: {
        const m = now.getHours() * 60 + now.getMinutes();
        return m < minutes(sun.sunrise) || m >= minutes(sun.sunset);
    }
    readonly property bool active: Prefs.nightLight === "on" || Prefs.nightLight === "sun" && dark
    readonly property int temperature: Prefs.nightTemp

    FileView {
        path: Quickshell.env("HOME") + "/.cache/theme/sun.json"
        watchChanges: true
        onFileChanged: reload()
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text());
                if (/^\d\d:\d\d$/.test(s.sunrise) && /^\d\d:\d\d$/.test(s.sunset))
                    night.sun = s;
            } catch (e) {}
        }
    }

    Timer {
        interval: 60 * 1000
        running: Prefs.nightLight === "sun"
        repeat: true
        triggeredOnStart: true
        onTriggered: night.now = new Date()
    }

    Process {
        id: sunset
        running: night.active
        // started with the warmth of that moment; a later change goes to the running one
        command: ["hyprsunset", "--temperature", String(night.temperature)]
    }
    onTemperatureChanged: {
        if (sunset.running)
            Actions.run(["hyprctl", "hyprsunset", "temperature", String(temperature)]);
    }
}
