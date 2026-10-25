import QtQuick
import qs.services

// Package updates waiting (pacman, AUR, flatpak: scripts/updates.sh); hidden while there are none.
// Click: update in a terminal · right click: check again.
Seg {
    id: seg

    readonly property var d: Feeds.updates.value
    readonly property int flatpak: d ? (d.flatpak || 0) : 0
    readonly property int count: d ? d.repo + d.aur + flatpak : 0
    shown: count > 0
    padL: compact ? 6 : 7
    padR: compact ? 6 : 8
    spacing: 4
    tip: d ? `${d.repo} official, ${d.aur} AUR${flatpak ? `, ${flatpak} Flatpak` : ""}<br><font color='${Theme.dim}'>Click: update  ·  Right: check again</font>` : ""

    onClicked: button => {
        if (button === Qt.RightButton) {
            Feeds.updates.refresh();
            return;
        }
        // the pill counts again when the terminal closes
        Feeds.runThen(["systemd-run", "--user", "--scope", "--collect", "--quiet", "--", "ghostty", "-e", "bash", "-c",
                       "yay -Syu; if command -v flatpak >/dev/null; then echo; flatpak update && flatpak uninstall --unused; fi; echo; read -rp 'Done, press Enter'"], "updates");
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{F03D4}"
        color: seg.count >= 30 ? Theme.warn : Theme.dim
    }
    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: seg.count
        color: seg.count >= 30 ? Theme.warn : Theme.text
        font.pixelSize: seg.compact ? 12 : 13
    }
}
