import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

// The desktop settings (a click on your name; walker menus before), laid out like a settings app: the
// pages on the left (appearance and palette, bar, monitors, system), on the right one row per setting,
// what it is on the left and its switch or button on the right. Every choice is this machine's own
// (scripts/settings-menu.sh, scripts/bar_layout.py, scripts/sync-menu.sh).
Item {
    id: root

    property var popup
    property var bar
    property string page: "appearance"

    readonly property string scripts: Quickshell.shellDir + "/scripts"
    readonly property string menu: scripts + "/settings-menu.sh"
    readonly property string stateDir: Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"

    property string pendingLook: ""  // clicked, apply.py is still rendering
    readonly property string look: pendingLook || Theme.appearance
    property string pendingPalette: ""  // the same for the palette
    readonly property string paletteName: pendingPalette || Theme.paletteName
    readonly property var paletteNow: Theme.palettes[paletteName] || null
    property var widgets: []        // bar_layout.py --widgets
    readonly property var hiddenGroups: widgets.filter(w => !w.group && w.hidden).map(w => w.id)
    readonly property bool laptopPanel: Hyprland.monitors.values.some(m => /^eDP-/.test(m.name))
    readonly property string syncMode: (syncModeFile.text() || "review").trim()

    readonly property var pages: [
        ["appearance", "Appearance", "\u{F03D8}", "Dark or light, the palette and your picture"],
        ["bar", "Bar", "\u{F06FC}", "Size of the bar and the widgets it shows"],
        ["displays", "Displays", "\u{F037A}", "Arrangement and mode of the monitors"],
        ["system", "System", "\u{F0493}", "Sync with your other machines, keyboard"]
    ]
    readonly property var current: pages.find(p => p[0] === page) || pages[0]

    implicitWidth: 720
    implicitHeight: 440

    function run(args) {
        Actions.launch([root.menu].concat(args));
    }
    // a program with a window of its own: the popup makes way
    function open(args) {
        run(args);
        if (popup)
            popup.close();
    }
    function sync(args) {
        Actions.launch([root.scripts + "/sync-menu.sh"].concat(args));
    }

    // ---- what there is ----

    // today's sunrise and sunset (weather.py), for the line under the looks
    FileView {
        id: sun
        path: Quickshell.env("HOME") + "/.cache/theme/sun.json"
        watchChanges: true
        onFileChanged: reload()
        printErrors: false
    }
    readonly property var sunTimes: {
        try {
            return JSON.parse(sun.text());
        } catch (e) {
            return { sunrise: "07:00", sunset: "19:00" };
        }
    }
    Connections {
        target: Theme
        function onRendersChanged() {
            if (root.pendingLook === Theme.appearance)
                root.pendingLook = "";
            if (root.pendingPalette === Theme.paletteName)
                root.pendingPalette = "";
        }
    }

    FileView {
        id: customMonitors
        path: root.stateDir + "/hypr/monitors.lua"
        printErrors: false
    }

    // the sync mode of this machine (sync-menu.sh writes it)
    FileView {
        id: syncModeFile
        path: root.stateDir + "/driftless/mode"
        watchChanges: true
        onFileChanged: reload()
        printErrors: false
    }

    Process {
        id: widgetList
        running: true
        command: [root.scripts + "/bar_layout.py", "--widgets"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    // the user pill is the way in here: it stays
                    root.widgets = JSON.parse(text).filter(w => w.id !== "group/user" && w.group !== "group/user");
                } catch (e) {}
            }
        }
    }
    // the layout changed (here or in the widget manager): read the list again
    Connections {
        target: BarLayout
        function onSavedChanged() {
            widgetList.running = true;
        }
    }

    // ---- left: who, and the pages ----
    Column {
        id: side
        width: 184
        height: parent.height
        spacing: 12

        // you; a click on the picture changes it
        Rectangle {
            width: parent.width
            height: 52
            color: meMouse.containsMouse ? Theme.hover : "transparent"
            Image {
                id: face
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 36
                sourceSize: Qt.size(72, 72)
                source: Theme.avatarVersion >= 0 ? "file://" + Theme.avatar : ""
                cache: false
                smooth: true
                mipmap: true
            }
            Column {
                anchors.left: face.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Label {
                    width: parent.width
                    elide: Text.ElideRight
                    text: Feeds.userName
                    bold: true
                }
                Label {
                    small: true
                    dim: true
                    text: "This machine"
                }
            }
            MouseArea {
                id: meMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.open(["avatar"])
            }
        }

        Column {
            width: parent.width
            spacing: 2
            Repeater {
                model: root.pages
                Rectangle {
                    id: nav
                    required property var modelData
                    readonly property bool on: root.page === modelData[0]
                    width: side.width
                    height: 32
                    color: on ? Theme.raised : navMouse.containsMouse ? Theme.hover : "transparent"
                    // the current page: a line in the accent on the left
                    Rectangle {
                        visible: nav.on
                        width: 2
                        height: parent.height
                        color: Theme.accent
                    }
                    Icon {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: nav.modelData[2]
                        size: 15
                        color: nav.on ? Theme.accent : Theme.dim
                    }
                    Label {
                        x: 40
                        anchors.verticalCenter: parent.verticalCenter
                        text: nav.modelData[1]
                        color: nav.on ? Theme.strong : Theme.text
                        bold: nav.on
                    }
                    MouseArea {
                        id: navMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.page = nav.modelData[0];
                            flick.contentY = 0;
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: divider
        x: side.width + 14
        y: -14
        width: 1
        height: parent.height + 28
        color: Theme.separator
    }

    // ---- right: the page ----
    Item {
        id: main
        x: divider.x + 1 + 20
        width: parent.width - x
        height: parent.height

        Column {
            id: head
            width: parent.width
            spacing: 3
            Label {
                text: root.current[1]
                bold: true
                color: Theme.strong
                font.pixelSize: 16
            }
            Label {
                small: true
                dim: true
                text: root.current[3]
            }
        }

        Flickable {
            id: flick
            y: head.height + 16
            width: parent.width
            height: parent.height - y
            clip: true
            contentHeight: pageLoader.height
            boundsBehavior: Flickable.StopAtBounds

            Loader {
                id: pageLoader
                width: flick.width - 12
                sourceComponent: ({ appearance: appearancePage, bar: barPage, displays: displaysPage, system: systemPage })[root.page]
            }
        }
        // where in a long page you are
        Rectangle {
            visible: flick.contentHeight > flick.height
            x: parent.width - 3
            y: flick.y + flick.visibleArea.yPosition * flick.height
            width: 3
            height: flick.visibleArea.heightRatio * flick.height
            color: Theme.border
        }
    }

    // ---- the pages ----

    Component {
        id: appearancePage
        Column {
            spacing: 18
            Group {
                title: "Style"
                SettingRow {
                    first: true
                    title: "Appearance"
                    detail: root.look === "auto"
                            ? "Light from sunrise (" + root.sunTimes.sunrise + ") to sunset (" + root.sunTimes.sunset + "), dark at night"
                            : root.paletteName !== "plain" && root.paletteNow
                            ? root.paletteNow.label + " " + root.paletteNow[root.look].name
                            : root.look === "light" ? "Light greys, dark text" : "Dark greys, light text"
                    PSegmented {
                        options: [["dark", "Dark", "\u{F0594}"], ["light", "Light", "\u{F0599}"], ["auto", "Auto", "\u{F050E}"]]
                        current: root.look
                        onPicked: value => {
                            root.pendingLook = value;
                            root.run(["appearance", value]);
                        }
                    }
                }
            }
            // the palettes, each in the variant that is on, a few of its colours as a preview
            Group {
                title: "Palette"
                Item {
                    width: parent.width
                    height: tiles.implicitHeight + 24
                    Grid {
                        id: tiles
                        x: 12
                        y: 12
                        columns: 3
                        spacing: 8
                        readonly property real tileWidth: Math.floor((parent.width - 24 - spacing * (columns - 1)) / columns)
                        Repeater {
                            model: Object.keys(Theme.palettes)
                            Rectangle {
                                id: tile
                                required property string modelData
                                readonly property var entry: Theme.palettes[modelData]
                                readonly property var variant: entry[Theme.scheme] || entry.dark
                                readonly property bool chosen: root.paletteName === modelData
                                width: tiles.tileWidth
                                height: 32
                                color: chosen ? Theme.raised : tileMouse.containsMouse ? Theme.hover : "transparent"
                                border.width: 1
                                border.color: chosen ? Theme.accent : Theme.border
                                // the background with the accent and three colours on it
                                Rectangle {
                                    id: swatch
                                    x: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: swatches.implicitWidth + 6
                                    height: 14
                                    color: tile.variant.bg
                                    border.width: 1
                                    border.color: Theme.border
                                    Row {
                                        id: swatches
                                        anchors.centerIn: parent
                                        spacing: 2
                                        Repeater {
                                            model: ["primary", "red", "yellow", "green"]
                                            Rectangle {
                                                required property string modelData
                                                width: 5
                                                height: 8
                                                color: tile.variant[modelData]
                                            }
                                        }
                                    }
                                }
                                Label {
                                    anchors.left: swatch.right
                                    anchors.leftMargin: 8
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                    text: tile.entry.label
                                    font.pixelSize: 12
                                    color: tile.chosen ? Theme.accent : Theme.text
                                }
                                MouseArea {
                                    id: tileMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: tile.chosen ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: {
                                        if (tile.chosen)
                                            return;
                                        root.pendingPalette = tile.modelData;
                                        root.run(["palette", tile.modelData]);
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Group {
                title: "Account"
                SettingRow {
                    first: true
                    title: "Picture"
                    detail: "Pick an image and the square to show"
                    PButton {
                        text: "Change …"
                        onClicked: root.open(["avatar"])
                    }
                }
            }
        }
    }

    Component {
        id: barPage
        Column {
            spacing: 18
            Group {
                title: "Size"
                SettingRow {
                    first: true
                    title: "Bar size"
                    detail: BarLayout.mode === "spacious" ? "Full size on every monitor"
                            : BarLayout.mode === "compact" ? "Compact on every monitor"
                            : "Compact on notebook panels, full size elsewhere"
                    PSegmented {
                        options: [["auto", "Automatic"], ["spacious", "Full size"], ["compact", "Compact"]]
                        current: BarLayout.mode
                        onPicked: value => Actions.run([root.scripts + "/bar_layout.py", "--mode", value])
                    }
                }
            }
            Group {
                title: "Widgets"
                SettingRow {
                    first: true
                    title: "Order and groups"
                    detail: "Move widgets and put them into groups"
                    PButton {
                        text: "Arrange …"
                        onClicked: root.open(["widgets"])
                    }
                }
                // which widgets show; a group that is off takes its members with it
                Repeater {
                    model: root.widgets
                    SettingRow {
                        id: wrow
                        required property var modelData
                        readonly property bool inGroup: modelData.group !== ""
                        readonly property bool groupOff: inGroup && root.hiddenGroups.includes(modelData.group)
                        rowHeight: 36
                        indent: inGroup ? 20 : 0
                        title: modelData.name
                        strong: !inGroup
                        enabled: !groupOff
                        opacity: groupOff ? 0.45 : 1
                        PSwitch {
                            checked: !wrow.modelData.hidden
                            onToggled: Actions.run([root.scripts + "/bar_layout.py", "--toggle", wrow.modelData.id])
                        }
                    }
                }
            }
        }
    }

    Component {
        id: displaysPage
        Column {
            spacing: 18
            Group {
                title: "Monitors"
                SettingRow {
                    first: true
                    title: "Arrangement"
                    detail: "Position, resolution and scale of each monitor"
                    PButton {
                        text: "Arrange …"
                        onClicked: root.open(["monitors-arrange"])
                    }
                }
                SettingRow {
                    visible: root.laptopPanel
                    title: "Display mode"
                    detail: "Extend, mirror or one screen only"
                    PButton {
                        text: "Choose …"
                        onClicked: root.open(["display-mode"])
                    }
                }
                SettingRow {
                    title: "Layout"
                    detail: customMonitors.loaded ? "Your own arrangement is in use" : "Automatic, nothing arranged by hand"
                    PButton {
                        visible: customMonitors.loaded
                        text: "Reset"
                        onClicked: {
                            root.run(["monitors-reset"]);
                            customMonitors.reload();
                        }
                    }
                }
            }
        }
    }

    Component {
        id: systemPage
        Column {
            spacing: 18
            Group {
                title: "Sync"
                SettingRow {
                    first: true
                    title: "Mode"
                    detail: root.syncMode === "auto" ? "Changes from GitHub come in by themselves"
                            : root.syncMode === "off" ? "This machine does not sync"
                            : "Changes from GitHub wait for “Sync now”"
                    PSegmented {
                        options: [["auto", "Automatic"], ["review", "Review first"], ["off", "Off"]]
                        current: root.syncMode
                        onPicked: value => root.sync([value])
                    }
                }
                SettingRow {
                    title: "Sync now"
                    detail: "Fetch, check and apply what is new"
                    PButton {
                        text: "Start"
                        onClicked: root.sync(["now"])
                    }
                }
                SettingRow {
                    title: "More"
                    detail: "Installs, trusted machines, the log"
                    PButton {
                        text: "Open …"
                        onClicked: root.open(["sync"])
                    }
                }
            }
            Group {
                title: "Keyboard"
                SettingRow {
                    first: true
                    title: "Keyboard shortcuts"
                    detail: "Every key binding of the desktop"
                    PButton {
                        text: "Show …"
                        onClicked: root.open(["keys"])
                    }
                }
            }
        }
    }

    // ---- the parts of a page ----

    // a few rows in one frame, a caption above
    component Group: Column {
        property alias title: cap.text
        default property alias rows: inner.data
        width: parent ? parent.width : 0
        spacing: 8
        Caption {
            id: cap
        }
        Rectangle {
            width: parent.width
            height: inner.implicitHeight + 2
            color: Theme.well
            border.width: 1
            border.color: Theme.cardBorder
            Column {
                id: inner
                x: 1
                y: 1
                width: parent.width - 2
            }
        }
    }

    // one setting: what it is on the left (and a line on it), its control on the right
    component SettingRow: Item {
        id: srow
        property string title: ""
        property string detail: ""
        property bool first: false
        property bool strong: false
        property int indent: 0
        property int rowHeight: 48
        default property alias control: slot.data
        width: parent ? parent.width : 0
        height: visible ? Math.max(rowHeight, texts.implicitHeight + 20) : 0

        Rectangle {
            visible: !srow.first
            width: parent.width
            height: 1
            color: Theme.separator
        }
        Column {
            id: texts
            x: 14 + srow.indent
            width: parent.width - x - slot.width - 30
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Label {
                width: parent.width
                elide: Text.ElideRight
                text: srow.title
                bold: srow.strong
            }
            Label {
                visible: srow.detail !== ""
                width: parent.width
                wrapMode: Text.WordWrap
                small: true
                dim: true
                text: srow.detail
            }
        }
        Row {
            id: slot
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
        }
    }
}
