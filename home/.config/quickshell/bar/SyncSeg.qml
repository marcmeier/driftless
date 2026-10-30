import QtQuick
import qs.services

// The driftless sync (scripts/sync.py): the driftless mark in the colour of its state, a pause or warning
// sign, and how many things wait for you (packages to look at, changes to take over, a machine to trust).
// Click: everything about it in its popup (SyncPopup.qml) · right: sync now · middle: pause / resume.
Seg {
    id: seg

    readonly property var d: Feeds.sync.value
    readonly property string mode: d?.["class"] ?? "none"
    readonly property int count: d?.count ?? 0
    shown: !!d && mode !== "none"
    spacing: 4
    padL: compact ? 4 : 7
    padR: compact ? 4 : 8
    tip: (d?.tooltip ?? "").replace(/\n/g, "<br>")
    popupKey: "sync"
    popupComponent: Component {
        SyncPopup {}
    }

    onClicked: button => {
        if (button === Qt.LeftButton) {
            togglePopup();
            return;
        }
        if (bar)
            bar.closePopup();
        Feeds.runThen(["systemd-run", "--user", "--scope", "--collect", "--quiet", "--", Actions.scripts + "/sync-menu.sh",
                       button === Qt.RightButton ? "now" : "toggle"], "sync");
    }

    readonly property color tint: mode === "running" ? Theme.accent : mode === "pending" || mode === "off" ? Theme.warn
                                : mode === "error" ? Theme.crit : Theme.dim

    DriftlessMark {
        anchors.verticalCenter: parent.verticalCenter
        size: seg.compact ? 16 : 17
        color: seg.tint
    }
    Icon {
        visible: text !== ""
        anchors.verticalCenter: parent.verticalCenter
        text: seg.d?.mark ?? ""
        color: seg.tint
    }
    // like the update count beside it: the number in the text colour, the sign in the state's
    Label {
        visible: seg.count > 0
        anchors.verticalCenter: parent.verticalCenter
        text: seg.count
        color: Theme.text
        font.pixelSize: seg.compact ? 12 : 13
    }
}
