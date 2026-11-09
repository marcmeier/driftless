import QtQuick
import qs.services

// Keep awake: while on, hypridle neither locks nor turns the screen off (services/KeepAwake.qml).
Seg {
    id: seg

    padL: compact ? 4 : 7
    padR: compact ? 4 : 7
    tip: KeepAwake.on ? "Kept awake: no lock, the screen stays on<br><font color='" + Theme.dim + "'>Click: back to the usual times</font>"
                      : "Locks and turns the screen off as set<br><font color='" + Theme.dim + "'>Click: keep awake</font>"

    onClicked: KeepAwake.on = !KeepAwake.on

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        text: KeepAwake.on ? "\u{F0176}" : "\u{F0FAA}"
        color: KeepAwake.on ? Theme.accent : Theme.dim
    }
}
