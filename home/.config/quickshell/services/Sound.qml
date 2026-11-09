pragma Singleton

import Quickshell
import QtQuick

// A sound device's name as people say it. PipeWire describes a device by its chip ("Navi 21/23
// HDMI/DP Audio Controller Digital Stereo (HDMI) [SCREEN NAME]"); what matters is where the sound
// comes out: the screen's own name for HDMI and DisplayPort, "Built-in" and the socket for the
// board's sound. USB and Bluetooth devices already say what they are.
Singleton {
    function name(n) {
        if (!n)
            return "";
        const p = n.properties || {};
        const profile = p["device.profile.description"] || "";
        const nick = p["node.nick"] || n.nickname || "";
        const plain = n.description || n.nickname || n.name || "";
        if (/HDMI|DisplayPort/i.test(profile)) {
            const port = /DisplayPort/i.test(profile) ? "DisplayPort" : "HDMI";
            // the nick is the screen's name, or just "HDMI 1" when the screen does not tell
            return (nick && !/^(HDMI|DisplayPort|DP)\b/i.test(nick) ? nick : "Screen") + ` (${port})`;
        }
        if (p["device.bus"] === "pci" && profile) {
            const socket = profile.replace(/ (Stereo|Surround [0-9.]+)/, "").replace(" (IEC958)", ", S/PDIF");
            return `Built-in (${socket})`;
        }
        return plain;
    }
}
