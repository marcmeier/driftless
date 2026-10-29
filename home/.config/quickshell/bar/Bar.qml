import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services

// One bar per screen: a flat strip along the top edge with a line below it, its groups in three sections. Which widgets, in which order, and whether
// the screen gets the compact bar comes from BarLayout (bar.jsonc and this machine's layout.json).
// Each bar has its own tooltip and popup window right below it.
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData
    readonly property string variant: BarLayout.variantFor(modelData)
    readonly property bool compact: variant === "compact"
    readonly property var monitor: Hyprland.monitors.values.find(m => m.name === modelData.name) ?? null

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barGap + Theme.barHeight
    exclusiveZone: implicitHeight
    color: Theme.surface
    WlrLayershell.namespace: "driftless-bar"
    WlrLayershell.layer: WlrLayer.Top

    // for a pill on the right that can shrink (the media title), so it never runs under the clock:
    // the width from the centre island to the edge, and what the right side takes of it
    readonly property real sideRoom: (content.width - centerSection.width) / 2 - 12
    readonly property real rightRigid: rightSection.rigidWidth

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.border
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.topMargin: Theme.barGap
        anchors.leftMargin: Theme.barSide
        anchors.rightMargin: Theme.barSide

        Section {
            name: "modules-left"
            anchors.left: parent.left
        }
        Section {
            id: centerSection
            name: "modules-center"
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Section {
            id: rightSection
            name: "modules-right"
            anchors.right: parent.right
        }
    }

    component Section: Row {
        id: section
        property string name
        height: Theme.barHeight
        spacing: bar.compact ? 14 : 20

        // the width of the pills that do not give way (all but those with `flexible`), with the gaps
        readonly property real rigidWidth: {
            let w = 0, n = 0;
            for (const c of children) {
                if (c.sourceComponent === undefined || !c.visible)
                    continue;
                n++;
                if (!c.item.flexible)
                    w += c.width;
            }
            return w + Math.max(0, n - 1) * spacing;
        }

        Repeater {
            model: BarLayout.section(section.name, bar.variant)
            // a thin line in the middle of the gap before every group but the first: the groups read
            // as groups, the widgets in one stay close together
            delegate: Item {
                required property string modelData
                readonly property alias item: loader.item
                readonly property alias sourceComponent: loader.sourceComponent
                visible: !!(item && item.shown)
                implicitWidth: loader.implicitWidth
                implicitHeight: Theme.barHeight

                Rectangle {
                    visible: !parent.Positioner.isFirstItem
                    x: -Math.round(section.spacing / 2) - 1
                    width: 1
                    height: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.separator
                }
                Loader {
                    id: loader
                    sourceComponent: bar.widget(parent.modelData)
                    onLoaded: item.bar = bar
                }
            }
        }
    }

    // ---- the widgets by their names in bar.jsonc ----

    function widget(name) {
        return ({
            "group/user": userPill,
            "group/workspaces": workspaces,
            "custom/window": windowPill,
            "custom/privacy": privacySeg,
            "group/datetime": dateTime,
            "group/media": mediaPill,
            "group/claude": claudeGroup,
            "group/tray": trayGroup,
            "custom/ask": askSeg,
            "custom/claude": claudeSeg,
            "group/status": statusPill,
            "group/pending": pendingPill,
            "group/session": sessionPill,
            "clock": clockSeg,
            "custom/weather": weatherSeg,
            "network": networkSeg,
            "bluetooth": bluetoothSeg,
            "pulseaudio": volumeSeg,
            "custom/dictate": dictateSeg,
            "battery": batterySeg,
            "tray": traySeg,
            "custom/updates": updatesSeg,
            "custom/sync": syncSeg,
            "idle_inhibitor": idleSeg,
            "custom/notifications": notifySeg,
            "custom/power": powerSeg
        })[name] || null;
    }

    Component { id: userPill; UserPill {} }
    Component { id: workspaces; Workspaces {} }
    Component { id: windowPill; WindowPill {} }
    Component { id: privacySeg; PrivacySeg {} }
    Component { id: dateTime; GroupPill { name: "group/datetime"; separators: true } }
    Component { id: mediaPill; MediaPill {} }
    Component { id: claudeGroup; GroupPill { name: "group/claude" } }
    Component { id: trayGroup; GroupPill { name: "group/tray" } }
    Component { id: askSeg; AskSeg {} }
    Component { id: claudeSeg; ClaudeSeg {} }
    Component { id: statusPill; GroupPill { name: "group/status" } }
    Component { id: pendingPill; GroupPill { name: "group/pending" } }
    Component { id: sessionPill; GroupPill { name: "group/session" } }
    Component { id: clockSeg; ClockSeg {} }
    Component { id: weatherSeg; WeatherSeg {} }
    Component { id: networkSeg; NetworkSeg {} }
    Component { id: bluetoothSeg; BluetoothSeg {} }
    Component { id: volumeSeg; VolumeSeg {} }
    Component { id: dictateSeg; DictateSeg {} }
    Component { id: batterySeg; BatterySeg {} }
    Component { id: traySeg; TraySeg {} }
    Component { id: updatesSeg; UpdatesSeg {} }
    Component { id: syncSeg; SyncSeg {} }
    Component { id: idleSeg; IdleSeg {} }
    Component { id: notifySeg; NotifySeg {} }
    Component { id: powerSeg; PowerSeg {} }

    // ---- tooltips and popups ----

    // a tray app's menu, kept here: an icon in the tray's box goes with the box when its menu replaces it
    property Component trayMenu: Component {
        TrayMenu {}
    }

    BarTooltip {
        id: tooltip
        bar: bar
    }
    BarPopup {
        id: popup
        bar: bar
    }

    // text: a function that returns rich text (read again while it shows)
    function showTip(item, text) {
        if (!popup.open)
            tooltip.show(item, text);
    }
    function hideTip(item) {
        tooltip.hide(item);
    }
    function togglePopup(item, component, key, props) {
        tooltip.hide(null);
        popup.toggle(item, component, key, props || {});
    }
    function closePopup() {
        popup.close();
    }

    // the parts that open a popup, by its name, for the IPC ("popup calendar")
    property var popupOwners: ({})
    function registerPopup(key, item) {
        popupOwners[key] = item;
    }
    function openNamed(key) {
        const item = popupOwners[key];
        if (!item || !item.visible)
            return false;
        item.togglePopup();
        return true;
    }
}
