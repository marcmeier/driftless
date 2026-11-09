import QtQuick
import Quickshell.Services.UPower
import qs.services

// The battery (UPower): charge, time left, power draw, health, and the power profile
// (power-profiles-daemon).
Item {
    id: root

    property var popup
    property var bar
    readonly property var dev: UPower.displayDevice
    readonly property var battery: UPower.devices.values.find(d => d.isLaptopBattery) || null
    readonly property int percent: Math.round((dev ? dev.percentage : 0) * 100)
    readonly property bool charging: !!dev && dev.state === UPowerDeviceState.Charging
    readonly property bool low: percent <= 12 && !!dev && dev.state === UPowerDeviceState.Discharging
    readonly property string words: Battery.state(dev)

    implicitWidth: 400
    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: 12

        PopupHeader {
            icon: Glyphs.battery(root.percent, root.charging)
            title: "Battery"
            status: root.percent + "%" + (root.words ? "  ·  " + root.words : "")
            statusColor: root.low ? Theme.crit : Theme.dim
        }

        PMeter {
            width: parent.width
            percent: root.percent
            tone: root.percent <= 12 ? Theme.crit : root.percent <= 25 ? Theme.warn : Theme.accent
        }

        Row {
            spacing: 18
            Label {
                visible: !!root.dev && Math.abs(root.dev.changeRate) > 0.05
                text: (root.charging ? "Charging at " : "Using ") + (root.dev ? Math.abs(root.dev.changeRate).toFixed(1) : "") + " W"
                small: true
                dim: true
            }
            Label {
                visible: !!root.battery && root.battery.healthSupported
                text: "Health " + (root.battery ? Math.round(root.battery.healthPercentage) : 0) + "%"
                small: true
                dim: true
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.separator
        }

        Caption { text: "Power profile" }
        // the same choice and words as in the settings (Power → Battery)
        PSegmented {
            options: [[String(PowerProfile.PowerSaver), "Saver"], [String(PowerProfile.Balanced), "Balanced"]]
                     .concat(PowerProfiles.hasPerformanceProfile ? [[String(PowerProfile.Performance), "Performance"]] : [])
            current: String(PowerProfiles.profile)
            onPicked: value => PowerProfiles.profile = Number(value)
        }
        Label {
            width: parent.width
            wrapMode: Text.Wrap
            small: true
            dim: true
            text: PowerProfiles.profile === PowerProfile.PowerSaver ? "Longer on battery, a little slower"
                  : PowerProfiles.profile === PowerProfile.Performance ? "Fastest, the fan and battery pay for it"
                  : "Fast when needed, quiet otherwise"
        }
    }
}
