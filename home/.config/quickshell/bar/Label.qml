import QtQuick
import qs.services

// Text in the shell's font; `small` and `dim` for the quiet parts (dates, artists, units), `mono` for a
// clock. A value without letters (25%, 17:00) takes figures of one width (tnum), so a counting number
// does not shift what follows it; in words Inter's tnum would also widen the hyphen, comma and space.
Text {
    property bool small: false
    property bool dim: false
    property bool bold: false
    property bool mono: false
    property bool figures: !/[A-Za-z\u00C0-\u024F]/.test(text)

    font.family: mono ? Theme.mono : Theme.font
    font.letterSpacing: mono ? Theme.monoSpacing : Theme.letterSpacing
    font.features: figures && !mono ? ({ "tnum": 1 }) : ({})
    font.pixelSize: small ? Theme.fontSmall : Theme.fontSize
    font.weight: bold ? Font.Bold : Font.Normal
    color: dim ? Theme.dim : Theme.text
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
}
