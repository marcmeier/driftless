import QtQuick
import qs.services

// One Nerd Font glyph as wide and as high as the ink it draws, not its cell: for symbols on a filled
// shape, where Icon's fixed cells leave a narrow glyph with more room on one side than on the other.
Item {
    id: icon

    property string text: ""
    property int size: 14
    property color color: Theme.text
    readonly property rect ink: metrics.tightBoundingRect

    implicitWidth: Math.ceil(ink.width)
    implicitHeight: Math.ceil(ink.height)

    TextMetrics {
        id: metrics
        font: label.font
        text: icon.text
    }

    // tightBoundingRect is measured from the start of the baseline, the label from its top-left
    Text {
        id: label
        x: -icon.ink.x
        y: -icon.ink.y - baselineOffset
        text: icon.text
        font.family: Theme.font
        font.pixelSize: icon.size
        color: icon.color
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
    }
}
