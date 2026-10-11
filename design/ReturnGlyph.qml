import QtQuick
import QtQuick.Shapes

// The flat "put back" arrow (a U-turn to the left, like undo), a structural glyph like `CloseGlyph`.
// Drawn in a 14 x 14 box and scaled to `size`.
Item {
    id: root

    property int size: 14
    property color color: Theme.glassText

    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 14
        height: 14
        scale: root.size / 14
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        // The stem and the bend over the top.
        ShapePath {
            strokeColor: root.color
            strokeWidth: 2
            fillColor: 'transparent'
            capStyle: ShapePath.RoundCap
            startX: 12
            startY: 12

            PathLine { x: 12; y: 7.5 }
            PathArc { x: 3; y: 7.5; radiusX: 4.5; radiusY: 4.5; direction: PathArc.Counterclockwise }
        }

        // The head, pointing down at the end of the bend.
        ShapePath {
            strokeColor: 'transparent'
            fillColor: root.color
            startX: 0
            startY: 7

            PathLine { x: 6; y: 7 }
            PathLine { x: 3; y: 11 }
            PathLine { x: 0; y: 7 }
        }
    }
}
