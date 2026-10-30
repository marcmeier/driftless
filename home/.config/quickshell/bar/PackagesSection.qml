import Quickshell
import Quickshell.Io
import QtQuick
import qs.services

// The new packages, a part of the sync icon's popup (SyncPopup.qml): what the sync found in your lists
// but not on this machine, one line each (what it is, its size), below it in small which machine listed
// it and what comes along (scripts/install-review.py has the data). × leaves a package out on this
// machine, "Install" hands over to the password dialog, which says why it asks.
Item {
    id: root

    property var popup
    property var bar
    property var d: null
    readonly property string script: Quickshell.shellDir + "/scripts/install-review.py"
    readonly property var packages: d ? d.packages : []
    readonly property var repo: packages.filter(p => p.kind === "repo")
    readonly property var aur: packages.filter(p => p.kind === "aur")
    readonly property var flatpaks: packages.filter(p => p.kind === "flatpak")
    readonly property int installable: repo.length + flatpaks.length
    readonly property bool canInstall: !!d && d.helper && installable > 0

    implicitHeight: content.implicitHeight
    Component.onCompleted: load()

    function hide() {
        if (popup)
            popup.close();
    }
    function load() {
        loader.running = true;
    }
    function install() {
        if (!canInstall)
            return;
        hide();
        // a unit of its own: the password dialog and pacman outlive a restart of the shell
        Actions.run(["systemd-run", "--user", "--quiet", "--collect", "--unit=driftless-package-install", "--",
                     script, "install"]);
    }
    function terminal() {
        hide();
        Actions.launch([Actions.scripts + "/sync-menu.sh", "install"]);
    }
    function skip(sub, names) {
        change.command = [script, sub].concat(names);
        change.running = true;
    }

    Process {
        id: loader
        command: [root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.d = JSON.parse(text);
                } catch (e) {
                    console.warn("install-review", e);
                }
            }
        }
    }
    Process {
        id: change
        onExited: root.load()
    }

    Column {
        id: content
        width: parent.width
        spacing: 2

        Label {
            visible: !root.d
            small: true
            dim: true
            text: "Looking them up …"
        }

        Repeater {
            model: root.packages
            Item {
                id: pkg
                required property var modelData
                readonly property string note: {
                    const p = modelData;
                    const parts = [];
                    if (p.by)
                        parts.push("from " + p.by);
                    if (p.deps)
                        parts.push("+" + p.deps + (p.deps === 1 ? " dependency" : " dependencies"));
                    if (p.kind === "aur")
                        parts.push("AUR, built in a terminal");
                    if (p.kind === "flatpak")
                        parts.push("Flathub");
                    return parts.join("  ·  ");
                }
                width: content.width
                height: lines.implicitHeight + 10

                Column {
                    id: lines
                    y: 5
                    width: parent.width - drop.width - 4
                    spacing: 1
                    Item {
                        width: parent.width
                        height: name.implicitHeight
                        Label {
                            id: name
                            text: pkg.modelData.name
                            bold: true
                        }
                        Label {
                            x: name.width + 10
                            width: parent.width - x - size.width - 10
                            elide: Text.ElideRight
                            dim: true
                            text: pkg.modelData.description || ""
                        }
                        Label {
                            id: size
                            anchors.right: parent.right
                            small: true
                            color: Theme.faint
                            text: pkg.modelData.size || ""
                        }
                    }
                    Label {
                        visible: text !== ""
                        width: parent.width
                        elide: Text.ElideRight
                        small: true
                        color: Theme.faint
                        text: pkg.note
                    }
                }
                PButton {
                    id: drop
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "\u{F0156}"
                    iconSize: 12
                    flat: true
                    onClicked: root.skip("skip", [pkg.modelData.name])
                }
            }
        }

        // what this machine does without, to take back with a click
        Label {
            visible: !!root.d && root.d.skipped.length > 0
            width: parent.width
            topPadding: 4
            elide: Text.ElideRight
            small: true
            color: Theme.faint
            text: root.d ? "Not on this machine: " + root.d.skipped.join(", ") + "  (click to offer again)" : ""
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.skip("unskip", root.d.skipped)
            }
        }

        Item {
            visible: root.packages.length > 0
            width: parent.width
            height: 36
            Label {
                anchors.verticalCenter: parent.verticalCenter
                small: true
                color: root.d && !root.d.helper ? Theme.warn : Theme.faint
                text: !root.d ? "" : !root.d.helper ? "Needs driftless-system first: driftless system"
                    : root.d.download ? root.d.download + " to download" : ""
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                PButton {
                    visible: root.aur.length > 0
                    text: "AUR in a terminal …"
                    onClicked: root.terminal()
                }
                PButton {
                    visible: root.installable > 0
                    text: "Install " + root.installable
                    accent: true
                    enabled: root.canInstall
                    onClicked: root.install()
                }
            }
        }
    }
}
