import Quickshell
import Quickshell.Io
import QtQuick

// A script that prints one JSON object, run every `interval` seconds and on refresh() (the bar's IPC:
// scripts/poke NAME). A refresh while it runs starts it once more when it is done; a run that takes
// longer than `limit` is stopped, so a hung connection cannot freeze the feed.
// The scripts report their usual troubles in the JSON (offline, sync failed). A script that prints
// nothing usable twice in a row is broken (a traceback after an update, say): one notification with
// its last error line (again only after it worked once more; it replaces the earlier one of the same
// script); the bar keeps the last answer meanwhile.
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
    property string what: ""          // in the notification: "The bar's <what> does not update"
    property int fails: 0
    property bool stopped: false      // the limit ended the run: the network, not the script

    function failed() {
        if (stopped)
            return;
        fails++;
        if (fails === 2)
            tell.start();
    }

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
                if (!t) {
                    feed.failed();
                    return;
                }
                try {
                    feed.value = JSON.parse(t.split("\n").pop());
                    feed.fails = 0;
                } catch (e) {
                    console.warn("feed", feed.command[0], e);
                    feed.failed();
                }
            }
        }
        stderr: StdioCollector {
            id: errors
        }
        onStarted: feed.stopped = false
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
            feed.stopped = true;
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

    // a moment after the run, so the error output is in
    Timer {
        id: tell
        interval: 500
        onTriggered: {
            const script = String(feed.command[0] || "").split("/").pop();
            const last = errors.text.trim().split("\n").pop() || "no usable answer";
            Quickshell.execDetached(["notify-send", "-a", "driftless", "-h", "string:x-canonical-private-synchronous:feed-" + script,
                                     "The bar's " + (feed.what || script) + " does not update",
                                     "It shows the last answer until the script works again. " + script + ": " + last]);
        }
    }

    Timer {
        id: first
        interval: feed.delay * 1000
        onTriggered: feed.refresh()
    }
    Component.onCompleted: first.start()
}
