pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import QtQuick

// What listens or watches right now, for the privacy indicator in the bar (bar/PrivacySeg.qml):
//   microphone  a PipeWire stream that records from a microphone (level meters left out)
//   camera      a PipeWire stream from a camera, or a program that opened /dev/video* itself
//               (scripts/camera.py)
//   screen      a PipeWire stream from any other video source (the portal's screencast,
//               xdg-desktop-portal-hyprland), or a recorder that copies frames straight from Hyprland
//               (its "screencast" event)
Singleton {
    id: privacy

    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool micMuted: !!(source && source.audio && source.audio.muted)
    readonly property real micLevel: source && source.audio ? source.audio.volume : 0

    readonly property var micApps: linked((s, t) => device(s, PwNodeType.Audio) && t.type === PwNodeType.AudioInStream && !meter(t))
    readonly property var cameraApps: merge(linked((s, t) => device(s, PwNodeType.Video) && isCamera(s) && t.isStream), directCamera)
    readonly property var screenApps: {
        const apps = linked((s, t) => !!(s.type & PwNodeType.Video) && !isCamera(s) && t.isStream);
        return apps.length ? apps : hyprCast ? ["an app"] : [];
    }
    readonly property bool mic: micApps.length > 0
    readonly property bool camera: cameraApps.length > 0
    readonly property bool screen: screenApps.length > 0
    readonly property bool active: mic || camera || screen

    property var directCamera: []
    property bool hyprCast: false

    function toggleMute() {
        if (source && source.audio)
            source.audio.muted = !source.audio.muted;
    }
    function nudgeLevel(steps) {
        if (source && source.audio)
            source.audio.volume = Math.max(0, Math.min(1, Math.round((source.audio.volume + steps * 0.02) * 100) / 100));
    }

    // a device node (no stream) of that kind that gives something out (a duplex interface counts)
    function device(n, kind) {
        return !!(n.type & kind) && !!(n.type & PwNodeType.Source) && !(n.type & PwNodeType.Stream);
    }
    // (not called camera: that is the property above, which a function of the same name would hide)
    function isCamera(n) {
        return /^(v4l2|libcamera)_/.test(n.name || "");
    }
    // a level meter (pavucontrol's and the like) only watches, it does not record
    function meter(n) {
        const p = n.properties || {};
        return p["stream.monitor"] === "true" || /peak detect/i.test(p["media.name"] || "");
    }
    function appName(n) {
        const p = n.properties || {};
        return p["application.name"] || n.description || n.nickname || n.name || "an app";
    }
    // the apps on the receiving end of the links that pass the test, each once
    function linked(test) {
        const names = [];
        for (const l of Pipewire.linkGroups.values) {
            if (!l.source || !l.target || !test(l.source, l.target))
                continue;
            const name = appName(l.target);
            if (!names.includes(name))
                names.push(name);
        }
        return names;
    }
    function merge(a, b) {
        return a.concat(b.filter(x => !a.includes(x)));
    }

    // the streams' properties (app name, level meter) only arrive while they are tracked
    PwObjectTracker {
        objects: [privacy.source].concat(Pipewire.nodes.values.filter(n => n.isStream && n.type !== PwNodeType.AudioOutStream))
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "screencast")
                return;
            if (event.data.split(",")[0] === "1") {
                castOff.stop();
                privacy.hyprCast = true;
            } else {
                castOff.restart();
            }
        }
    }
    // Hyprland reports a cast as stopped and started again several times a second while frames
    // come unevenly: only believe a stop that lasts
    Timer {
        id: castOff
        interval: 2000
        onTriggered: privacy.hyprCast = false
    }

    Process {
        id: cameraWatch
        running: true
        command: [Quickshell.shellDir + "/scripts/camera.py"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    privacy.directCamera = JSON.parse(line).apps || [];
                } catch (e) {
                    console.warn("camera.py:", e);
                }
            }
        }
        onExited: {
            privacy.directCamera = [];
            restart.start();
        }
    }
    Timer {
        id: restart
        interval: 10000
        onTriggered: cameraWatch.running = true
    }
}
