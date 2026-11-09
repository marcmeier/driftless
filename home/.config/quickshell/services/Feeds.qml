pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// What the bar learns from scripts (everything else comes from Quickshell's own services: Hyprland,
// PipeWire, MPRIS, UPower, NetworkManager, the tray). Each feed runs once for all bars.
// A script that changes something tells the bar with scripts/poke NAME, e.g. "poke sync".
Singleton {
    id: feeds

    readonly property string scripts: Quickshell.shellDir + "/scripts"
    readonly property string home: Quickshell.env("HOME")

    property alias claude: claude
    property alias sessions: sessions
    property alias sync: sync
    property alias weather: weather
    property alias calendar: calendar
    property alias updates: updates
    property alias dictate: dictate
    property string userName: Quickshell.env("USER")

    // SUPER + A and the dictation keep working without the bar; the bar only shows their state
    Feed {
        id: claude
        what: "Claude usage"
        command: [feeds.scripts + "/claude-usage.py"]
        interval: 180
    }
    // a Claude Code hook pokes on every change; the interval only ends "done" and drops dead sessions
    Feed {
        id: sessions
        what: "Claude sessions"
        command: [feeds.scripts + "/claude-sessions.py"]
        interval: 60
    }
    // the sync pokes at the start and the end of every run: the interval only ages the "ago" texts
    Feed {
        id: sync
        what: "sync status"
        command: [feeds.scripts + "/sync.py"]
        interval: 300
    }
    Feed {
        id: weather
        what: "weather"
        command: [feeds.scripts + "/weather.py"]
        interval: 1800
    }
    // calendar-sync.sh pokes after every sync; besides, ask again when the next event starts and
    // when the day changes ("tmrw" becomes today)
    Feed {
        id: calendar
        what: "calendar"
        command: [feeds.scripts + "/agenda.py"]
        interval: 600
    }
    SystemClock {
        id: minute
        precision: SystemClock.Minutes
        property string day: Qt.formatDate(date, "yyyy-MM-dd")
        onDayChanged: calendar.refresh()
        onDateChanged: {
            const next = calendar.value && calendar.value.next;
            if (next && next.at && next.at * 1000 <= date.getTime())
                calendar.refresh();
        }
    }
    // network calls: not in the rush of the login
    Feed {
        id: updates
        what: "update count"
        command: [feeds.scripts + "/updates.sh"]
        interval: 1800
        delay: 120
        limit: 200      // updates.sh: three calls of up to 60 s each
    }
    Feed {
        id: dictate
        what: "dictation status"
        command: [feeds.home + "/.config/hypr/dictate.py", "status"]
    }

    // the full name from the account (chfn), else the login name
    Process {
        running: true
        command: ["getent", "passwd", Quickshell.env("USER")]
        stdout: StdioCollector {
            onStreamFinished: {
                const name = (text.split(":")[4] || "").split(",")[0].trim();
                if (name)
                    feeds.userName = name;
            }
        }
    }

    function refresh(name) {
        const feed = {
            claude: claude, sessions: sessions, sync: sync, weather: weather, calendar: calendar, updates: updates,
            dictate: dictate
        }[name];
        if (feed)
            feed.refresh();
        return !!feed;
    }

    // run a command, then refresh a feed when it is done (clicks that change what a feed shows)
    function runThen(cmd, name) {
        const p = runner.createObject(feeds, { command: cmd, then: name });
        p.running = true;
    }
    Component {
        id: runner
        Process {
            property string then: ""
            onExited: {
                if (then)
                    feeds.refresh(then);
                destroy();
            }
        }
    }
}
