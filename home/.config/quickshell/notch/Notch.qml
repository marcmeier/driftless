import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import qs.services

// The box of hypr/notch/notch.py (ask Claude by voice). It hangs below the ask button in the bar
// (bar/AskSeg.qml) on the focused screen, or at the top centre when the bar has none: what it does in
// words, a level line while it listens, the answer at once. notch.py drives
// it over IPC, e.g.:
//   quickshell ipc -p ~/.config/quickshell call notch think "Do I have meetings today?"
// (listening, think, answer, append, error, setLevel, speaking, ringing, hide, state)
Scope {
    id: root

    // idle | listening | thinking | answer | error
    property string mode: "idle"
    property string prompt: ""
    property string fullText: ""
    property int shown: 0
    property real level: -1          // < 0: no real level, the bars move by themselves
    property bool speaking: false    // the answer is being spoken: stay open
    property bool ringing: false     // a timer rings: stay open until it is stopped

    readonly property bool open: mode !== "idle"

    // where it grows from: the ask button's x on the focused screen (-1: the middle)
    property real anchorX: -1
    function place() {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        const target = Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0];
        if (target && win.screen !== target)
            win.screen = target;
        anchorX = target ? Voice.anchorX(target.name) : -1;
    }
    onModeChanged: {
        if (mode !== "idle" && Voice.mode === "idle")
            place();
        Voice.mode = mode;
    }
    onSpeakingChanged: Voice.speaking = speaking

    function reset() {
        fullText = "";
        shown = 0;
        level = -1;
    }

    IpcHandler {
        target: "notch"

        function listening(): void {
            root.reset();
            root.prompt = "";
            root.mode = "listening";
        }
        function think(prompt: string): void {
            root.reset();
            root.prompt = prompt;
            root.mode = "thinking";
        }
        function answer(text: string): void {
            root.fullText = text;
            root.shown = 0;
            root.mode = "answer";
        }
        // streaming: add a piece of text
        function append(chunk: string): void {
            if (root.mode !== "answer") {
                root.fullText = "";
                root.shown = 0;
                root.mode = "answer";
            }
            root.fullText += chunk;
        }
        function error(text: string): void {
            root.fullText = text;
            root.shown = 0;
            root.mode = "error";
        }
        function setLevel(l: real): void { root.level = Math.max(0, Math.min(1, l)); }
        function ringing(on: bool): void { root.ringing = on; }
        function speaking(on: bool): void {
            root.speaking = on;
            if (!on) root.level = -1;
        }
        function hide(): void {
            root.speaking = false;
            root.ringing = false;
            root.mode = "idle";
        }
        function state(): string { return root.mode; }
    }

    // the whole text at once (no typewriter in the plain look)
    Timer {
        interval: 1
        running: root.shown < root.fullText.length
        onTriggered: root.shown = root.fullText.length
    }

    // fold away when done (not while the pointer is on it or it still speaks)
    Timer {
        id: autoHide
        interval: root.mode === "error" ? 6000 : 9000 + root.fullText.length * 25
        running: (root.mode === "answer" || root.mode === "error")
                 && root.shown >= root.fullText.length
                 && !hover.hovered
                 && !root.speaking
                 && !root.ringing
        onTriggered: root.mode = "idle"
    }

    PanelWindow {
        id: win

        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: 360
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "claude-notch"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0

        // only the bubble takes clicks, the rest of the window lets them through
        mask: Region { item: bubble }

        Rectangle {
            id: bubble

            readonly property int pad: 12
            readonly property int headerH: 34
            readonly property int indent: pad
            readonly property int answerW: 520
            readonly property int textW: answerW - indent - pad

            readonly property real targetW: {
                switch (root.mode) {
                case "listening": return 230;
                case "thinking": return Math.min(440, Math.max(200, header.implicitWidth + 2 * pad));
                case "answer":
                case "error": return answerW;
                default: return 110;
                }
            }
            readonly property real targetH: {
                if (root.mode === "answer" || root.mode === "error")
                    return headerH - 4 + Math.min(measure.implicitHeight, 240) + pad + 2;
                return headerH;
            }

            readonly property real from: root.anchorX >= 0 ? root.anchorX : win.width / 2
            x: Math.round(Math.max(10, Math.min(win.width - width - 10, from - width / 2)))
            y: 0
            width: targetW
            height: targetH
            visible: root.open
            color: Theme.card
            border.width: 1
            border.color: root.mode === "error" ? Theme.crit : Theme.cardBorder
            clip: true

            HoverHandler { id: hover }
            // click: close, and stop the recording, Claude or the voice
            TapHandler {
                onTapped: {
                    if (root.mode === "listening" || root.mode === "thinking" || root.speaking || root.ringing)
                        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/notch/notch.py", "cancel"]);
                    root.mode = "idle";
                }
            }

            // ---------- header: the status ----------
            Row {
                id: header
                x: bubble.pad
                height: bubble.headerH
                spacing: 10

                Text {
                    id: status
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, root.mode === "answer" || root.mode === "error" ? bubble.textW : 340)
                    elide: Text.ElideRight
                    color: root.mode === "answer" ? Theme.dim : Theme.text
                    font.family: Theme.font
                    font.pixelSize: 12
                    text: {
                        switch (root.mode) {
                        case "listening": return "Listening …";
                        case "thinking": return root.prompt !== "" ? root.prompt + "  …" : "Thinking …";
                        case "answer": return root.prompt !== "" ? root.prompt : "Claude";
                        case "error": return "Error";
                        default: return "";
                        }
                    }
                }
            }

            // the microphone's level while listening: a 2 px line (none without a real level)
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: bubble.pad
                y: (bubble.headerH - height) / 2
                width: 60
                height: 2
                visible: root.mode === "listening" && root.level >= 0
                color: Theme.track
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, root.level))
                    height: parent.height
                    color: Theme.accent
                }
            }

            // ---------- answer ----------
            Text {
                id: measure
                visible: false
                width: bubble.textW
                wrapMode: Text.Wrap
                font: answerText.font
                lineHeight: 1.15
                text: root.fullText
                textFormat: Text.PlainText
            }

            Text {
                id: answerText
                x: bubble.indent
                y: bubble.headerH - 4
                width: bubble.textW
                height: Math.min(measure.implicitHeight, 240)
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                textFormat: Text.PlainText
                color: root.mode === "error" ? Theme.crit : Theme.text
                font.family: Theme.font
                font.pixelSize: 13
                lineHeight: 1.15
                text: root.fullText.substring(0, root.shown)
                visible: root.mode === "answer" || root.mode === "error"
            }
        }
    }
}
