import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import QtQuick

// The login screen: the lock screen's look (home/.config/quickshell/lock/LockSurface.qml), so logging
// in and unlocking are one thing: the plain look in night colours, the clock, the name, the password. Started by /usr/lib/driftless/greeter in cage as the user "greeter",
// which cannot read any home: everything it shows comes from /var/lib/driftless/greeter, rendered by
// greeter-update (colors.json and user; login.png is ReGreet's background), or from the system (the
// accounts, the sessions in /usr/share/wayland-sessions, /etc/hostname).
// DRIFTLESS_GREETER_DIR=~/.cache/theme quickshell -p /usr/share/driftless/greeter previews it in a
// window of the running session (no greetd there: the password is never checked);
// DRIFTLESS_GREETER_USER=NAME shows that account instead of the real ones (screenshots).
ShellRoot {
    id: root

    readonly property string dir: Quickshell.env("DRIFTLESS_GREETER_DIR") || "/var/lib/driftless/greeter"
    readonly property bool preview: !Greetd.available

    // ---- the look: the shell's night palette (services/Theme.qml), as theme/apply.py wrote it ----
    QtObject {
        id: look
        property color primary: "#7aa6d9"
        property color desk: "#0e0e0e"
        property color line: "#2b2b2b"
        property color field: "#111111"
        property color text: "#d6d6d6"
        property color strong: "#f2f2f2"
        property color dim: "#8a8a8a"
        readonly property color faint: Qt.alpha(dim, 0.6)
        readonly property color hover: Qt.rgba(1, 1, 1, 0.07)
        property color warn: "#e0a040"
        property color crit: "#e06666"
        readonly property string font: "JetBrainsMono Nerd Font"
    }
    FileView {
        path: root.dir + "/colors.json"
        printErrors: false
        onLoaded: {
            try {
                const c = JSON.parse(text());
                const k = c.colors || {};
                // only colours: whatever else is in the file stays unused
                const ok = v => typeof v === "string" && /^#[0-9a-fA-F]{6}$/.test(v);
                if (ok(c.primary))
                    look.primary = c.primary;
                for (const [name, key] of [["desk", "desk"], ["line", "line"], ["field", "field"], ["text", "fg"],
                        ["strong", "fg_strong"], ["dim", "dim"], ["warn", "orange"], ["crit", "red"]])
                    if (ok(k[key]))
                        look[name] = k[key];
            } catch (e) {}
        }
    }

    // ---- who: the people with an account; the one who rendered the look last comes first ----
    property var users: []          // [{login, name}]
    property int userIndex: 0
    readonly property var user: users[userIndex] || {
        login: "",
        name: ""
    }
    property string lastUser: ""

    FileView {
        path: root.dir + "/user"
        printErrors: false
        onLoaded: {
            root.lastUser = text().trim();
            root.pickUser();
        }
    }
    Process {
        running: true
        command: ["getent", "passwd"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                for (const line of text.split("\n")) {
                    const f = line.split(":");
                    const uid = parseInt(f[2]);
                    if (f.length < 7 || uid < 1000 || uid >= 60000 || /(nologin|false)$/.test(f[6]))
                        continue;
                    found.push({
                        login: f[0],
                        name: (f[4] || "").split(",")[0].trim() || f[0]
                    });
                }
                const demo = root.preview ? Quickshell.env("DRIFTLESS_GREETER_USER") : "";
                root.users = demo ? [{
                        login: demo,
                        name: demo
                    }] : found;
                root.pickUser();
            }
        }
    }
    function pickUser() {
        const i = users.findIndex(u => u.login === lastUser);
        userIndex = Math.max(0, i);
    }
    function nextUser() {
        if (users.length < 2 || Greetd.state !== GreetdState.Inactive)
            return;
        userIndex = (userIndex + 1) % users.length;
        reset();
    }

    // ---- what starts: the Wayland sessions, the uwsm-managed Hyprland first ----
    property var sessions: []       // [{file, name, exec, desktops}]
    property int sessionIndex: 0
    readonly property var session: sessions[sessionIndex] || null

    Process {
        running: true
        command: ["sh", "-c", "for f in /usr/share/wayland-sessions/*.desktop; do [ -f \"$f\" ] || continue; " + "grep -qiE '^(NoDisplay|Hidden)=true' \"$f\" && continue; " + "printf '%s\\t%s\\t%s\\t%s\\n' \"${f##*/}\" \"$(sed -n 's/^Name=//p' \"$f\" | head -1)\" " + "\"$(sed -n 's/^Exec=//p' \"$f\" | head -1)\" \"$(sed -n 's/^DesktopNames=//p' \"$f\" | head -1)\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    if (f.length < 4 || !f[2])
                        continue;
                    found.push({
                        file: f[0].replace(/\.desktop$/, ""),
                        name: f[1] || f[0],
                        exec: f[2],
                        desktops: f[3]
                    });
                }
                found.sort((a, b) => (b.file === "hyprland-uwsm") - (a.file === "hyprland-uwsm"));
                root.sessions = found;
                root.sessionIndex = 0;
            }
        }
    }
    function nextSession() {
        if (sessions.length > 1)
            sessionIndex = (sessionIndex + 1) % sessions.length;
    }

    // ---- the login itself: greetd asks (PAM), we answer with the password ----
    property string password: ""
    property string message: ""     // what greetd says, or why it failed
    property bool failed: false
    property int fails: 0
    property bool checking: false
    property bool answered: false   // the password went to the first secret prompt of this try
    property bool asking: false     // greetd asked something else: the next submit answers it
    property bool reveal: false     // ... and it is not secret
    property bool leaving: false    // the session is about to start

    function reset() {
        password = "";
        message = "";
        failed = false;
        checking = false;
        answered = false;
        asking = false;
        reveal = false;
    }

    function submit() {
        if (checking || leaving || !session || !user.login)
            return;
        if (preview) {
            message = "Preview: greetd is not running";
            return;
        }
        if (asking) {
            asking = false;
            checking = true;
            Greetd.respond(password);
            password = "";
            return;
        }
        if (password === "")
            return;
        failed = false;
        message = "";
        checking = true;
        answered = false;
        Greetd.createSession(user.login);
    }

    function launchCommand() {
        // Exec= of the session file, without the field codes (%f ...) desktop entries may have
        return session.exec.split(/\s+/).filter(a => a !== "" && !/^%/.test(a));
    }

    Connections {
        target: Greetd
        function onAuthMessage(msg, error, responseRequired, echoResponse) {
            if (!responseRequired) {
                if (msg)
                    root.message = msg;
                return;
            }
            if (!echoResponse && !root.answered) {
                root.answered = true;
                Greetd.respond(root.password);
                return;
            }
            // something else to answer (a code, a new password): ask with greetd's words
            root.checking = false;
            root.asking = true;
            root.reveal = echoResponse;
            root.password = "";
            root.message = msg;
        }
        function onAuthFailure(msg) {
            root.reset();
            root.failed = true;
            root.fails++;
            root.message = "Wrong password";
        }
        function onError(error) {
            root.reset();
            root.failed = true;
            root.message = "Could not log in (" + error + ")";
            Greetd.cancelSession();
        }
        function onReadyToLaunch() {
            root.leaving = true;
            launchTimer.start();
        }
    }
    Timer {
        id: launchTimer
        interval: 20
        onTriggered: {
            const env = ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=" + root.session.file];
            if (root.session.desktops)
                env.push("XDG_CURRENT_DESKTOP=" + root.session.desktops.replace(/;+$/, "").replace(/;/g, ":"));
            Greetd.launch(root.launchCommand(), env, true);
        }
    }

    // Caps Lock, read from the keyboards' LEDs (services/Keyboard.qml)
    property bool caps: false
    Process {
        id: capsProc
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2> /dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.caps = text.split("\n").some(l => l.trim() !== "" && l.trim() !== "0")
        }
    }
    Timer {
        running: true
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!capsProc.running) capsProc.running = true
    }

    property string hostname: ""
    FileView {
        path: "/etc/hostname"
        printErrors: false
        onLoaded: root.hostname = text().trim()
    }

    Process {
        id: power
    }

    // ---- the screen (cage shows it fullscreen on one output) ----
    FloatingWindow {
        id: win
        color: look.desk
        implicitWidth: 1600
        implicitHeight: 900
        title: "driftless greeter"

        Item {
            id: content
            anchors.fill: parent
            visible: !root.leaving

            // ---- the clock, the date, the name and the password, in one column, as on the lock screen ----
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(parent.height * 0.5) - 150
                width: 280
                spacing: 6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.family: look.font
                    font.pixelSize: 72
                    font.weight: Font.Light
                    color: look.strong
                    text: Qt.formatTime(time.date, "hh:mm")
                    renderType: Text.NativeRendering
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.family: look.font
                    font.pixelSize: 13
                    color: look.dim
                    text: Qt.locale().toString(time.date, "dddd, d. MMMM")
                    renderType: Text.NativeRendering
                }
                Item {
                    width: 1
                    height: 30
                }

                // the name; with more than one account a click goes to the next
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: nameRow.implicitWidth
                    height: nameRow.implicitHeight
                    Row {
                        id: nameRow
                        spacing: 4
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: look.font
                            font.pixelSize: 13
                            color: nameMouse.containsMouse ? look.strong : look.text
                            text: root.user.name
                            textFormat: Text.PlainText
                            renderType: Text.NativeRendering
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.users.length > 1
                            font.family: look.font
                            font.pixelSize: 13
                            color: look.faint
                            text: "\u{F0140}"
                        }
                    }
                    MouseArea {
                        id: nameMouse
                        anchors.fill: parent
                        enabled: root.users.length > 1
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.nextUser()
                    }
                }

                PasswordField {
                    id: field
                    theme: look
                    caps: root.caps
                    width: parent.width
                    text: root.password
                    checking: root.checking
                    failed: root.failed
                    reveal: root.reveal
                    placeholder: root.asking ? "Answer" : "Password"
                    onEdited: t => {
                        root.password = t;
                        if (t !== "")
                            root.failed = false;
                    }
                    onAccepted: root.submit()
                    onEscaped: {
                        root.password = "";
                        if (Greetd.state !== GreetdState.Inactive)
                            Greetd.cancelSession();
                        root.reset();
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 16
                    width: Math.min(implicitWidth, parent.width)
                    elide: Text.ElideRight
                    font.family: look.font
                    font.pixelSize: 12
                    text: root.message !== "" ? root.message : root.caps ? "Caps Lock is on" : ""
                    color: root.failed ? look.crit : root.message === "" && root.caps ? look.warn : look.dim
                    textFormat: Text.PlainText
                    renderType: Text.NativeRendering
                }
            }
            SystemClock {
                id: time
                precision: SystemClock.Minutes
            }
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: field.focusInput()
            }

            // ---- at the bottom, quietly: the machine, the session, power ----
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                spacing: 8

                Chip {
                    theme: look
                    icon: "\u{F0379}"
                    label: root.hostname
                    clickable: false
                    visible: root.hostname !== ""
                }
                // the session; a click picks the next one (there is rarely more than one)
                Chip {
                    theme: look
                    icon: "\u{F056E}"
                    label: root.session ? root.session.name : "no session"
                    clickable: root.sessions.length > 1
                    onClicked: root.nextSession()
                }
                Chip {
                    theme: look
                    icon: "\u{F0709}"
                    label: ""
                    onClicked: {
                        power.command = ["systemctl", "reboot"];
                        power.running = true;
                    }
                }
                Chip {
                    theme: look
                    icon: "\u{F0425}"
                    label: ""
                    onClicked: {
                        power.command = ["systemctl", "poweroff"];
                        power.running = true;
                    }
                }
            }
        }

        Component.onCompleted: field.focusInput()
    }
}
