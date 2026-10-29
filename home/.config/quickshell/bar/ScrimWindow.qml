import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.services

// A window over the whole screen in the desk colour, with all the keys, for one box in the middle:
// the power menu, the password dialog, the picture editor. A click beside the box: dismissed (left
// unanswered where a click must not decide, the password dialog).
PanelWindow {
    id: win

    required property bool open
    required property string name   // the layer's namespace: driftless-<name>
    signal dismissed

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: open
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "driftless-" + name
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        MouseArea {
            anchors.fill: parent
            onClicked: win.dismissed()
        }
    }
}
