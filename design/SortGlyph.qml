import QtQuick
import QtQuick.Shapes

// The flat "sorted by use" glyph: an arrow up beside an arrow down. Drawn in a 14 x 14 box.
Item {
    id: root

    property int size: 14
    property color color: Theme.textMuted

    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 14
        height: 14
        scale: root.size / 14
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.5
            fillColor: 'transparent'
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 4
            startY: 12.5

            PathLine { x: 4; y: 1.5 }
            PathMove { x: 1; y: 4.5 }
            PathLine { x: 4; y: 1.5 }
            PathLine { x: 7; y: 4.5 }
            PathMove { x: 10; y: 1.5 }
            PathLine { x: 10; y: 12.5 }
            PathMove { x: 7; y: 9.5 }
            PathLine { x: 10; y: 12.5 }
            PathLine { x: 13; y: 9.5 }
        }
    }
}
