import QtQuick
import Quickshell.Io
import qs.services

// About this machine (a click on your name): you and the machine, its system and versions, the
// driftless release it runs, the last full upgrade, memory and disk (scripts/about.py, read on every
// open). Below: change your picture, lock, log out.
Item {
    id: root

    property var popup
    property var bar
    property var info: ({})

    implicitWidth: 340
    implicitHeight: column.implicitHeight

    function gb(bytes) {
        return (bytes / 1073741824).toFixed(bytes < 10737418240 ? 1 : 0);
    }
    function percent(part) {
        return part && part.total ? 100 * part.used / part.total : 0;
    }
    function duration(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return d ? `${d} d ${h} h` : h ? `${h} h ${m} min` : `${m} min`;
    }
    // "today 18:43", "yesterday", "3 days ago"
    function ago(t) {
        if (!t)
            return "";
        const then = new Date(t * 1000), now = new Date();
        const midnight = d => new Date(d.getFullYear(), d.getMonth(), d.getDate());
        const days = Math.round((midnight(now) - midnight(then)) / 86400000);
        return days === 0 ? "today " + Qt.formatTime(then, "HH:mm") : days === 1 ? "yesterday" : `${days} days ago`;
    }
    function act(fn) {
        if (root.popup)
            root.popup.close();
        fn();
    }

    Process {
        running: true
        command: [Actions.scripts + "/about.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.info = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Column {
        id: column
        width: parent.width
        spacing: 12

        // you, and where you are
        Row {
            spacing: 12
            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                sourceSize: Qt.size(88, 88)
                source: Theme.avatarVersion >= 0 ? "file://" + Theme.avatar : ""
                cache: false
                smooth: true
                mipmap: true
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Label {
                    text: `${Apps.esc(Feeds.userName)} <font color='${Theme.dim}'>on</font> ${Apps.esc(root.info.host || "")}`
                    textFormat: Text.StyledText
                    bold: true
                    font.pixelSize: 15
                }
                Label {
                    visible: text !== ""
                    text: root.info.model || ""
                    small: true
                    dim: true
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.separator
        }

        // the system, a name and a value per line
        Column {
            width: parent.width
            spacing: 5
            Repeater {
                model: [
                    ["Processor", root.info.cpu],
                    ["System", root.info.os],
                    ["Kernel", root.info.kernel],
                    ["Hyprland", root.info.hyprland],
                    ["Quickshell", root.info.quickshell],
                    ["driftless", root.info.driftless ? root.info.driftless.version
                        + (root.info.driftless.commit ? `  <font color='${Theme.dim}'>${root.info.driftless.commit}</font>` : "") : ""],
                    ["Up", root.info.uptime ? root.duration(root.info.uptime) : ""],
                    ["Last upgrade", root.ago(root.info.upgraded)]
                ].filter(r => r[1])
                delegate: Row {
                    required property var modelData
                    spacing: 0
                    Label {
                        width: 104
                        text: modelData[0]
                        small: true
                        dim: true
                    }
                    Label {
                        width: column.width - 104
                        elide: Text.ElideRight
                        text: modelData[1]
                        textFormat: Text.StyledText
                        small: true
                    }
                }
            }
        }

        // memory and the root file system
        Repeater {
            model: [["Memory", root.info.memory], ["Disk", root.info.disk]].filter(r => r[1] && r[1].total)
            delegate: Column {
                required property var modelData
                width: column.width
                spacing: 5
                Item {
                    width: parent.width
                    height: name.implicitHeight
                    Label {
                        id: name
                        text: modelData[0]
                        small: true
                        dim: true
                    }
                    Label {
                        anchors.right: parent.right
                        text: `${root.gb(modelData[1].used)} of ${root.gb(modelData[1].total)} GB`
                        small: true
                        dim: true
                    }
                }
                PMeter {
                    width: parent.width
                    percent: root.percent(modelData[1])
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.separator
        }

        ButtonRow {
            PButton {
                icon: "\u{F0004}"
                text: "Picture …"
                onClicked: root.act(() => Actions.script("settings-menu.sh", ["avatar"]))
            }
            PButton {
                icon: "\u{F033E}"
                text: "Lock"
                onClicked: root.act(() => Session.lock())
            }
            PButton {
                icon: "\u{F0343}"
                text: "Log out"
                onClicked: root.act(() => Session.logout())
            }
        }
    }
}
