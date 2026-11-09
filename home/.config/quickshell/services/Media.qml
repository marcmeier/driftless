pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// The player the bar shows: the one you picked in the media popup while it plays (or nothing else
// does), else the first one that plays, else one that is paused. playerctld only mirrors the others.
Singleton {
    id: media

    readonly property var players: Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"))
    property var chosen: null

    readonly property var player: {
        const playing = players.filter(p => p.isPlaying);
        if (chosen && players.includes(chosen) && (chosen.isPlaying || playing.length === 0))
            return chosen;
        if (playing.length)
            return playing[0];
        return players.find(p => p.playbackState === MprisPlaybackState.Paused) || null;
    }
    readonly property bool active: !!player && player.playbackState !== MprisPlaybackState.Stopped
                                   && (player.trackTitle !== "" || player.isPlaying)

    // What the pill shows. Switching tracks in a browser (YouTube Shorts) drops the player or its
    // metadata for a moment: keep the pill and the last title, state and artist through such gaps
    // instead of hiding it and building it anew. The kept title stands in only for such a gap and only
    // for the player it came from: past that, a player without a title shows its name, not the song
    // before.
    readonly property bool shown: active || linger.running
    property string title: ""
    property string titleOf: ""
    property string artist: ""
    property bool playing: false
    readonly property string rawTitle: active ? line(player.trackTitle) : ""
    onRawTitleChanged: if (rawTitle === "") gap.restart()
    Timer {
        id: gap
        interval: 3000
    }
    readonly property var live: active ? {
        title: rawTitle || (gap.running && titleOf === player.dbusName ? title : "") || player.identity,
        artist: line(player.trackArtist),
        playing: player.isPlaying,
        owner: player.dbusName
    } : null
    onLiveChanged: {
        if (!live)
            return;
        title = live.title;
        titleOf = live.owner;
        artist = live.artist;
        playing = live.playing;
    }

    // metadata on one line: a stream's title may carry line breaks
    function line(s) {
        return String(s || "").replace(/\s*[\r\n]+\s*/g, " ").trim();
    }
    onActiveChanged: if (!active) linger.restart()
    Timer {
        id: linger
        interval: 1500
    }

    // MPRIS only reports the position on seeks: ask while something plays and someone looks
    property int watchers: 0
    Timer {
        interval: 1000
        repeat: true
        running: media.watchers > 0 && !!media.player && media.player.isPlaying
        onTriggered: media.player.positionChanged()
    }

    function time(seconds) {
        if (!(seconds >= 0) || !isFinite(seconds))
            return "--:--";
        const s = Math.floor(seconds);
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const ss = String(s % 60).padStart(2, "0");
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${ss}` : `${m}:${ss}`;
    }
}
