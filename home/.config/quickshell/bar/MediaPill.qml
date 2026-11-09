import QtQuick
import qs.services

// Now playing (MPRIS): previous · play/pause · next and the title, cut with "…" when it is long
// (compact: play/pause and the title). Click on the title: cover, progress and the players ·
// wheel: next/previous track · middle: play/pause · right: next track.
Pill {
    id: pill

    readonly property var player: Media.player
    readonly property bool playing: Media.playing
    shown: Media.shown
    implicitWidth: Media.shown ? row.implicitWidth + padding * 2 : 0

    // gives way beside the centre island: the title gets what the other pills and its buttons leave,
    // the artist only what the title leaves (and goes when that is too little for a name)
    readonly property bool flexible: true
    readonly property real buttons: padding * 2 + (prevSeg.shown ? prevSeg.width : 0) + playSeg.width
                                    + (nextSeg.shown ? nextSeg.width : 0) + title.padL + title.padR
    // what does not give way: the buttons and the shortest title (the marquee's 60), so the centre
    // makes room for them (Bar.centerRoom); the title then counts the rest of the right side only
    readonly property real rigidPart: buttons + 60
    readonly property real titleRoom: bar ? bar.sideRoom - (bar.rightRigid - rigidPart) - buttons : 400
    readonly property real artistRoom: Math.min(160, titleRoom - marquee.width - title.spacing)

    Seg {
        id: prevSeg
        shown: !pill.compact
        bar: pill.bar
        padL: 10
        padR: 2
        tip: "Previous"
        onClicked: if (pill.player) pill.player.previous()
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            text: "\u{F04AE}"
            size: 16
            color: parent.parent.hovered ? Theme.text : Theme.dim
        }
    }
    Seg {
        id: playSeg
        bar: pill.bar
        padL: pill.compact ? 8 : 2
        padR: 2
        tip: pill.playing ? "Pause" : "Play"
        onClicked: if (pill.player) pill.player.togglePlaying()
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            text: pill.playing ? "\u{F03E4}" : "\u{F040A}"
            size: 16
            color: pill.playing ? Theme.text : Theme.dim
        }
    }
    Seg {
        id: nextSeg
        shown: !pill.compact
        bar: pill.bar
        padL: 2
        padR: 4
        tip: "Next"
        onClicked: if (pill.player) pill.player.next()
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            text: "\u{F04AD}"
            size: 16
            color: parent.parent.hovered ? Theme.text : Theme.dim
        }
    }
    Seg {
        id: title
        bar: pill.bar
        padL: 6
        padR: pill.compact ? 10 : 12
        spacing: 8
        tip: {
            const p = pill.player;
            const head = Media.artist ? `<b>${Apps.esc(Media.title)}</b><br>${Apps.esc(Media.artist)}` : `<b>${Apps.esc(Media.title)}</b>`;
            return head + (p && p.trackAlbum ? `<br><font color='${Theme.dim}'>${Apps.esc(p.trackAlbum)}</font>` : "");
        }
        onClicked: button => {
            if (button !== Qt.MiddleButton && button !== Qt.RightButton)
                title.togglePopup();
            else if (pill.player)
                button === Qt.MiddleButton ? pill.player.togglePlaying() : pill.player.next();
        }
        onScrolled: steps => {
            if (pill.player)
                steps < 0 ? pill.player.next() : pill.player.previous();
        }

        popupKey: "media"
        popupComponent: Component {
            MediaPopup {}
        }

        Marquee {
            id: marquee
            anchors.verticalCenter: parent.verticalCenter
            text: Media.title
            // at least a few letters
            maxWidth: Math.max(60, Math.min(pill.compact ? 150 : 240, pill.titleRoom))
            font.weight: Font.DemiBold
            font.pixelSize: pill.compact ? Theme.fontCompact : Theme.fontSize
            color: pill.playing ? Theme.text : Theme.dim
        }
        Label {
            id: artist
            visible: !pill.compact && text !== "" && pill.artistRoom >= 48
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1
            width: Math.min(implicitWidth, pill.artistRoom)
            elide: Text.ElideRight
            text: Media.artist
            small: true
            color: Theme.dim
        }
    }
}
