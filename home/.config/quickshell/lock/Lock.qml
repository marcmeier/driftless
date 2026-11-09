import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import qs.services

// The lock screen (hyprlock before; it stays as the fallback, scripts/lock). It looks like the login
// screen: the same plain night colour, the clock, your name and the password. SUPER + L, the power menu, the right click on the power button, hypridle after 10
// minutes and before sleep (lock_cmd = scripts/lock) all end up here.
//
// The password is checked by PAM with lock/pam/password (pam_unix only: the "login" stack's faillock
// would lock you out of your own screen for 10 minutes after three typos).
//
// If the shell dies while locked, the screen stays locked (Hyprland keeps the session locked and
// allow_session_lock_restore lets the restarted shell take over): a marker in $XDG_RUNTIME_DIR tells
// the new shell to lock again at once. From a TTY, hyprlock can take over as well:
//   WAYLAND_DISPLAY=wayland-1 hyprlock
//   quickshell ipc -p ~/.config/quickshell call lock lock
Scope {
    id: root

    property string password: ""
    property string message: ""         // what PAM says or why it failed
    property bool failed: false
    property bool checking: pam.active
    property bool unlocking: false      // the moment before the screens open
    readonly property bool locked: keep.locked
    // Hyprland shows a lock opaque (a see-through colour stays opaque): the desk colour is there at
    // once, the clock and the password fade in on it and out before it opens
    property real shown: 0
    // fully shown whenever no fade runs (after a reload of the shell while locked too)
    readonly property real cover: fadeIn.running || unlocking ? shown : (keep.locked ? 1 : 0)

    // the lock outlives a reload of the shell (a sync brings new QML every hour): kept here, and
    // declared before the lock so it is restored before the lock looks at it
    PersistentProperties {
        id: keep
        reloadableId: "driftless-lock"
        property bool locked: false
    }

    // per Wayland display: a second session (or a nested test) never locks this one
    readonly property string marker: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/driftless-locked-"
                                     + (Quickshell.env("WAYLAND_DISPLAY") || "wayland-0")

    function doLock() {
        if (keep.locked)
            return;
        password = "";
        message = "";
        failed = false;
        unlocking = false;
        Quickshell.execDetached(["touch", marker]);
        fadeIn.restart();
        keep.locked = true;
    }
    NumberAnimation {
        id: fadeIn
        target: root
        property: "shown"
        from: 0
        to: 1
        duration: Theme.lockFade
        easing.type: Easing.OutCubic
    }

    function submit() {
        if (pam.active || unlocking)
            return;
        if (password === "") {
            failed = false;
            message = "";
            return;
        }
        message = "";
        failed = false;
        pam.start();
    }

    function done() {
        shown = cover;   // 1, also when the shell was reloaded while locked
        unlocking = true;
        fadeOut.restart();
    }
    // what the lock shows fades out, then the screens open
    SequentialAnimation {
        id: fadeOut
        NumberAnimation {
            target: root
            property: "shown"
            to: 0
            duration: Theme.leave
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                Quickshell.execDetached(["rm", "-f", root.marker]);
                keep.locked = false;
                root.unlocking = false;
                root.password = "";
            }
        }
    }

    Binding {
        target: Session
        property: "locked"
        value: keep.locked
    }
    Connections {
        target: Session
        function onLockRequested() {
            root.doLock();
        }
    }

    // locked when the shell started: it died while the screen was locked
    FileView {
        path: root.marker
        printErrors: false
        onLoaded: {
            root.doLock();
            fadeIn.stop();   // back after a crash: there at once
            root.shown = 1;
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: keep.locked
        onSecureChanged: if (secure) Session.lockSecured()

        LockSurface {
            lockScope: root
        }
    }

    PamContext {
        id: pam
        configDirectory: Quickshell.shellDir + "/lock/pam"
        config: "password"

        onPamMessage: {
            if (responseRequired)
                respond(root.password);
            else if (message)
                root.message = message;
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.done();
                return;
            }
            root.password = "";
            root.failed = true;
            root.message = result === PamResult.MaxTries ? "Too many tries, wait a moment" : "Wrong password";
        }
        onError: error => {
            root.password = "";
            root.failed = true;
            root.message = "Could not check the password (" + PamError.toString(error) + ")";
        }
    }

    // the password field's Caps Lock warning (services/Keyboard.qml) looks while locked
    Binding {
        target: Keyboard
        property: "lockOpen"
        value: keep.locked
    }

    IpcHandler {
        target: "lock"

        // answers "locked" (scripts/lock relies on the answer: an older shell answers nothing)
        function lock(): string {
            root.doLock();
            return keep.locked ? "locked" : "unlocked";
        }
        // "locked" or "unlocked"
        function state(): string {
            return keep.locked ? "locked" : "unlocked";
        }
    }
}
