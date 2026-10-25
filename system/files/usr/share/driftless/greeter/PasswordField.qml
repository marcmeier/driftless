import QtQuick

// The greeter's copy of the shell's password field (home/.config/quickshell/bar/PasswordField.qml; the
// greeter runs as another user and cannot read the home): keep the two in step. The colours come from
// `theme` (shell.qml), Caps Lock from `caps`.
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
    color: field.theme.field
    border.width: 1
    border.color: failed ? field.theme.crit : input.activeFocus ? field.theme.primary : field.theme.line

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

    Text {
        anchors.verticalCenter: parent.verticalCenter
        x: 12
        visible: field.text === "" && !field.checking
        text: field.placeholder
        color: field.theme.faint
        font.family: field.theme.font
        font.pixelSize: 13
        renderType: Text.NativeRendering
    }

    // what you typed, shown (not a password)
    Text {
        anchors.verticalCenter: parent.verticalCenter
        x: 12
        width: parent.width - 50
        elide: Text.ElideLeft
        visible: field.reveal && !field.checking
        text: field.text
        color: field.theme.text
        font.family: field.theme.font
        font.pixelSize: 13
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
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
    Text {
        anchors.verticalCenter: parent.verticalCenter
        x: 12
        visible: field.checking
        text: "checking …"
        font.family: field.theme.font
        font.pixelSize: 12
        color: field.theme.dim
        renderType: Text.NativeRendering
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        visible: field.caps && !field.reveal
        text: "\u{F030E}"
        font.family: field.theme.font
        font.pixelSize: 16
        color: field.theme.warn
        renderType: Text.NativeRendering
    }
}
