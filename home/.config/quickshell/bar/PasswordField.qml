import QtQuick
import qs.services

// The password field of the lock screen and the polkit dialog: a framed line, small squares for what
// you typed, "checking …" while it is checked, red after a wrong one, a Caps Lock warning.
// `text` is what is typed (set it to change the field); `edited(text)` when you type.
Rectangle {
    id: field

    property string text: ""
    property bool checking: false
    property bool failed: false
    property bool reveal: false            // show the text itself (a prompt that is not a password)
    property string placeholder: "Password"
    property bool night: false             // the lock screen: dark in both looks
    readonly property bool focused: input.activeFocus
    signal edited(string text)
    signal accepted
    signal escaped

    function focusInput() {
        input.forceActiveFocus();
    }

    onTextChanged: if (input.text !== text) input.text = text

    implicitWidth: 300
    implicitHeight: 32
    color: night ? Theme.night.field : Theme.field
    border.width: 1
    border.color: failed ? (night ? Theme.night.crit : Theme.crit)
                : input.activeFocus ? (night ? Theme.night.primary : Theme.primary) : night ? Theme.night.fieldBorder : Theme.fieldBorder

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
            Keyboard.check();
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

    Label {
        anchors.verticalCenter: parent.verticalCenter
        x: 12
        visible: field.text === "" && !field.checking
        text: field.placeholder
        color: field.night ? Theme.night.faint : Theme.faint
    }

    // what you typed, shown (not a password)
    Label {
        anchors.verticalCenter: parent.verticalCenter
        x: 12
        width: parent.width - 50
        elide: Text.ElideLeft
        visible: field.reveal && !field.checking
        text: field.text
        color: field.night ? Theme.night.text : Theme.text
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
                color: field.night ? Theme.night.text : Theme.text
            }
        }
    }

    // checking: one quiet word
    Label {
        anchors.verticalCenter: parent.verticalCenter
        x: 12
        visible: field.checking
        text: "checking …"
        font.pixelSize: 12
        color: field.night ? Theme.night.dim : Theme.dim
    }

    Icon {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        visible: Keyboard.caps && !field.reveal
        text: "\u{F030E}"
        size: 16
        color: field.night ? Theme.night.warn : Theme.warn
    }
}
