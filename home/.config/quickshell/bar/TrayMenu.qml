import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.services

// A tray app's menu (DBusMenu), drawn like the rest of the shell. A submenu opens in place, with a
// way back at the top.
Item {
    id: root

    property var popup
    property var bar
    property var menu: null
    property var stack: []                     // the submenus opened on the way down
    readonly property var current: stack.length ? stack[stack.length - 1] : menu

    implicitWidth: 276
    implicitHeight: column.implicitHeight

    onMenuChanged: {
        stack = [];
        pendingFocus = false;
    }

    // the keyboard's focus into the menu when it was opened from the keyboard, and on each step down
    // or back: the first entry it can use. The entries come over D-Bus, maybe a moment later: until
    // then it waits (in a submenu on the way back, so Esc and Enter still have a place).
    property bool pendingFocus: false
    function focusFirst() {
        pendingFocus = true;
        Qt.callLater(tryFocus);
    }
    function tryFocus() {
        if (!pendingFocus)
            return;
        for (let i = 0; i < entries.count; i++) {
            const e = entries.itemAt(i);
            if (e && e.takeFocus()) {
                pendingFocus = false;
                return;
            }
        }
        if (stack.length)
            backRing.forceActiveFocus();
    }

    QsMenuOpener {
        id: opener
        menu: root.current
    }

    Column {
        id: column
        width: parent.width
        spacing: 1

        Rectangle {
            visible: root.stack.length > 0
            width: parent.width
            height: 30
            color: back.containsMouse ? Theme.hover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.quick } }
            Icon {
                x: 4
                anchors.verticalCenter: parent.verticalCenter
                text: "\u{F0141}"
                size: 16
                color: Theme.dim
            }
            Label {
                x: 28
                anchors.verticalCenter: parent.verticalCenter
                text: root.stack.length ? root.stack[root.stack.length - 1].text.replace(/_/g, "") : ""
                bold: true
            }
            MouseArea {
                id: back
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.stack = root.stack.slice(0, -1)
            }
            FocusRing {
                id: backRing
                inset: true
                onActivated: {
                    back.clicked(null);
                    root.focusFirst();
                }
            }
        }

        Repeater {
            id: entries
            model: opener.children
            onItemAdded: if (root.pendingFocus) Qt.callLater(root.tryFocus)
            delegate: Item {
                id: entry
                required property var modelData
                width: column.width
                height: modelData.isSeparator ? 9 : 30

                function takeFocus() {
                    if (modelData.isSeparator || !modelData.enabled)
                        return false;
                    ring.forceActiveFocus();
                    return true;
                }

                Rectangle {
                    visible: entry.modelData.isSeparator
                    anchors.centerIn: parent
                    width: parent.width - 8
                    height: 1
                    color: Theme.border
                }

                Rectangle {
                    visible: !entry.modelData.isSeparator
                    anchors.fill: parent
                    color: mouse.containsMouse && entry.modelData.enabled ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.quick } }
                    opacity: entry.modelData.enabled ? 1 : 0.45

                    // check box / radio button state, or the item's icon
                    Item {
                        id: lead
                        x: 6
                        width: 18
                        height: parent.height
                        Icon {
                            visible: entry.modelData.buttonType !== QsMenuButtonType.None
                            anchors.centerIn: parent
                            size: 16
                            text: entry.modelData.checkState === Qt.Checked
                                  ? (entry.modelData.buttonType === QsMenuButtonType.RadioButton ? "\u{F0133}" : "\u{F0132}")
                                  : (entry.modelData.buttonType === QsMenuButtonType.RadioButton ? "\u{F0130}" : "\u{F0131}")
                            color: entry.modelData.checkState === Qt.Checked ? Theme.accent2 : Theme.dim
                        }
                        IconImage {
                            readonly property string known: Apps.knownIcon(entry.modelData.icon)
                            visible: entry.modelData.buttonType === QsMenuButtonType.None && known !== ""
                            anchors.centerIn: parent
                            implicitSize: 16
                            source: known
                            // symbolic icons come dark: draw them in the text colour
                            layer.enabled: /symbolic/.test(entry.modelData.icon)
                            layer.effect: MultiEffect {
                                colorization: 1
                                colorizationColor: Theme.dim
                                brightness: 1
                            }
                        }
                    }
                    Label {
                        x: 32
                        width: parent.width - 56
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: entry.modelData.text.replace(/_(?=\S)/g, "")
                        color: entry.modelData.enabled ? Theme.text : Theme.faint   // greyed out, like the app means it
                    }
                    Icon {
                        visible: entry.modelData.hasChildren
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u{F0142}"
                        size: 16
                        color: Theme.dim
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: entry.modelData.enabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (entry.modelData.hasChildren) {
                                root.stack = root.stack.concat([entry.modelData]);
                            } else {
                                entry.modelData.triggered();
                                root.popup.close();
                            }
                        }
                    }
                    FocusRing {
                        id: ring
                        inset: true
                        enabled: entry.modelData.enabled
                        onActivated: {
                            // taken now: this entry is gone once a submenu opens
                            const menu = root, down = entry.modelData.hasChildren;
                            mouse.clicked(null);
                            if (down)
                                menu.focusFirst();
                        }
                    }
                }
            }
        }
    }
}
