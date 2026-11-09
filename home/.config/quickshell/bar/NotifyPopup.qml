import QtQuick
import qs.services
import "../notifications"

// The bell's popup: every notification that is still there, newest first and grouped by app, with
// do not disturb and "clear all". Opening it marks them as seen (the bell stops glowing). An app with
// more than three shows its newest three and "N more from …" (one app's flood does not fill the list);
// that opens the group until the popup closes.
Item {
    id: root

    property var popup
    property var bar
    property real room: 100000                    // the height the popup may take (BarPopup)

    readonly property int fold: 3
    property var opened: ({})                     // app → its group shows every card
    property int rev: 0                           // the history changed: ranks anew

    Connections {
        target: Notifs.history
        function onCountChanged() { root.rev++; }
        function onRowsMoved() { root.rev++; }
        function onDataChanged() { root.rev++; }
    }

    // where a card stands in its app's group, and how big the group is (an app's cards are together)
    function rank(i) {
        const app = Notifs.history.get(i).app;
        let r = 0;
        while (i - r - 1 >= 0 && Notifs.history.get(i - r - 1).app === app)
            r++;
        return r;
    }
    function groupSize(i) {
        const app = Notifs.history.get(i).app;
        let first = i - rank(i), n = 0;
        while (first + n < Notifs.history.count && Notifs.history.get(first + n).app === app)
            n++;
        return n;
    }
    // the button moves (under the third card / the last); from the keyboard its focus goes with it
    function toggle(app, first, byKey) {
        const o = Object.assign({}, opened);
        o[app] = !o[app];
        opened = o;
        if (!byKey)
            return;
        Qt.callLater(() => {
            const at = first + (o[app] ? groupSize(first) - 1 : fold - 1);
            list.positionViewAtIndex(at, ListView.Contain);
            const d = list.itemAtIndex(at);
            if (d)
                d.focusToggler();
        });
    }

    implicitWidth: 490
    implicitHeight: column.implicitHeight

    Component.onCompleted: {
        Notifs.markRead();
        Notifs.now = Date.now();
        Notifs.listOpen = true;
    }
    Component.onDestruction: Notifs.listOpen = false

    Column {
        id: column
        width: parent.width
        spacing: 12

        PopupHeader {
            id: header
            icon: Notifs.dnd ? "\u{F009B}" : "\u{F009A}"
            title: Notifs.count === 1 ? "1 notification" : Notifs.count > 0 ? Notifs.count + " notifications" : "Notifications"
            // on: they pop up; off: do not disturb (the switch the other popups have in this place)
            PSwitch {
                checked: !Notifs.dnd
                onToggled: Notifs.setDnd(!Notifs.dnd)
            }
        }

        Label {
            id: dndLine
            visible: Notifs.dnd
            width: parent.width
            wrapMode: Text.Wrap
            small: true
            dim: true
            text: "Do not disturb: only critical ones pop up"
        }

        // nothing there
        Column {
            visible: Notifs.count === 0
            width: parent.width
            topPadding: 18
            bottomPadding: 22
            spacing: 8
            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 34
                text: Notifs.dnd ? "\u{F009B}" : "\u{F009C}"
                color: Theme.faint
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "All caught up"
                color: Theme.dim
            }
        }

        ListView {
            id: list
            visible: Notifs.count > 0
            width: parent.width
            // the room under the header, the buttons stay (as the calendar's events, the sound apps)
            height: Math.min(contentHeight, Math.max(160, root.room - header.height - foot.height - 2 * column.spacing
                                                        - (dndLine.visible ? dndLine.height + column.spacing : 0)))
            clip: true
            // the gap is each card's own (below it): a folded card takes no room at all
            spacing: 0
            boundsBehavior: Flickable.StopAtBounds
            model: Notifs.history

            section.property: "app"
            section.criteria: ViewSection.FullString
            section.delegate: Item {
                required property string section
                width: ListView.view.width
                height: 30
                Label {
                    anchors.left: parent.left
                    anchors.leftMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 40
                    elide: Text.ElideRight
                    small: true
                    bold: true
                    color: Theme.dim
                    text: parent.section
                }
                PButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    implicitHeight: 24
                    flat: true
                    icon: "\u{F0156}"
                    iconSize: 12
                    onClicked: Notifs.clearApp(parent.section)
                }
            }

            delegate: Item {
                id: slot
                required property int index
                required property var model
                readonly property int rank: { root.rev; return index < Notifs.history.count ? root.rank(index) : 0; }
                readonly property int size: { root.rev; return index < Notifs.history.count ? root.groupSize(index) : 1; }
                readonly property bool open: !!root.opened[model.app]
                readonly property bool folds: size > root.fold
                readonly property bool shown: !folds || open || rank < root.fold
                // under the group's last card shown: more to see, or the way back
                readonly property bool toggler: folds && (open ? rank === size - 1 : rank === root.fold - 1)
                width: ListView.view.width
                height: shown ? card.height + (toggler ? more.height + 4 : 0) + 6 : 0
                visible: shown

                function focusToggler() {
                    more.takeFocus();
                }

                NotifCard {
                    id: card
                    width: parent.width
                    showApp: false
                    nid: slot.model.nid
                    app: slot.model.app
                    summary: slot.model.summary
                    body: slot.model.body
                    icon: slot.model.icon
                    image: slot.model.image
                    urgency: slot.model.urgency
                    progress: slot.model.progress
                    actions: slot.model.actions
                    clickable: slot.model.clickable
                    reply: slot.model.reply
                    time: slot.model.time
                    timeout: slot.model.timeout
                }
                PButton {
                    id: more
                    visible: slot.toggler
                    y: card.height + 4
                    flat: true
                    implicitHeight: 28
                    iconSize: 12
                    icon: slot.open ? "\u{F0143}" : "\u{F0140}"
                    text: slot.open ? "Show fewer" : (slot.size - root.fold) + " more from " + slot.model.app
                    onClicked: root.toggle(slot.model.app, slot.index - slot.rank, more.keyFocus)
                }
            }

        }

        ButtonRow {
            id: foot
            visible: Notifs.count > 0
            PButton {
                icon: "\u{F039F}"
                text: "Clear all"
                onClicked: Notifs.clear()
            }
        }
    }
}
