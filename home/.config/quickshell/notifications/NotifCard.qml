import QtQuick
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.services
import "../bar"

// One notification: the app's icon (or the picture it sent), the app and when, the summary, the
// text, a progress bar if it sends one, its actions. The same box pops up at the top right and sits
// in the bell's list; `popup` adds the time that runs out (it waits while the pointer is on it).
// Click: the app's default action (or its window) · right click or ×: dismiss · swipe right: dismiss.
// When the app takes an answer (a messenger), a field below: type, Enter sends it, Esc leaves it.
Rectangle {
    id: card

    required property int nid
    required property string app
    required property string summary
    required property string body
    required property string icon
    required property string image
    required property int urgency
    required property real progress
    required property string actions
    required property bool clickable
    required property string reply    // the answer field's placeholder; empty: no field
    required property real time

    property bool popup: false
    property bool showApp: true       // the list shows the app once over its group
    required property int timeout     // ms until a popup leaves on its own; 0: it stays
    readonly property bool critical: urgency === NotificationUrgency.Critical
    readonly property bool low: urgency === NotificationUrgency.Low
    readonly property var actionList: { try { return JSON.parse(actions); } catch (e) { return []; } }
    readonly property bool hovered: hover.hovered

    signal expired

    // new content in the same notification (notify-send -r): its time starts again
    onSummaryChanged: if (countdown.running) countdown.restart()
    onBodyChanged: if (countdown.running) countdown.restart()

    implicitWidth: 380
    implicitHeight: content.implicitHeight + 2 * pad
    readonly property int pad: 10
    color: !popup && mouse.containsMouse ? Theme.hover : Theme.card
    border.width: 1
    border.color: critical ? Theme.crit : Theme.cardBorder
    clip: true

    HoverHandler {
        id: hover
    }

    // swipe right to dismiss
    property real dragX: 0
    transform: Translate {
        x: card.dragX
    }
    DragHandler {
        id: swipe
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        onTranslationChanged: card.dragX = Math.max(0, translation.x)
        onActiveChanged: {
            if (active)
                return;
            if (card.dragX > card.width * 0.3)
                Notifs.dismiss(card.nid);
            else
                card.dragX = 0;
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: card.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: m => {
            if (m.button === Qt.LeftButton && card.clickable)
                Notifs.activate(card.nid);
            else if (m.button !== Qt.LeftButton || card.popup)
                card.popup ? Notifs.hidePopup(card.nid) : Notifs.dismiss(card.nid);
        }
    }

    Row {
        id: content
        x: card.pad
        y: card.pad
        width: card.width - 2 * card.pad
        spacing: 10

        // the picture it sent, else the app's icon, else a sign for it (below)
        Item {
            id: art
            width: 32
            height: 32
            readonly property string src: card.image || card.icon

            ClippingRectangle {
                anchors.fill: parent
                visible: art.src !== "" && pic.status === Image.Ready
                color: "transparent"
                Image {
                    id: pic
                    anchors.fill: parent
                    source: art.src
                    sourceSize: Qt.size(80, 80)
                    fillMode: card.image ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }
            }
            Item {
                anchors.fill: parent
                visible: !(art.src !== "" && pic.status === Image.Ready)
                // the desktop's own senders by name, then the app's glyph from the bar
                // (services/Apps.qml), else the first letter of the app's name
                readonly property string own: ({ settings: "\u{F0493}", calendar: "\u{F00ED}", notifications: "\u{F009A}" })[card.app.toLowerCase()] || ""
                readonly property var known: Apps.lookup(card.app)
                readonly property string glyph: card.critical ? "\u{F0028}" : own || (known.glyph !== "\u{F05B2}" ? known.glyph : "")
                readonly property color tone: card.critical ? Theme.crit : Theme.dim

                DriftlessMark {
                    visible: !card.critical && card.app.toLowerCase() === "driftless"
                    anchors.centerIn: parent
                    size: 20
                    color: parent.tone
                }
                Icon {
                    visible: parent.glyph !== "" && (card.critical || card.app.toLowerCase() !== "driftless")
                    anchors.centerIn: parent
                    size: 18
                    text: parent.glyph
                    color: parent.tone
                }
                Rectangle {
                    visible: parent.glyph === "" && card.app.toLowerCase() !== "driftless"
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.border
                    Label {
                        anchors.centerIn: parent
                        text: (card.app.match(/[A-Za-z0-9]/) || ["?"])[0].toUpperCase()
                        bold: true
                        font.pixelSize: 13
                        color: Theme.dim
                    }
                }
            }
        }

        Column {
            width: content.width - art.width - content.spacing
            spacing: 3

            // app · when (the list names the app once over its group)
            Item {
                width: parent.width - 20
                height: 18
                Label {
                    id: appLabel
                    visible: card.showApp
                    anchors.verticalCenter: parent.verticalCenter
                    width: visible ? Math.min(implicitWidth, parent.width - timeLabel.implicitWidth - 8) : 0
                    elide: Text.ElideRight
                    small: true
                    text: card.app
                    color: card.critical ? Theme.crit : Theme.dim
                    bold: true
                }
                Label {
                    id: timeLabel
                    anchors.left: appLabel.right
                    anchors.leftMargin: card.showApp ? 6 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    small: true
                    color: Theme.faint
                    text: (card.showApp ? "·  " : "") + Notifs.ago(card.time)
                }
            }

            Label {
                width: parent.width
                visible: text !== ""
                text: card.summary
                bold: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: card.low ? Theme.dim : Theme.text
            }
            Label {
                width: parent.width
                visible: text !== ""
                text: card.body
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: card.popup ? 4 : 6
                elide: Text.ElideRight
                font.pixelSize: 13
                color: Theme.dim
                lineHeight: 1.1
                linkColor: Theme.accent
            }

            Item {
                visible: card.progress >= 0
                width: parent.width
                height: 14
                PMeter {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    percent: Math.max(0, card.progress)
                    tone: Theme.accent
                }
            }

            Flow {
                visible: card.actionList.length > 0
                width: parent.width
                topPadding: 6
                spacing: 6
                Repeater {
                    model: card.actionList
                    PButton {
                        required property var modelData
                        required property int index
                        text: modelData.text
                        accent: index === 0 && card.critical
                        implicitHeight: 28
                        onClicked: Notifs.invoke(card.nid, modelData.id)
                    }
                }
            }

            // the answer, straight to the app
            Item {
                visible: card.reply !== ""
                width: parent.width
                height: 38
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 30
                    color: Theme.field
                    border.width: 1
                    border.color: answer.activeFocus ? Theme.accent : Theme.fieldBorder

                    TextInput {
                        id: answer
                        anchors.left: parent.left
                        anchors.right: send.left
                        anchors.leftMargin: 8
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true
                        color: Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentInk
                        font.family: Theme.font
                        font.pixelSize: 13
                        selectByMouse: true
                        onAccepted: Notifs.reply(card.nid, text)
                        Keys.onEscapePressed: {
                            text = "";
                            focus = false;
                        }

                        Label {
                            visible: answer.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.reply
                            font.pixelSize: 13
                            color: Theme.faint
                        }
                    }
                    // a click into the field: typing, not the card's action
                    MouseArea {
                        anchors.fill: answer
                        cursorShape: Qt.IBeamCursor
                        onPressed: m => {
                            answer.forceActiveFocus();
                            m.accepted = false;
                        }
                    }
                    Rectangle {
                        id: send
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 3
                        width: 24
                        height: 24
                        color: sendMouse.containsMouse ? Theme.hover : "transparent"
                        Icon {
                            anchors.centerIn: parent
                            size: 14
                            text: "\u{F048A}"
                            color: answer.text.trim() ? Theme.accent : Theme.faint
                        }
                        MouseArea {
                            id: sendMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifs.reply(card.nid, answer.text)
                        }
                    }
                }
            }
        }
    }

    // ×: on hover
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        width: 22
        height: 22
        color: closeMouse.containsMouse ? Theme.hover : "transparent"
        visible: card.hovered
        Icon {
            anchors.centerIn: parent
            size: 13
            text: "\u{F0156}"
            color: closeMouse.containsMouse ? Theme.text : Theme.dim
        }
        MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Notifs.dismiss(card.nid)
        }
    }

    // the popup's time running out, held while you are at it. A Timer, not an animation: a running
    // animation would redraw the popups at the screen's refresh rate for as long as one shows.
    readonly property bool counting: popup && timeout > 0
                                     && !(hovered || swipe.active || answer.activeFocus || answer.text !== "")
    property real timeLeft: timeout   // ms
    property real since: 0
    function countFrom() {
        since = Date.now();
        countdown.restart();
    }
    onCountingChanged: {
        if (counting)
            countFrom();
        else if (countdown.running) {
            countdown.stop();
            timeLeft = Math.max(1, timeLeft - (Date.now() - since));
        }
    }
    Component.onCompleted: if (counting) countFrom()
    Timer {
        id: countdown
        interval: Math.max(1, card.timeLeft)
        onTriggered: card.expired()
    }
}
