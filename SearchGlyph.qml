import QtQuick
import QtQuick.Shapes

// The flat magnifier of a search field. Drawn in a 14 x 14 box.
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

            PathAngleArc {
                centerX: 5.75
                centerY: 5.75
                radiusX: 4.5
                radiusY: 4.5
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: 2
            fillColor: 'transparent'
            capStyle: ShapePath.RoundCap
            startX: 9
            startY: 9

            PathLine { x: 13; y: 13 }
        }
    }
}
