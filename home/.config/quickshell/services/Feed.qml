import Quickshell
import Quickshell.Io
import QtQuick

// A script that prints one JSON object, run every `interval` seconds and on refresh() (the bar's IPC:
// scripts/poke NAME). A refresh while it runs starts it once more when it is done; a run that takes
// longer than `limit` is stopped, so a hung connection cannot freeze the feed.
Item {
    id: feed

    property var command: []
    property int interval: 0          // seconds; 0: only at the start and on refresh()
    property int delay: 0             // seconds after the shell starts before the first run
    property int limit: 120           // seconds a run may take
    // the last answer that parsed (null until there is one). Not called `data`: that is the Item's
    // default property, where the Process and Timer below go, and a property of that name would take them in
    property var value: null
    property bool again: false

    function refresh() {
        if (proc.running)
            again = true;
        else
            proc.running = true;
    }

    Process {
        id: proc
        command: feed.command
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (!t)
                    return;
                try {
                    feed.value = JSON.parse(t.split("\n").pop());
                } catch (e) {
                    console.warn("feed", feed.command[0], e);
                }
            }
        }
        onExited: {
            if (feed.again) {
                feed.again = false;
                running = true;
            }
        }
    }

    Timer {
        interval: feed.limit * 1000
        running: proc.running
        onTriggered: {
            console.warn("feed", feed.command[0], "took longer than", feed.limit, "s: stopped");
            proc.running = false;
        }
    }

    Timer {
        interval: Math.max(feed.interval, 1) * 1000
        running: feed.interval > 0
        repeat: true
        triggeredOnStart: false
        onTriggered: feed.refresh()
    }

    Timer {
        id: first
        interval: feed.delay * 1000
        onTriggered: feed.refresh()
    }
    Component.onCompleted: first.start()
}
