import QtQuick
import qs.services

// The privacy indicator: a coloured capsule that is only there while an app records the microphone,
// uses the camera or shares the screen, with one symbol for each (services/Privacy.qml). Amber, red
// while the screen is shared. Click: mute the microphone ·
// wheel: its level.
Seg {
    id: seg

    shown: Privacy.active
    padL: 3
    padR: 3
    hoverColor: "transparent"
    interactive: Privacy.mic
    tip: {
        const line = (what, apps, extra) => `${what}${extra || ""}<font color='${Theme.dim}'>  ·  ${Apps.esc(apps.join(", "))}</font>`;
        const lines = [];
        if (Privacy.mic)
            lines.push(line("Microphone", Privacy.micApps, Privacy.micMuted ? ` <font color='${Theme.crit}'>muted</font>` : ""));
        if (Privacy.camera)
            lines.push(line("Camera", Privacy.cameraApps));
        if (Privacy.screen)
            lines.push(line("Screen shared", Privacy.screenApps));
        if (Privacy.mic)
            lines.push(`<font color='${Theme.dim}'>Click: mute  ·  Wheel: microphone level</font>`);
        return lines.join("<br>");
    }

    onClicked: if (Privacy.mic) Privacy.toggleMute()
    onScrolled: steps => {
        if (Privacy.mic)
            Privacy.nudgeLevel(steps);
    }

    Item {
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: capsule.width
        implicitHeight: capsule.height

        Rectangle {
            id: capsule
            anchors.centerIn: parent
            // the same room around the symbols as between them (measured on their ink)
            width: icons.implicitWidth + 2 * (icons.spacing + 1)
            height: Theme.barHeight - 8
            color: Privacy.screen ? Theme.crit : Theme.warn
            opacity: seg.hovered && seg.interactive ? 0.85 : 1

            Row {
                id: icons
                x: Math.round((capsule.width - implicitWidth) / 2)
                y: Math.round((capsule.height - implicitHeight) / 2)
                spacing: 7

                InkIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Privacy.mic
                    text: Glyphs.mic(Privacy.micMuted)
                    color: Theme.accentInk
                }
                InkIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Privacy.camera
                    text: "\u{F05A0}"
                    color: Theme.accentInk
                }
                InkIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Privacy.screen
                    text: "\u{F1483}"
                    color: Theme.accentInk
                }
            }
        }
    }
}
