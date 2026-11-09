import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import qs.services
import "../bar"

// The box of hypr/notch/notch.py (ask Claude by voice). It hangs below the ask button in the bar
// (bar/AskSeg.qml) on the focused screen, or at the top centre when the bar has none: what it does in
// words, a level line while it listens, the answer at once. notch.py drives
// it over IPC, e.g.:
//   quickshell ipc -p ~/.config/quickshell call notch think "Do I have meetings today?"
// (listening, think, answer, append, error, speaking, ringing, hide, state); the microphone's level
// while listening comes from $XDG_RUNTIME_DIR/claude-notch/level, which notch.py writes
Scope {
    id: root

    // idle | listening | thinking | answer | error
    property string mode: "idle"
    property string prompt: ""
    property string fullText: ""
    property real level: -1          // < 0: no level yet, the line is hidden
    property bool speaking: false    // the answer is being spoken: stay open
    property bool ringing: false     // a timer rings: stay open until it is stopped

    readonly property bool open: mode !== "idle"

    // where it grows from: the ask button's x on the focused screen (-1: the middle)
    property real anchorX: -1
    function place() {
        const target = Actions.toFocusedScreen(win);
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
            root.mode = "answer";
        }
        // streaming: add a piece of text
        function append(chunk: string): void {
            if (root.mode !== "answer") {
                root.fullText = "";
                    root.mode = "answer";
            }
            root.fullText += chunk;
        }
        function error(text: string): void {
            root.fullText = text;
            root.mode = "error";
        }
        function ringing(on: bool): void { root.ringing = on; }
        function speaking(on: bool): void { root.speaking = on; }
        function hide(): void {
            root.speaking = false;
            root.ringing = false;
            root.mode = "idle";
        }
        function state(): string { return root.mode; }
    }

    FileView {
        path: root.mode === "listening" ? Quickshell.env("XDG_RUNTIME_DIR") + "/claude-notch/level" : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const l = parseFloat(text());
            if (!isNaN(l))
                root.level = Math.max(0, Math.min(1, l));
        }
    }

    // fold away when done (not while the pointer is on it or it still speaks)
    Timer {
        id: autoHide
        interval: root.mode === "error" ? 6000 : 9000 + root.fullText.length * 25
        running: (root.mode === "answer" || root.mode === "error")
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
        visible: root.open

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
            // room for the longest answer the prompt allows (a summary, about 100 words: 13 to 15 lines)
            readonly property int maxTextH: 400

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
                    return headerH - 4 + Math.min(measure.implicitHeight, bubble.maxTextH) + pad + 2;
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
            layer.enabled: true
            layer.effect: CardShadow {}
            Behavior on width { NumberAnimation { duration: Theme.enter; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: Theme.enter; easing.type: Easing.OutCubic } }
            onVisibleChanged: if (visible) enter.restart()
            NumberAnimation {
                id: enter
                target: bubble
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.enter
                easing.type: Easing.OutCubic
            }

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
                    font.letterSpacing: Theme.letterSpacing
                    font.pixelSize: Theme.fontSmall
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
                height: Math.min(measure.implicitHeight, bubble.maxTextH)
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                textFormat: Text.PlainText
                color: root.mode === "error" ? Theme.crit : Theme.text
                font.family: Theme.font
                font.letterSpacing: Theme.letterSpacing
                font.pixelSize: Theme.fontSize
                lineHeight: 1.15
                text: root.fullText
                visible: root.mode === "answer" || root.mode === "error"
            }
        }
    }
}
