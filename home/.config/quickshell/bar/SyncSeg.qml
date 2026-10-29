import QtQuick
import qs.services

// The driftless sync (scripts/sync.py): the driftless mark in the colour of its state, plus what
// waits (↓ incoming, ↑ outgoing) and a pause or warning sign. Click: the sync menu · right: sync now · middle: pause / resume.
Seg {
    id: seg

    readonly property var d: Feeds.sync.value
    readonly property string mode: d?.["class"] ?? "none"
    shown: !!d && mode !== "none"
    spacing: 2
    padL: compact ? 4 : 7
    padR: compact ? 4 : 8
    tip: (d?.tooltip ?? "").replace(/\n/g, "<br>").replace(/(^|<br>)( +)/g, (m, br, sp) => br + "&nbsp;".repeat(sp.length))

    onClicked: button => {
        const arg = button === Qt.RightButton ? ["now"] : button === Qt.MiddleButton ? ["toggle"] : [];
        Feeds.runThen(["systemd-run", "--user", "--scope", "--collect", "--quiet", "--", Actions.scripts + "/sync-menu.sh"].concat(arg), "sync");
    }

    readonly property color tint: mode === "running" ? Theme.accent : mode === "pending" || mode === "off" ? Theme.warn
                                : mode === "error" ? Theme.crit : Theme.dim

    DriftlessMark {
        anchors.verticalCenter: parent.verticalCenter
        size: seg.compact ? 16 : 17
        color: seg.tint
    }
    Label {
        visible: text !== ""
        anchors.verticalCenter: parent.verticalCenter
        text: seg.d?.badge ?? ""
        font.pixelSize: seg.compact ? 13 : 14
        color: seg.tint
    }
}
