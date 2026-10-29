import QtQuick
import qs.services

// The driftless sync (scripts/sync.py): the GitHub mark in the colour of its state, plus what waits
// (↓ incoming, ↑ outgoing). Click: the sync menu · right: sync now · middle: pause / resume.
Seg {
    id: seg

    readonly property var d: Feeds.sync.value
    readonly property string mode: d?.["class"] ?? "none"
    shown: !!d && mode !== "none"
    padL: compact ? 4 : 7
    padR: compact ? 4 : 8
    tip: (d?.tooltip ?? "").replace(/\n/g, "<br>").replace(/(^|<br>)( +)/g, (m, br, sp) => br + "&nbsp;".repeat(sp.length))

    onClicked: button => {
        const arg = button === Qt.RightButton ? ["now"] : button === Qt.MiddleButton ? ["toggle"] : [];
        Feeds.runThen(["systemd-run", "--user", "--scope", "--collect", "--quiet", "--", Actions.scripts + "/sync-menu.sh"].concat(arg), "sync");
    }

    Label {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        text: seg.d?.text ?? ""
        font.pixelSize: seg.compact ? 13 : 14
        color: seg.mode === "running" ? Theme.accent : seg.mode === "pending" || seg.mode === "off" ? Theme.warn
             : seg.mode === "error" ? Theme.crit : Theme.dim

    }
}
