import QtQuick

// The password field of the login screen, the lock screen and the polkit dialog: a framed line, small
// squares for what you typed, "checking …" while it is checked, red after a wrong one, a Caps Lock
// warning. One file for both: the greeter runs as another user and reads it here, the shell through a
// link in the repository (home/.config/quickshell/bar/PasswordField.qml), so it takes no singletons.
// `theme`: the colours (field, fieldBorder, primary, text, dim, faint, warn, crit) and the font;
// `caps`: Caps Lock is on; `keyPressed` on every key (a moment to look at Caps Lock again).
// `text` is what is typed (set it to change the field); `edited(text)` when you type.
Rectangle {
    id: field

    required property var theme
    property bool caps: false

    property string text: ""
    property bool checking: false
    property bool failed: false
    property bool reveal: false            // show the text itself (a prompt that is not a password)
    property string placeholder: "Password"
    readonly property bool focused: input.activeFocus
    signal edited(string text)
    signal accepted
    signal escaped
    signal keyPressed

    function focusInput() {
        input.forceActiveFocus();
    }

    onTextChanged: if (input.text !== text) input.text = text

    implicitWidth: 300
    implicitHeight: 32
    color: theme.field
    border.width: 1
    border.color: failed ? theme.crit : input.activeFocus ? theme.primary : theme.fieldBorder

    component Line: Text {
        anchors.verticalCenter: parent.verticalCenter
        x: 12
        font.family: field.theme.font
        font.pixelSize: 13
        verticalAlignment: Text.AlignVCenter
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
    }

    TextInput {
        id: input
        anchors.fill: parent
        opacity: 0
        focus: true
        echoMode: TextInput.Password
        cursorVisible: false
        selectByMouse: false
        onTextChanged: if (text !== field.text) field.edited(text)
        Keys.onPressed: e => {
            field.keyPressed();
            if (e.key === Qt.Key_Escape) {
                field.escaped();
                e.accepted = true;
            }
        }
        onAccepted: field.accepted()
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: input.forceActiveFocus()
    }

    Line {
        visible: field.text === "" && !field.checking
        text: field.placeholder
        color: field.theme.faint
    }

    // what you typed, shown (not a password)
    Line {
        width: parent.width - 50
        elide: Text.ElideLeft
        visible: field.reveal && !field.checking
        text: field.text
        color: field.theme.text
    }

    Row {
        id: dots
        visible: !field.reveal && !field.checking
        anchors.verticalCenter: parent.verticalCenter
        x: 12
        spacing: 4
        readonly property int fit: Math.max(0, Math.floor((field.width - 60) / 12))
        Repeater {
            model: Math.min(field.text.length, dots.fit)
            Rectangle {
                required property int index
                width: 6
                height: 6
                color: field.theme.text
            }
        }
    }

    // checking: one quiet word
    Line {
        visible: field.checking
        text: "checking …"
        font.pixelSize: 12
        color: field.theme.dim
    }

    // Caps Lock: one glyph in a cell of fixed width (the shell's Icon)
    Line {
        anchors.right: parent.right
        anchors.rightMargin: 10
        width: 21
        height: 20
        horizontalAlignment: Text.AlignHCenter
        visible: field.caps && !field.reveal
        text: "\u{F030E}"
        font.pixelSize: 16
        color: field.theme.warn
    }
}
