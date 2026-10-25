import QtQuick
import qs.services

// Text in the shell's font; `small` and `dim` for the quiet parts (dates, artists, units).
Text {
    property bool small: false
    property bool dim: false
    property bool bold: false

    font.family: Theme.font
    font.pixelSize: small ? 12 : 13
    font.weight: bold ? Font.Bold : Font.Normal
    color: dim ? Theme.dim : Theme.text
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
}
