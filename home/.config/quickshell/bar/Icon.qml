import QtQuick
import qs.services

// One Nerd Font glyph in a cell of fixed width, so icons of different widths line up and keep their
// gaps (Waybar needed a padding per glyph for that).
Text {
    property int size: 14

    width: Math.round(size * 1.3)
    height: size + 4
    font.family: Theme.font
    font.pixelSize: size
    color: Theme.text
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
}
