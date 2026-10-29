import QtQuick
import qs.services

// The desktop settings (bar/SettingsPopup.qml: look, bar size and widgets, monitors, sync, keys),
// behind a cog at the edge, next to the power menu.
Seg {
    id: seg

    padL: compact ? 4 : 7
    padR: compact ? 4 : 7
    tip: "Desktop settings<br><font color='" + Theme.dim + "'>look · bar size and widgets · monitors · sync · keys</font>"
    onClicked: togglePopup()
    popupKey: "settings"
    popupComponent: Component {
        SettingsPopup {}
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{F0493}"
        color: seg.hovered ? Theme.text : Theme.dim
    }
}
