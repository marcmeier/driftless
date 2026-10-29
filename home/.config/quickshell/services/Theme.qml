pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// The shell's look in one place (the bar, the notifications, the power menu, the on-screen display, the
// password dialog): the plain look, or one of the named palettes (Catppuccin, Nord, ...) in its place.
// Background and one accent, everything opaque with a 1 px line around it, square corners, nothing that
// fades, glows or blends. theme/apply.py writes ~/.config/theme/colors.json with the named colours of
// the look that is on, dark or light, in the chosen palette (theme/scheme.py); the shell follows a
// change at once. The lock screen keeps the palette's dark look in both (`night`), like the login screen
// it matches.
Singleton {
    id: theme

    // ---- what colors.json says (scheme.py's dark values until it is read) ----
    property string scheme: "dark"
    property string appearance: "dark"      // what was chosen: dark, light or auto
    readonly property bool light: scheme === "light"
    property string paletteName: "plain"    // theme/scheme.py's PALETTES
    property var palettes: ({})             // every palette in brief: label, dark and light (name, swatches)
    property int renders: 0                 // bumps whenever apply.py rendered (a new look)

    property color primary: "#7aa6d9"
    property color secondary: "#7aa6d9"
    // the historic names of the stylesheets (theme/colors.css): accent = secondary, accent2 = primary
    readonly property color accent: secondary
    readonly property color accent2: primary

    property color desk: "#0e0e0e"           // the desktop behind everything
    property color glass: "#161616"          // what the surfaces are made of (opaque)
    property color raisedBase: "#1c1c1c"     // a lit tile, a selected row
    property color lineColor: "#2b2b2b"      // every border and separator
    property color fieldColor: "#111111"     // where you type
    property color overlay: "#ffffff"        // what hovers are made of
    property color text: "#d6d6d6"
    property color dim: "#8a8a8a"
    property color strong: "#f2f2f2"
    property color warn: "#e0a040"
    property color crit: "#e06666"
    property color accentInk: "#0e0e0e"      // text on an accent

    // ---- the parts, made of the above ----
    readonly property color surface: glass                            // the bar
    readonly property color card: glass                               // popups, tooltips, cards
    readonly property color raised: raisedBase
    readonly property color well: Qt.alpha(overlay, 0.035)            // a box inside a card
    readonly property color hover: Qt.alpha(overlay, light ? 0.06 : 0.07)
    readonly property color border: lineColor
    readonly property color cardBorder: lineColor
    readonly property color separator: lineColor
    readonly property color track: lineColor                          // under a slider, a meter, a switch
    readonly property color faint: Qt.alpha(dim, light ? 0.72 : 0.6)
    readonly property color knob: strong                              // a slider's knob, a switch's off thumb
    readonly property color field: fieldColor
    readonly property color fieldBorder: lineColor
    readonly property color scrim: desk                               // behind the power menu and the password dialog

    // the lock screen: always the dark look
    readonly property QtObject night: QtObject {
        property color primary: "#7aa6d9"
        property color desk: "#0e0e0e"
        property color text: "#d6d6d6"
        property color dim: "#8a8a8a"
        property color strong: "#f2f2f2"
        property color line: "#2b2b2b"
        readonly property color faint: Qt.alpha(dim, 0.6)
        property color warn: "#e0a040"
        property color crit: "#e06666"
        property color field: "#111111"
        readonly property color fieldBorder: line
        readonly property string font: theme.font
    }

    readonly property string font: "JetBrainsMono Nerd Font"

    // the bar: one flat strip along the top edge, a line below it (the compact bar is a bit tighter)
    readonly property int barHeight: 28
    readonly property int barGap: 0
    readonly property int barSide: 4

    // the round avatar (apply.py renders it from ~/.face); bumps when it is written again
    readonly property string avatar: Quickshell.env("HOME") + "/.config/theme/avatar.png"
    property int avatarVersion: 0

    readonly property string applyScript: Quickshell.env("HOME") + "/.config/theme/apply.py"

    // ok / warn / crit for a percentage that is running out
    function levelColor(percent) {
        return percent >= 90 ? crit : percent >= 70 ? warn : primary;
    }

    function apply(c) {
        const k = c.colors || {};
        theme.scheme = c.scheme === "light" ? "light" : "dark";
        theme.appearance = c.appearance || theme.scheme;
        if (c.primary)
            theme.primary = c.primary;
        if (c.secondary)
            theme.secondary = c.secondary;
        theme.desk = k.desk || "#0e0e0e";
        theme.glass = k.glass || "#161616";
        theme.raisedBase = k.bg_alt || "#1c1c1c";
        theme.lineColor = k.line || "#2b2b2b";
        theme.fieldColor = k.field || "#111111";
        theme.overlay = k.overlay || "#ffffff";
        theme.text = k.fg || "#d6d6d6";
        theme.dim = k.dim || "#8a8a8a";
        theme.strong = k.fg_strong || "#f2f2f2";
        theme.warn = k.orange || "#e0a040";
        theme.crit = k.red || "#e06666";
        theme.accentInk = k.ink || "#0e0e0e";
        const n = c.night || {};
        if (n.primary) {
            theme.night.primary = n.primary;
            theme.night.desk = n.desk;
            theme.night.text = n.fg;
            theme.night.dim = n.dim;
            theme.night.strong = n.fg_strong;
            theme.night.line = n.line;
            theme.night.warn = n.orange;
            theme.night.crit = n.red;
            theme.night.field = n.field;
        }
        theme.paletteName = c.palette || "plain";
        theme.palettes = c.palettes || {};
        theme.renders++;
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/theme/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                theme.apply(JSON.parse(text()));
            } catch (e) {}  // half written: the next change event brings the rest
        }
    }

    FileView {
        path: theme.avatar
        watchChanges: true
        printErrors: false
        onFileChanged: {
            reload();
            theme.avatarVersion++;
        }
    }

    // auto: when the sun rises or sets (NightLight follows the clock and today's times) and when
    // auto is chosen or read at the start; apply.py only renders when the look is not the right one
    Process {
        id: sunWatch
        command: ["python3", theme.applyScript, "--follow-sun"]
    }
    readonly property bool sunUp: !NightLight.dark
    onSunUpChanged: followSun()
    onAppearanceChanged: followSun()
    function followSun() {
        if (appearance === "auto" && !sunWatch.running)
            sunWatch.running = true;
    }
}
