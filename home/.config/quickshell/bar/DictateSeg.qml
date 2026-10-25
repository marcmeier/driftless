import QtQuick
import qs.services

// Dictation (hypr/dictate.py, SUPER + D): ready, recording, transcribing. Click: start/stop · right:
// start/stop without the LLM · middle: cancel the recording.
Seg {
    id: seg

    readonly property string mode: Feeds.dictate.value?.["class"] ?? "idle"
    readonly property string script: Actions.home + "/.config/hypr/dictate.py"

    padL: compact ? 4 : 5
    padR: compact ? 4 : 5
    tip: Apps.esc(Feeds.dictate.value?.tooltip ?? "").replace(/\n/g, "<br>")

    onClicked: button => {
        const args = button === Qt.RightButton ? ["toggle", "--raw"] : button === Qt.MiddleButton ? ["cancel"] : ["toggle"];
        Actions.launch([script].concat(args));
    }

    Icon {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        text: seg.mode === "recording" ? "\u{F0EC2}" : seg.mode === "busy" ? "\u{F01D8}" : "\u{F147D}"
        size: 14
        color: seg.mode === "recording" ? Theme.crit : Theme.accent

    }
}
