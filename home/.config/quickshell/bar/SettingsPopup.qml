import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs.services

// The desktop settings (a click on your name; walker menus before), laid out like a settings app: the
// pages on the left (appearance and palette, bar, monitors, notifications, mouse and keyboard, power,
// system), on the right one row per setting, what it is on the left and its switch or button on the
// right. Every choice is this machine's own (scripts/settings-menu.sh, scripts/bar_layout.py,
// scripts/prefs.py, scripts/sync-menu.sh).
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
        ["displays", "Displays", "\u{F037A}", "The monitors and the night light"],
        ["notifications", "Notifications", "\u{F009A}", "When they pop up, and the list"],
        ["input", "Mouse & keyboard", "\u{F037D}", "Pointer, touchpad, key repeat and shortcuts"],
        ["power", "Power", "\u{F0425}", "When the screen locks and turns off, the power profile"],
        ["system", "System", "\u{F0493}", "Sync with your other machines, this machine"]
    ]
    readonly property var current: pages.find(p => p[0] === page) || pages[0]

    implicitWidth: 760
    implicitHeight: 460

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

    // ---- mouse, touchpad and keyboard: what Hyprland has now (prefs.py input) ----
    property var input: ({})
    function setInput(key, value) {
        root.input = Object.assign({}, root.input, { [key]: value });
        Prefs.set(key, value);
    }
    Process {
        id: inputNow
        running: true
        command: [Prefs.script, "input"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.input = JSON.parse(text);
                } catch (e) {}
            }
        }
    }
    // the speed while the slider moves, handed over once it rests
    property real pendingSpeed: 0
    Timer {
        id: speedLater
        interval: 250
        onTriggered: root.setInput("pointerSpeed", root.pendingSpeed)
    }

    // this machine (prefs.py about), for System
    property var about: ({})
    Process {
        running: true
        command: [Prefs.script, "about"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.about = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    readonly property var laptop: UPower.displayDevice && UPower.displayDevice.isLaptopBattery && UPower.displayDevice.isPresent
    function minutes(s) {
        return s % 3600 === 0 ? s / 3600 + (s === 3600 ? " hour" : " hours") : Math.round(s / 60) + " minutes";
    }
    readonly property var idleTimes: [["300", "5 min"], ["600", "10 min"], ["900", "15 min"], ["1800", "30 min"], ["0", "Never"]]

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
                sourceComponent: ({ appearance: appearancePage, bar: barPage, displays: displaysPage,
                                    notifications: notificationsPage, input: inputPage, power: powerPage,
                                    system: systemPage })[root.page]
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
                title: "Clock"
                SettingRow {
                    first: true
                    title: "24-hour time"
                    detail: Prefs.clock24 ? "14:30, not 2:30 PM" : "2:30 PM, not 14:30"
                    PSwitch {
                        checked: Prefs.clock24
                        onToggled: Prefs.set("clock24", !Prefs.clock24)
                    }
                }
                SettingRow {
                    title: "Seconds"
                    PSwitch {
                        checked: Prefs.clockSeconds
                        onToggled: Prefs.set("clockSeconds", !Prefs.clockSeconds)
                    }
                }
                SettingRow {
                    title: "Date next to the time"
                    detail: "The weekday, day and month; the calendar is a click on the clock"
                    PSwitch {
                        checked: Prefs.clockDate
                        onToggled: Prefs.set("clockDate", !Prefs.clockDate)
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
                title: "Night light"
                SettingRow {
                    first: true
                    title: "Warmer colours"
                    detail: Prefs.nightLight === "sun"
                            ? "From sunset (" + NightLight.sun.sunset + ") to sunrise (" + NightLight.sun.sunrise + ")"
                              + (NightLight.active ? ", on now" : "")
                            : Prefs.nightLight === "on" ? "On until you turn it off" : "Off: the colours as they are"
                    PSegmented {
                        options: [["off", "Off"], ["sun", "At night"], ["on", "Always"]]
                        current: Prefs.nightLight
                        onPicked: value => Prefs.set("nightLight", value)
                    }
                }
                SettingRow {
                    visible: Prefs.nightLight !== "off"
                    title: "Warmth"
                    detail: Prefs.nightTemp + " K"
                    PSegmented {
                        options: [["4500", "Slight"], ["4000", "Medium"], ["3500", "Warm"], ["3000", "Very warm"]]
                        current: String(Prefs.nightTemp)
                        onPicked: value => Prefs.set("nightTemp", Number(value))
                    }
                }
            }
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
        id: notificationsPage
        Column {
            spacing: 18
            Group {
                title: "Pop-ups"
                SettingRow {
                    first: true
                    title: "Do not disturb"
                    detail: Notifs.dnd ? "Only critical ones pop up, the rest wait in the list"
                                       : "Notifications pop up at the top right"
                    PSwitch {
                        checked: Notifs.dnd
                        onToggled: Notifs.setDnd(!Notifs.dnd)
                    }
                }
                SettingRow {
                    title: "Quiet while fullscreen"
                    detail: Prefs.holdInFullscreen
                            ? "Games and videos are not interrupted; afterwards one card says what came"
                            : "They pop up over fullscreen windows too"
                    PSwitch {
                        checked: Prefs.holdInFullscreen
                        onToggled: Prefs.set("holdInFullscreen", !Prefs.holdInFullscreen)
                    }
                }
            }
            Group {
                title: "List"
                SettingRow {
                    first: true
                    title: Notifs.count === 0 ? "Nothing in the list" : Notifs.count === 1 ? "One notification" : Notifs.count + " notifications"
                    detail: "Kept on this machine for " + Notifs.keepDays + " days, at most " + Notifs.maxHistory
                    PButton {
                        visible: Notifs.count > 0
                        text: "Clear"
                        onClicked: Notifs.clear()
                    }
                }
            }
        }
    }

    Component {
        id: inputPage
        Column {
            spacing: 18
            Component.onCompleted: inputNow.running = true
            Group {
                title: "Mouse"
                SettingRow {
                    first: true
                    title: "Pointer speed"
                    readonly property real speed: root.input.pointerSpeed || 0
                    detail: speed === 0 ? "As the device moves it" : speed < 0 ? "Slower" : "Faster"
                    PSlider {
                        implicitWidth: 160
                        value: ((root.input.pointerSpeed || 0) + 1) / 2
                        step: 0.05
                        onMoved: v => {
                            root.pendingSpeed = Math.round((v * 2 - 1) * 20) / 20;
                            speedLater.restart();
                        }
                    }
                    PButton {
                        visible: (root.input.pointerSpeed || 0) !== 0
                        text: "Reset"
                        flat: true
                        onClicked: root.setInput("pointerSpeed", 0)
                    }
                }
                SettingRow {
                    title: "Focus follows the mouse"
                    detail: root.input.followMouse !== false ? "The window under the pointer gets the keys"
                                                             : "A click gives a window the keys"
                    PSwitch {
                        checked: root.input.followMouse !== false
                        onToggled: root.setInput("followMouse", !checked)
                    }
                }
            }
            Group {
                visible: !!root.input.touchpad
                title: "Touchpad"
                SettingRow {
                    first: true
                    title: "Natural scrolling"
                    detail: "The content follows your fingers"
                    PSwitch {
                        checked: !!root.input.naturalScroll
                        onToggled: root.setInput("naturalScroll", !checked)
                    }
                }
                SettingRow {
                    title: "Tap to click"
                    PSwitch {
                        checked: !!root.input.tapToClick
                        onToggled: root.setInput("tapToClick", !checked)
                    }
                }
                SettingRow {
                    title: "Off while typing"
                    detail: "No stray clicks from the heel of your hand"
                    PSwitch {
                        checked: !!root.input.disableWhileTyping
                        onToggled: root.setInput("disableWhileTyping", !checked)
                    }
                }
            }
            Group {
                title: "Keyboard"
                SettingRow {
                    first: true
                    title: "Repeat after"
                    detail: "How long a held key waits before it repeats"
                    PSegmented {
                        options: [["600", "Long"], ["400", "Medium"], ["250", "Short"]]
                        current: String(root.input.repeatDelay || "")
                        onPicked: value => root.setInput("repeatDelay", Number(value))
                    }
                }
                SettingRow {
                    title: "Repeat speed"
                    PSegmented {
                        options: [["25", "Slow"], ["35", "Medium"], ["50", "Fast"]]
                        current: String(root.input.repeatRate || "")
                        onPicked: value => root.setInput("repeatRate", Number(value))
                    }
                }
                SettingRow {
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

    Component {
        id: powerPage
        Column {
            spacing: 18
            Group {
                title: "When you are away"
                SettingRow {
                    first: true
                    title: "Lock the screen"
                    detail: Prefs.lockAfter === 0 ? "Only by hand (SUPER + L) and before the machine sleeps"
                                                  : "After " + root.minutes(Prefs.lockAfter) + " without input, and before sleep"
                    PSegmented {
                        options: root.idleTimes
                        current: String(Prefs.lockAfter)
                        onPicked: value => Prefs.set("lockAfter", Number(value))
                    }
                }
                SettingRow {
                    title: "Turn the screen off"
                    detail: Prefs.screenOffAfter === 0 ? "Never by itself"
                                                       : "After " + root.minutes(Prefs.screenOffAfter) + " without input"
                    PSegmented {
                        options: root.idleTimes
                        current: String(Prefs.screenOffAfter)
                        onPicked: value => Prefs.set("screenOffAfter", Number(value))
                    }
                }
                SettingRow {
                    title: "Keep awake"
                    detail: KeepAwake.on ? "On: no lock, the screen stays on (the cup in the bar)"
                                         : "For a presentation or a long download, until you turn it off"
                    PSwitch {
                        checked: KeepAwake.on
                        onToggled: KeepAwake.on = !KeepAwake.on
                    }
                }
            }
            Group {
                visible: root.laptop
                title: "Battery"
                SettingRow {
                    first: true
                    title: "Power profile"
                    detail: PowerProfiles.profile === PowerProfile.PowerSaver ? "Longer on battery, a little slower"
                            : PowerProfiles.profile === PowerProfile.Performance ? "Fastest, the fan and battery pay for it"
                            : "Fast when needed, quiet otherwise"
                    PSegmented {
                        options: [[String(PowerProfile.PowerSaver), "Saver"], [String(PowerProfile.Balanced), "Balanced"]]
                                 .concat(PowerProfiles.hasPerformanceProfile ? [[String(PowerProfile.Performance), "Performance"]] : [])
                        current: String(PowerProfiles.profile)
                        onPicked: value => PowerProfiles.profile = Number(value)
                    }
                }
            }
            Group {
                title: "Session"
                SettingRow {
                    first: true
                    title: "Lock, log out, sleep, restart, shut down"
                    detail: "The power menu (SUPER + SHIFT + M)"
                    PButton {
                        text: "Open …"
                        onClicked: {
                            if (root.popup)
                                root.popup.close();
                            Session.powerMenu();
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
            // what this machine is, one fact per row
            Group {
                title: "About"
                Repeater {
                    model: [["Machine", root.about.host], ["driftless", root.about.version ? "v" + root.about.version : ""],
                            ["System", [root.about.os, root.about.kernel].filter(x => !!x).join(" · ")],
                            ["Hyprland", root.about.hyprland], ["Processor", root.about.cpu], ["Memory", root.about.memory]]
                            .filter(r => !!r[1])
                    SettingRow {
                        id: fact
                        required property var modelData
                        required property int index
                        first: index === 0
                        rowHeight: 36
                        title: modelData[0]
                        Label {
                            text: fact.modelData[1]
                            dim: true
                            width: Math.min(implicitWidth, 300)
                            elide: Text.ElideRight
                        }
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
