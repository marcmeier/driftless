import QtQuick
import Quickshell.Networking
import qs.services

// Wi-Fi (NetworkManager): on/off, the networks around, strongest first. Click a known network to join
// it; a new one asks for its password in nmtui. Settings: nm-connection-editor.
Item {
    id: root

    property var popup
    property var bar

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null
    readonly property var networks: wifi ? wifi.networks.values.filter(n => n.name !== "")
                                              .sort((a, b) => (b.connected - a.connected) || (b.known - a.known)
                                                              || (b.signalStrength - a.signalStrength)).slice(0, 9) : []

    // look for networks while the popup is open
    Component.onCompleted: if (wifi) wifi.scannerEnabled = true
    Component.onDestruction: if (wifi) wifi.scannerEnabled = false

    implicitWidth: 320
    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: 10

        PopupHeader {
            icon: Networking.wifiEnabled ? "\u{F0928}" : "\u{F05AA}"
            title: "Wi-Fi"
            PSwitch {
                checked: Networking.wifiEnabled
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            }
        }

        Label {
            visible: Networking.wifiEnabled && root.networks.length === 0
            text: "Looking for networks …"
            dim: true
        }

        Column {
            visible: Networking.wifiEnabled
            width: parent.width
            spacing: 2
            Repeater {
                model: root.networks
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    readonly property bool busy: modelData.stateChanging
                    width: column.width
                    height: 36
                    color: modelData.connected ? Theme.raised : mouse.containsMouse ? Theme.hover : "transparent"

                    Icon {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: Glyphs.wifi(modelData.signalStrength)
                        size: 16
                        color: modelData.connected ? Theme.accent2 : Theme.text
                    }
                    Label {
                        x: 38
                        width: parent.width - 110
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: modelData.name
                        bold: modelData.connected
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.busy ? "…" : modelData.connected ? "connected" : modelData.known ? "known" : ""
                            small: true
                            color: modelData.connected ? Theme.accent2 : Theme.faint
                        }
                        Icon {
                            visible: modelData.security !== WifiSecurityType.Open
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\u{F033E}"
                            size: 12
                            color: Theme.faint
                        }
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const n = row.modelData;
                            if (n.connected)
                                n.disconnect();
                            else if (n.known || n.security === WifiSecurityType.Open)
                                n.connect();
                            else {
                                Actions.launch(["ghostty", "-e", "nmtui-connect", n.name]);
                                root.popup.close();
                            }
                        }
                    }
                }
            }
        }

        ButtonRow {
            PButton {
                icon: "\u{F0493}"
                text: "Network settings …"
                onClicked: {
                    Actions.launch(["nm-connection-editor"]);
                    root.popup.close();
                }
            }
        }
    }
}
