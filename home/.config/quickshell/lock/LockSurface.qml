import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import QtQuick
import qs.services
import "../bar"

// One screen of the lock (lock/Lock.qml): the login screen's look, dark in both looks (Theme.night). Every screen takes the password,
// so typing works wherever the pointer is; what you type shows on all of them.
WlSessionLockSurface {
    id: surface

    required property var lockScope
    readonly property var ctx: lockScope

    // the plain look: the night desk colour, nothing behind it (the login screen is the same)
    color: Theme.night.desk

    Item {
        id: content
        anchors.fill: parent
        visible: !surface.ctx.unlocking

        // ---- the clock, the date, your name and the password, in one column ----
        Column {
            id: box
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.5) - 150
            width: 280
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: Theme.font
                font.pixelSize: 72
                font.weight: Font.Light
                color: Theme.night.strong
                text: Qt.formatTime(time.date, "hh:mm")
                renderType: Text.NativeRendering
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.night.dim
                text: Qt.locale().toString(time.date, "dddd, d. MMMM")
            }
            Item {
                width: 1
                height: 30
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Feeds.userName
                color: Theme.night.text
            }
            PasswordField {
                id: field
                theme: Theme.night
                caps: Keyboard.caps
                onKeyPressed: Keyboard.check()
                width: parent.width
                text: surface.ctx.password
                checking: surface.ctx.checking
                failed: surface.ctx.failed
                onEdited: t => {
                    surface.ctx.password = t;
                    if (t !== "")
                        surface.ctx.failed = false;
                }
                onAccepted: surface.ctx.submit()
                onEscaped: surface.ctx.password = ""
            }
            // why it did not open, Caps Lock, or what PAM asks
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                height: 16
                small: true
                text: surface.ctx.message !== "" ? surface.ctx.message : Keyboard.caps ? "Caps Lock is on" : ""
                color: surface.ctx.failed ? Theme.night.crit : Keyboard.caps ? Theme.night.warn : Theme.night.dim
            }
        }
        SystemClock {
            id: time
            precision: SystemClock.Minutes
        }
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: field.focusInput()
        }

        // ---- at the bottom: what waits, quietly (no notification text on a locked screen) ----
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
            spacing: 22

            readonly property var bat: UPower.displayDevice
            readonly property bool hasBat: !!bat && bat.isLaptopBattery && bat.isPresent

            Row {
                visible: parent.hasBat
                spacing: 6
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.parent.hasBat ? Glyphs.battery(Math.round(parent.parent.bat.percentage * 100), parent.parent.bat.state === UPowerDeviceState.Charging) : ""
                    color: Theme.night.dim
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    small: true
                    color: Theme.night.dim
                    text: parent.parent.hasBat ? Math.round(parent.parent.bat.percentage * 100) + "%" : ""
                }
            }
            Row {
                visible: Notifs.count > 0
                spacing: 6
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Notifs.dnd ? "\u{F009B}" : "\u{F009E}"
                    color: Theme.night.dim
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    small: true
                    color: Theme.night.dim
                    text: Notifs.count + (Notifs.count === 1 ? " notification" : " notifications")
                }
            }
        }
    }

    Component.onCompleted: field.focusInput()
}
