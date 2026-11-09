import QtQuick
import qs.services

// The weather in detail (scripts/weather.py, wttr.in): now, the next hours and three days.
Item {
    id: root

    property var popup
    property var bar
    readonly property var w: Feeds.weather.value || {}

    implicitWidth: 380
    implicitHeight: root.w.icon ? column.implicitHeight : none.implicitHeight

    // no weather yet (wttr.in did not answer and nothing from the last hours)
    Label {
        id: none
        visible: !root.w.icon
        width: parent.width
        wrapMode: Text.Wrap
        text: "No weather: wttr.in does not answer. It asks again every half hour."
        dim: true
    }

    Column {
        id: column
        visible: !!root.w.icon
        width: parent.width
        spacing: 12

        // ---- now ----
        Row {
            width: parent.width
            spacing: 14
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: root.w.icon || ""
                size: 40
                color: Theme.dim
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x
                spacing: 2
                Row {
                    spacing: 8
                    Label {
                        text: (root.w.temp ?? "") + "°"
                        bold: true
                        font.pixelSize: Theme.fontFigure
                    }
                    Label {
                        anchors.baseline: parent.children[0].baseline
                        text: "feels " + (root.w.feels ?? "") + "°"
                        dim: true
                    }
                }
                // a long description with a long place: two lines, then cut
                Label {
                    width: parent.width
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: (root.w.desc || "") + (root.w.place ? "  ·  " + root.w.place : "")
                }
            }
        }

        Row {
            spacing: 18
            Row {
                spacing: 4
                Icon { text: "\u{F058E}"; size: 14; color: Theme.dim }
                Label { anchors.verticalCenter: parent.verticalCenter; text: (root.w.humidity ?? "") + "%"; small: true }
            }
            Row {
                spacing: 4
                Icon { text: "\u{F059D}"; size: 14; color: Theme.dim }
                Label { anchors.verticalCenter: parent.verticalCenter; text: root.w.wind || ""; small: true }
            }
        }
        Label {
            visible: !!root.w.stale
            text: "From " + Prefs.time(root.w.stale) + ": wttr.in does not answer"
            small: true
            color: Theme.warn
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.separator
        }

        // ---- the next hours ----
        Caption { text: "Next hours" }
        Row {
            width: parent.width
            Repeater {
                model: root.w.hours || []
                delegate: Column {
                    required property var modelData
                    width: column.width / Math.max(1, (root.w.hours || []).length)
                    spacing: 3
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Prefs.time(modelData.time, true)
                        small: true
                        dim: true
                    }
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.icon
                        size: 18
                        color: Theme.dim
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.temp + "°"
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.rain + "%"
                        small: true
                        color: modelData.rain >= 50 ? Theme.accent2 : Theme.dim
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.separator
        }

        // ---- three days ----
        Caption { text: "Next days" }
        Column {
            width: parent.width
            spacing: 6
            Repeater {
                model: root.w.days || []
                delegate: Item {
                    required property var modelData
                    width: parent.width
                    height: 24
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 116
                        text: modelData.label
                    }
                    Icon {
                        x: 104
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.icon
                        size: 18
                        color: Theme.dim
                    }
                    Label {
                        x: 140
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u{F058C} " + modelData.rain + "%"
                        small: true
                        color: modelData.rain >= 50 ? Theme.accent2 : Theme.dim
                    }
                    Label {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.min + "°  " + modelData.max + "°"
                    }
                }
            }
        }
    }
}
