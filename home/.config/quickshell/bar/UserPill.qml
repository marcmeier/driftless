import QtQuick
import qs.services

// You: your name (the plain look leaves the picture to the settings; "custom/avatar" alone shows the
// name as well). A click: about this machine (bar/AboutPopup.qml: the machine, its system and
// versions, memory and disk; your picture, lock, log out). The settings sit behind the cog at the edge.
Pill {
    id: pill

    readonly property var members: bar ? BarLayout.members("group/user", bar.variant) : []
    readonly property bool showAvatar: false
    readonly property bool showName: members.includes("custom/username") || members.includes("custom/avatar")
    shown: showName

    Seg {
        bar: pill.bar
        padL: pill.showAvatar ? 2 : 10
        padR: pill.showName ? 10 : 2
        spacing: 8
        tip: "About this machine"
        onClicked: togglePopup()
        popupKey: "about"
        popupComponent: Component {
            AboutPopup {}
        }

        Item {
            visible: pill.showAvatar
            width: 26
            height: 26
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: avatar
                anchors.fill: parent
                sourceSize: Qt.size(52, 52)
                fillMode: Image.PreserveAspectCrop
                cache: false
                smooth: true
                mipmap: true
                // a new picture: load it again
                source: Theme.avatarVersion >= 0 ? "file://" + Theme.avatar : ""
                Connections {
                    target: Theme
                    function onAvatarVersionChanged() {
                        avatar.source = "";
                        avatar.source = "file://" + Theme.avatar;
                    }
                }
            }
        }

        Label {
            visible: pill.showName
            anchors.verticalCenter: parent.verticalCenter
            text: Feeds.userName
            font.pixelSize: pill.compact ? 12 : 13
        }
    }
}
