import QtQuick
import qs.services

// The weather now (wttr.in, scripts/weather.py). Click: the next hours and three days.
Seg {
    id: seg

    readonly property var w: Feeds.weather.value
    shown: !!(w && w.icon)
    spacing: 6
    tip: w && w.desc ? Apps.esc(w.desc) + "<font color='" + Theme.dim + "'>  ·  feels " + w.feels + "°"
                       + (w.stale ? "  ·  from " + w.stale : "") + "</font>" : ""

    onClicked: togglePopup()

    popupKey: "weather"
    popupComponent: Component {
        WeatherPopup {}
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        text: seg.w?.icon ?? ""
        size: 16
        color: Theme.dim
    }
    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: seg.w ? seg.w.temp + "°C" : ""
        font.pixelSize: seg.compact ? Theme.fontCompact : Theme.fontSize
    }
}
