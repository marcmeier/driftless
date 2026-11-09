import QtQuick
import Quickshell.Hyprland
import qs.services

// The focused window: the app's glyph and the window title (compact: the app's name), from Hyprland.
// Hidden on an empty workspace.
Pill {
    id: pill

    // Hyprland keeps the last window active on an empty workspace: only one on the focused workspace counts
    readonly property var win: {
        const w = Hyprland.activeToplevel;
        const ws = Hyprland.focusedWorkspace;
        return w && (!w.workspace || !ws || w.workspace.id === ws.id) ? w : null;
    }
    readonly property string appId: win ? ((win.wayland && win.wayland.appId) || (win.lastIpcObject && win.lastIpcObject.class) || "") : ""
    readonly property string title: win ? win.title : ""
    readonly property var app: Apps.lookup(appId)
    readonly property string shortTitle: title.replace(/\s+[-—–]\s+(Brave( Origin)?|Mozilla Firefox|Discord|Visual Studio Code)$/, "").trim()

    shown: !!win && appId !== ""

    // gives way to the centre like the media title on the right: fixed are the glyph and the shortest
    // title (60 px), the title gets what is left up to where the centre begins (Bar.leftEnd)
    readonly property bool flexible: true
    readonly property real fixed: padding * 2 + seg.padL + seg.padR + glyph.width + seg.spacing
    readonly property real rigidPart: fixed + 60
    readonly property real titleRoom: bar ? bar.leftEnd - (bar.leftRigid - rigidPart) - fixed : 340

    Seg {
        id: seg
        bar: pill.bar
        interactive: false
        padL: pill.compact ? 8 : 10
        padR: pill.compact ? 10 : 12
        spacing: 8
        tip: [pill.title, pill.appId].filter(x => x).map(Apps.esc).join("<br>")

        Icon {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            text: pill.app.glyph
            size: 16
            color: Theme.dim
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, pill.compact ? 160 : 340, Math.max(60, pill.titleRoom))
            elide: Text.ElideRight
            color: Theme.dim
            font.pixelSize: pill.compact ? Theme.fontCompact : Theme.fontSize
            text: pill.compact || !pill.shortTitle || pill.shortTitle.toLowerCase() === pill.app.name.toLowerCase()
                  ? pill.app.name : pill.shortTitle
        }
    }
}
