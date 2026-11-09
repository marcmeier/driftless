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
    // full size even where it was picked by hand falls back to compact on a screen too small for its
    // fixed parts (they would overlap); `fullNeed` keeps the width it needed, so the bar does not
    // flip back and forth: full size again once the screen is that wide, the size is picked again,
    // or something leaves the compact bar (music stops, the screen share ends) – then it tries anew
    readonly property string chosen: BarLayout.variantFor(modelData)
    property real fullNeed: 0
    property real compactNeed: 0          // the most the compact bar needed since it fell back
    onChosenChanged: fullNeed = compactNeed = 0
    readonly property string variant: chosen === "spacious" && fullNeed > content.width ? "compact" : chosen
    readonly property bool compact: variant === "compact"
    readonly property real need: leftSection.rigidWidth + centerSection.rigidWidth + rightSection.rigidWidth + 2 * 16
    // after the change settles: switching sizes changes `need` again (no binding loop). While the
    // parts are built anew `need` only grows; it shrinks when one goes.
    function checkFit() {
        if (variant === "spacious") {
            if (need > content.width) {
                fullNeed = need;
                compactNeed = 0;
            }
        } else if (fullNeed > 0) {
            // a part that went, not a narrower number (12:59 → 1:00, 10°C → 9°C), and full size could
            // fit now (what the compact bar needs, scaled as full size was to it), else no flicker
            if (need < compactNeed - 24 && need * fullNeed / compactNeed <= content.width)
                fullNeed = compactNeed = 0;
            else
                compactNeed = Math.max(compactNeed, need);
        }
    }
    onNeedChanged: Qt.callLater(checkFit)
    readonly property var monitor: Hyprland.monitors.values.find(m => m.name === modelData.name) ?? null

    anchors {
        top: true
        left: true
        right: true
    }
    // the strip, and room below it for its shadow: that room is see-through and lets clicks through
    readonly property int stripHeight: Theme.barGap + Theme.barHeight
    implicitHeight: stripHeight + 16
    exclusiveZone: stripHeight
    color: "transparent"
    mask: Region {
        item: strip
    }
    WlrLayershell.namespace: "driftless-bar"
    WlrLayershell.layer: WlrLayer.Top

    // for a pill on the right that can shrink (the media title), so it never runs under the clock:
    // the width from the centre island to the edge, and what the right side takes of it
    readonly property real sideRoom: content.width - centerSection.x - centerSection.width - 12
    readonly property real rightRigid: rightSection.rigidWidth
    // the same for the left (the window title): its fixed parts, and where the centre begins
    readonly property real leftRigid: leftSection.rigidWidth
    readonly property real leftEnd: centerSection.x - 16
    // what the centre may fill while it stays in the middle: the width between the wider side (only
    // the parts of the right that do not give way, so the media title and the clock do not wait for
    // each other) · and what of the centre does not give way (the clock without date and event)
    readonly property real centerRoom: content.width - 2 * Math.max(leftSection.rigidWidth, rightSection.rigidWidth) - 2 * 16
    readonly property real centerRigid: centerSection.rigidWidth

    Rectangle {
        id: strip
        anchors.left: parent.left
        anchors.right: parent.right
        height: bar.stripHeight
        color: Theme.surface
        layer.enabled: true
        layer.effect: CardShadow {
            shadowOpacity: Theme.shadowOpacity * 0.6
            shadowVerticalOffset: 2
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.border
        }
    }

    Item {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Theme.barHeight
        anchors.topMargin: Theme.barGap
        anchors.leftMargin: Theme.barSide
        anchors.rightMargin: Theme.barSide

        Section {
            id: leftSection
            name: "modules-left"
            anchors.left: parent.left
        }
        // in the middle while it fits there; when even its fixed part does not (a full-size bar on a
        // notebook while music plays), it moves aside as far as the right side needs, never into the
        // fixed part of the left (the window title gives way down to 60 px)
        Section {
            id: centerSection
            name: "modules-center"
            x: Math.round(Math.max(leftSection.rigidWidth + 16,
                                   Math.min((parent.width - width) / 2, parent.width - rightSection.rigidWidth - 16 - width)))
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
        spacing: bar.compact ? 18 : 28

        // the width of the pills that do not give way, with the gaps; of a `flexible` one only its
        // `rigidPart` (the clock: the time) or nothing (the media title)
        readonly property real rigidWidth: {
            let w = 0, n = 0;
            for (const c of children) {
                if (c.sourceComponent === undefined || !c.visible)
                    continue;
                n++;
                w += c.item.flexible ? (c.item.rigidPart || 0) : c.width;
            }
            return w + Math.max(0, n - 1) * spacing;
        }

        Repeater {
            model: BarLayout.section(section.name, bar.variant)
            // the groups read as groups by the wide gap between them, the widgets in one stay close
            delegate: Item {
                required property string modelData
                readonly property alias item: loader.item
                readonly property alias sourceComponent: loader.sourceComponent
                visible: !!(item && item.shown)
                implicitWidth: loader.implicitWidth
                implicitHeight: Theme.barHeight

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
            "custom/settings": settingsSeg,
            "custom/power": powerSeg
        })[name] || null;
    }

    Component { id: userPill; UserPill {} }
    Component { id: workspaces; Workspaces {} }
    Component { id: windowPill; WindowPill {} }
    Component { id: privacySeg; PrivacySeg {} }
    Component { id: settingsSeg; SettingsSeg {} }
    Component { id: dateTime; GroupPill { name: "group/datetime"; separators: true } }
    Component { id: mediaPill; MediaPill {} }
    Component { id: claudeGroup; GroupPill { name: "group/claude" } }
    Component { id: trayGroup; GroupPill { name: "group/tray" } }
    Component { id: askSeg; AskSeg {} }
    Component { id: claudeSeg; ClaudeSeg {} }
    Component { id: statusPill; GroupPill { name: "group/status" } }
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
        if (keys)
            stopKeys();   // a click on the bar opened it: the popup takes the keys
        keysReturn = null;
        popup.toggle(item, component, key, props || {});
    }
    function closePopup() {
        popup.close();
    }

    // ---- the keyboard (Super+B, IPC "bar keys"): the arrows or Tab walk the parts from left to right,
    // Enter, Space or Down open a part's popup (Esc there comes back here) or do what a click does,
    // Esc or a click beside the bar leave. The part shows the accent line of a focus and its tooltip.
    property var segs: []
    property bool keys: false
    property var navSeg: null
    property var lastNav: null      // where the keyboard was last time: the next Super+B starts there
    property var keysReturn: null   // the part whose popup the keyboard opened
    function registerSeg(s) {
        if (!segs.includes(s))
            segs.push(s);
    }
    function unregisterSeg(s) {
        const i = segs.indexOf(s);
        if (i >= 0)
            segs.splice(i, 1);
        if (navSeg === s)
            navSeg = null;
        if (lastNav === s)
            lastNav = null;
    }
    function reachable() {
        return segs.filter(s => s.visible && s.interactive && s.width > 0)
            .sort((a, b) => a.mapToItem(null, 0, 0).x - b.mapToItem(null, 0, 0).x);
    }
    function startKeys(at) {
        const list = reachable();
        if (!list.length)
            return false;
        popup.close();
        keys = true;
        navTo(list.includes(at) ? at : list.includes(lastNav) ? lastNav : list[0]);
        keyCatcher.forceActiveFocus();
        return true;
    }
    function stopKeys() {
        keys = false;
        navSeg = null;
        tooltip.hide(null);
    }
    function navTo(s) {
        navSeg = lastNav = s;
        tooltip.hide(null);
        if (s.tip)
            tooltip.show(s, () => s.tip);
    }
    function step(by) {
        const list = reachable();
        if (!list.length)
            return;
        const i = list.indexOf(navSeg);
        navTo(list[(Math.max(i, 0) + by + list.length) % list.length]);
    }
    function activate() {
        const s = navSeg;
        if (!s)
            return;
        if (s.popupComponent) {
            stopKeys();
            s.togglePopup();
            keysReturn = s;
        } else {
            tooltip.hide(null);
            s.clicked(Qt.LeftButton);
            // what it did may have changed the tooltip (keep awake on, a mute)
            if (s.tip)
                tooltip.show(s, () => s.tip);
        }
    }
    // The keys go to a window of their own, see-through, over the screen below the bar: Hyprland hands
    // the keyboard to a window that appears with it (like the power menu), not to the bar that is
    // already there, and a click on it, anywhere beside the bar, ends the mode.
    PanelWindow {
        screen: bar.modelData
        visible: bar.keys
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        margins.top: bar.stripHeight
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "driftless-keys"
        WlrLayershell.keyboardFocus: bar.keys ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: bar.stopKeys()
        }
        Item {
            id: keyCatcher
            focus: true
            Keys.onLeftPressed: bar.step(-1)
            Keys.onRightPressed: bar.step(1)
            Keys.onTabPressed: bar.step(1)
            Keys.onBacktabPressed: bar.step(-1)
            Keys.onReturnPressed: bar.activate()
            Keys.onEnterPressed: bar.activate()
            Keys.onSpacePressed: bar.activate()
            Keys.onDownPressed: bar.activate()
            Keys.onEscapePressed: bar.stopKeys()
        }
    }
    Connections {
        target: popup
        function onEscaped() {
            const s = bar.keysReturn;
            bar.keysReturn = null;
            if (s)
                bar.startKeys(s);
        }
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
