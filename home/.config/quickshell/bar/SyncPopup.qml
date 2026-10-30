import QtQuick
import qs.services

// The driftless sync in one place, the popup at its icon (SyncSeg.qml; scripts/sync.py has the data).
// Short on purpose: one line how it stands, one line for each thing that waits for you (new packages,
// changes on GitHub, a new machine, a conflict), unfolded in place, and the switches at the bottom.
// What needs a terminal (a diff, the log, a fingerprint to compare) opens one; scripts/sync-menu.sh
// does the work. More settings: the settings popup (Sync).
Item {
    id: root

    property var popup
    property var bar
    readonly property var d: Feeds.sync.value?.details ?? null
    readonly property var inc: d?.incoming ?? null
    readonly property bool incWaits: !!inc && d.mode !== "auto"
    property bool packagesOpen: true
    property bool incomingOpen: false

    // how it stands, in a few words
    readonly property string summary: {
        if (!d)
            return "";
        if (d.running)
            return "Syncing …";
        const l = d.last;
        const when = l ? "  ·  " + l.ago.replace(" ago", "") : "";
        if (d.conflict.length)
            return "Conflict" + when;
        if (l && !l.ok)
            return l.result.replace(/,.*/, "") + when;
        if (d.mode === "off")
            return "Paused";
        return "Up to date" + when;
    }
    readonly property bool trouble: !!d && (d.conflict.length > 0 || d.foreign > 0 || (!!d.last && !d.last.ok))

    implicitWidth: 460
    implicitHeight: content.implicitHeight

    // a switch or a run in the background: the icon and this popup follow when it is done
    function menu(args) {
        Feeds.runThen(["systemd-run", "--user", "--scope", "--collect", "--quiet", "--", Actions.scripts + "/sync-menu.sh"].concat(args), "sync");
    }
    // a terminal: the popup makes way
    function terminal(args) {
        Actions.launch([Actions.scripts + "/sync-menu.sh"].concat(args));
        if (popup)
            popup.close();
    }

    Column {
        id: content
        width: parent.width
        spacing: 8

        PopupHeader {
            title: "driftless"
            status: root.summary
            statusColor: root.trouble ? Theme.crit : Theme.faint
        }

        // trouble: one line, the log says the rest
        Row {
            visible: root.trouble
            spacing: 8
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: content.width - why.width - 8
                elide: Text.ElideRight
                small: true
                color: Theme.crit
                text: !root.d ? ""
                    : root.d.conflict.length ? "Changed here and on GitHub: " + root.d.conflict.join(", ")
                    : root.d.foreign ? root.d.foreign + " change(s) on GitHub not signed by your machines"
                    : "The last run did not finish"
            }
            PButton {
                id: why
                text: "Log …"
                onClicked: root.terminal(["log"])
            }
        }

        // a new machine to trust
        Repeater {
            model: root.d ? root.d.joining : []
            Item {
                required property var modelData
                width: content.width
                height: 32
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "New machine: " + modelData.host
                    bold: true
                }
                PButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Trust …"
                    onClicked: root.terminal(["trust", modelData.fp])
                }
            }
        }

        // new packages from the lists, the list in the frame of its header
        SyncFold {
            visible: !!root.d && root.d.packages > 0
            text: root.d ? (root.d.packages === 1 ? "1 new package" : root.d.packages + " new packages") : ""
            open: root.packagesOpen
            onToggled: root.packagesOpen = !root.packagesOpen
            Loader {
                active: !!root.d && root.d.packages > 0 && root.packagesOpen
                width: parent.width
                sourceComponent: PackagesSection {
                    popup: root.popup
                    bar: root.bar
                }
            }
        }

        // changes on GitHub that wait
        SyncFold {
            visible: root.incWaits
            text: root.inc ? (root.inc.count === 1 ? "1 change" : root.inc.count + " changes") + " from "
                             + [...new Set(root.inc.commits.map(c => c.by))].join(", ") : ""
            open: root.incomingOpen
            onToggled: root.incomingOpen = !root.incomingOpen
            Repeater {
                model: root.inc ? root.inc.commits : []
                Label {
                    required property var modelData
                    width: parent.width
                    topPadding: 2
                    elide: Text.ElideRight
                    dim: true
                    text: modelData.subject
                }
            }
            Item {
                width: parent.width
                height: 36
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    small: true
                    color: Theme.faint
                    text: root.inc && root.inc.more ? "and " + root.inc.more + " more" : ""
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    PButton {
                        text: "Diff …"
                        onClicked: root.terminal(["diff"])
                    }
                    PButton {
                        text: "Take over"
                        accent: true
                        onClicked: root.menu(["now"])
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.separator
        }
        // the switches, each with what it does
        Item {
            width: parent.width
            height: 30
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Label {
                    text: "Sync with your other machines"
                    dim: true
                }
                Label {
                    small: true
                    color: Theme.faint
                    text: "Send this machine's changes, fetch theirs"
                }
            }
            PButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: "\u{F04E6}"
                text: "Sync now"
                enabled: !!root.d && !root.d.running
                onClicked: root.menu(["now"])
            }
        }
        Column {
            width: parent.width
            spacing: 2
            Item {
                width: parent.width
                height: 28
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Their changes"
                    dim: true
                }
                PSegmented {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    options: [["review", "Ask first"], ["auto", "Automatic"], ["off", "Paused"]]
                    current: root.d ? root.d.mode : ""
                    onPicked: value => root.menu([value])
                }
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignRight
                small: true
                color: Theme.faint
                text: !root.d ? "" : root.d.mode === "auto" ? "They come in by themselves, every hour"
                    : root.d.mode === "off" ? "This machine does not sync" : "They wait here until you take them over"
            }
        }
    }
}
