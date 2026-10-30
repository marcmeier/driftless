import Quickshell
import Quickshell.Services.Polkit
import QtQuick
import qs.services
import "../bar"

// The password dialog when something asks for more rights (hyprpolkitagent before): installing
// packages from the lists, a mount, an app's settings. The shell is the session's polkit agent; the
// dialog is a plain box over the focused screen, which it covers in the desk colour: what is asked and
// by which action, the password. driftless's own request (installing listed packages, after the review in
// bar/PackagesSection.qml) says which packages and why, instead of the raw command line. Enter: authenticate · Esc or "Cancel": no.
// Without the shell there is no agent: polkit then says so to the program that asked.
Scope {
    id: root

    readonly property var flow: agent.flow
    readonly property bool open: agent.isActive && !!flow
    property string password: ""
    property bool checking: false
    property int fails: 0
    // driftless's own request in plain words: the packages from the command line polkit puts in the message
    readonly property var packages: {
        if (!flow || flow.actionId !== "org.driftless.install-packages")
            return null;
        const m = /install-packages\s+(.+)$/.exec(flow.message);
        return m ? m[1].trim().split(/\s+/) : null;
    }

    PolkitAgent {
        id: agent
    }

    Binding {
        target: Keyboard
        property: "polkitOpen"
        value: root.open
    }

    // a new request: an empty field on the screen you work on
    onOpenChanged: {
        if (!open)
            return;
        password = "";
        checking = false;
        fails = 0;
        Actions.toFocusedScreen(win);
        focusLater.restart();
    }
    Timer {
        id: focusLater
        interval: 50
        onTriggered: field.focusInput()
    }

    Connections {
        target: root.flow
        ignoreUnknownSignals: true
        // polkit asks (again, after a wrong password): the field is ready
        function onIsResponseRequiredChanged() {
            if (root.flow.isResponseRequired)
                root.checking = false;
        }
        function onAuthenticationFailed() {
            root.checking = false;
            root.password = "";
            root.fails++;
        }
    }

    function submit() {
        if (!flow || checking || !flow.isResponseRequired)
            return;
        checking = true;
        flow.submit(password);
        password = "";
    }
    function cancel() {
        if (flow)
            flow.cancelAuthenticationRequest();
    }

    ScrimWindow {
        id: win
        open: root.open
        name: "polkit"
        // a click beside the card does nothing: a request is answered, not dismissed by accident

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 460
            height: content.implicitHeight + 40
            color: Theme.card
            border.width: 1
            border.color: root.fails > 0 && !root.checking ? Theme.crit : Theme.cardBorder

            Row {
                id: content
                x: 20
                y: 20
                spacing: 0

                Column {
                    width: card.width - 40
                    spacing: 10

                    // driftless's own request under its mark, like the sync icon's popup it comes from
                    PopupHeader {
                        icon: root.packages ? "" : "\u{F099D}"
                        title: root.packages ? "driftless" : "Authentication required"
                        status: !root.packages ? "" : root.packages.length === 1 ? "Install 1 package"
                                : "Install " + root.packages.length + " packages"
                    }

                    // what is asked, in the program's words
                    Label {
                        width: parent.width
                        text: root.packages
                              ? root.packages.join(", ") + "\n\nInstalling changes the system for every user, so it needs your password."
                                + " driftless uses it for pacman -S with exactly these names, nothing else."
                              : root.flow ? root.flow.message : ""
                        wrapMode: Text.Wrap
                        maximumLineCount: root.packages ? 8 : 4
                        elide: Text.ElideRight
                        color: Theme.dim
                        lineHeight: 1.1
                    }
                    // and by which action, for the careful
                    Label {
                        width: parent.width
                        text: root.flow ? root.flow.actionId : ""
                        elide: Text.ElideMiddle
                        small: true
                        color: Theme.faint
                    }

                    PasswordField {
                        id: field
                        theme: Theme
                        caps: Keyboard.caps
                        onKeyPressed: Keyboard.check()
                        width: parent.width
                        text: root.password
                        checking: root.checking
                        failed: root.fails > 0 && !root.checking && root.password === ""
                        reveal: !!root.flow && root.flow.responseVisible
                        placeholder: root.flow && root.flow.inputPrompt && !/^password:?\s*$/i.test(root.flow.inputPrompt)
                                     ? root.flow.inputPrompt.replace(/:\s*$/, "") : "Password"
                        onEdited: t => root.password = t
                        onAccepted: root.submit()
                        onEscaped: root.cancel()
                    }

                    // what polkit adds (a wrong password, a fingerprint prompt), or Caps Lock
                    Label {
                        height: 16
                        width: parent.width
                        elide: Text.ElideRight
                        small: true
                        readonly property string extra: root.flow ? root.flow.supplementaryMessage : ""
                        text: extra !== "" ? extra : root.fails > 0 && !root.checking ? "Wrong password" : Keyboard.caps ? "Caps Lock is on" : ""
                        color: (root.flow && root.flow.supplementaryIsError) || (extra === "" && root.fails > 0) ? Theme.crit
                             : Keyboard.caps && extra === "" ? Theme.warn : Theme.dim
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: 8
                        PButton {
                            text: "Cancel"
                            onClicked: root.cancel()
                        }
                        PButton {
                            text: "Authenticate"
                            accent: true
                            enabled: root.password !== "" && !root.checking
                            onClicked: root.submit()
                        }
                    }
                }
            }
        }
    }
}
