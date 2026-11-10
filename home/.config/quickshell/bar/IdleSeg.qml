import QtQuick
import qs.services

// Keep awake: while on, hypridle neither locks nor turns the screen off (services/KeepAwake.qml).
// Only in the bar while it is on, like the updates: it is turned on in the settings ("When you are
// away").
Seg {
    id: seg

    shown: KeepAwake.on

    padL: compact ? 4 : 7
    padR: compact ? 4 : 7
    tip: "Kept awake: no lock, the screen stays on<br><font color='" + Theme.dim + "'>Click: back to the usual times</font>"

    onClicked: KeepAwake.on = !KeepAwake.on

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{F0176}"
        color: Theme.accent
    }
}
