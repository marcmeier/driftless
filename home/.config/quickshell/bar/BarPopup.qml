import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services

// The popup below a bar (calendar, media, audio, ...): one box that hangs from the bar's line under
// the item that was clicked and jumps to the next one. A click on the same item, a click anywhere else or Esc
// closes it. Only the card takes input; the rest of the window lets clicks through. It fades in and
// slides down a few pixels from the bar's line; it goes at once.
PanelWindow {
    id: win

    property var bar
    property bool open: false
    property string key: ""
    property real anchorX: 0
    signal escaped                 // closed with Esc (the bar's keyboard mode goes on from there)

    screen: bar.screen
    anchors {
        top: true
        left: true
        right: true
    }
    margins.top: bar.stripHeight - 1
    implicitHeight: Math.round(bar.screen.height * 0.85)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: open
    mask: Region {
        item: card
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "driftless-popup"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [win, win.bar]
        active: win.open && win.visible
        onCleared: win.close()
    }

    function toggle(item, component, k, props) {
        if (open && key === k) {
            close();
            return;
        }
        anchorX = item.mapToItem(null, item.width / 2, 0).x;
        loader.props = props;
        if (loader.sourceComponent === component && loader.item)
            loader.apply();
        else
            loader.sourceComponent = component;
        key = k;
        open = true;
        card.forceActiveFocus();
        enter.restart();
    }
    function close() {
        open = false;
        key = "";
    }

    // the content goes when the box is closed
    Timer {
        running: !win.open
        interval: 50
        onTriggered: loader.sourceComponent = null
    }

    // the card comes in: from a little under the bar's line and faint, to its place
    property real shown: 1
    NumberAnimation {
        id: enter
        target: win
        property: "shown"
        from: 0
        to: 1
        duration: Theme.enter
        easing.type: Easing.OutCubic
    }

    Rectangle {
        id: card
        // the content may ask for less room around it (`pad`)
        readonly property int pad: loader.item && loader.item.pad !== undefined ? loader.item.pad : 20
        width: (loader.item ? loader.item.implicitWidth : 0) + pad * 2
        height: (loader.item ? loader.item.implicitHeight : 0) + pad * 2
        x: Math.round(Math.max(Theme.barSide, Math.min(win.width - width - Theme.barSide, win.anchorX - width / 2)))
        y: Math.round((win.shown - 1) * Theme.rise)
        opacity: win.shown
        color: Theme.card
        border.width: 1
        border.color: Theme.cardBorder
        focus: true
        // the shadow; the content is clipped in its own item, a clip here would cut the shadow off
        layer.enabled: true
        layer.effect: CardShadow {}
        Keys.onEscapePressed: {
            win.escaped();
            win.close();
        }

        // inside the 1 px frame
        Item {
            anchors.fill: parent
            anchors.margins: 1
            clip: true

            Loader {
                id: loader
                property var props: ({})
                x: card.pad - 1
                y: card.pad - 1

                function apply() {
                    if (!item)
                        return;
                    if ("popup" in item)
                        item.popup = win;
                    if ("bar" in item)
                        item.bar = win.bar;
                    if ("room" in item)
                        item.room = Qt.binding(() => win.height - card.pad * 2);
                    for (const k in props)
                        item[k] = props[k];
                }
                onLoaded: apply()
            }
        }
    }
}
