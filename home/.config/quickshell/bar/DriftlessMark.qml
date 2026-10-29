import QtQuick
import QtQuick.Shapes

// The driftless mark (docs/brand) for the bar: a d whose bowl is an arrow coming back to its stem, in
// one colour. Redrawn on a 24 grid for 14 to 18 pixels: the bowl smaller, the arrowhead much larger
// than in the logo and clear of the stem, so it still reads as an arrow at that size; its ink spans
// the same height as a Material glyph of the same size (3.4 to 20.6).
Item {
    id: mark

    property real size: 16
    property color color: "white"
    readonly property real k: size / 24

    implicitWidth: size
    implicitHeight: size

    Shape {
        width: parent.width
        height: parent.height
        // up by one unit: the glyphs beside it sit a little above the middle
        y: -mark.k
        preferredRendererType: Shape.CurveRenderer

        // the stem
        ShapePath {
            strokeColor: mark.color
            strokeWidth: 2.2 * mark.k
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            startX: 18.5 * mark.k; startY: 4.5 * mark.k
            PathLine { x: 18.5 * mark.k; y: 19.5 * mark.k }
        }
        // the bowl: from the stem's foot round the left to the top
        ShapePath {
            strokeColor: mark.color
            strokeWidth: 2.2 * mark.k
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            startX: 15.1 * mark.k; startY: 16.9 * mark.k
            PathArc { x: 10.5 * mark.k; y: 8.5 * mark.k; radiusX: 5.5 * mark.k; radiusY: 5.5 * mark.k; useLargeArc: true }
        }
        // the arrowhead, pointing at the stem
        ShapePath {
            strokeColor: mark.color
            strokeWidth: 1 * mark.k
            joinStyle: ShapePath.RoundJoin
            fillColor: mark.color
            startX: 16.1 * mark.k; startY: 8.5 * mark.k
            PathLine { x: 10.5 * mark.k; y: 4.8 * mark.k }
            PathLine { x: 10.5 * mark.k; y: 12.2 * mark.k }
            PathLine { x: 16.1 * mark.k; y: 8.5 * mark.k }
        }
    }
}
