import QtQuick
import qs.services

// One line of text, cut with "…" when it is wider than `maxWidth` (the plain look does not scroll it;
// the tooltip has the whole text).
Item {
    id: marquee

    property string text: ""
    property int maxWidth: 240
    property alias font: first.font
    property alias color: first.color
    readonly property bool overflow: first.implicitWidth > maxWidth

    implicitWidth: Math.min(first.implicitWidth, maxWidth)
    implicitHeight: first.implicitHeight

    Label {
        id: first
        width: marquee.width
        text: marquee.text
        elide: Text.ElideRight
    }
}
