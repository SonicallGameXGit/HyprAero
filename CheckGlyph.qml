import QtQuick
import QtQuick.Shapes

// The flat check mark of a ticked menu entry or check box.
Item {
    id: root

    property int size: 10
    property color color: Theme.text

    implicitWidth: size
    implicitHeight: size

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: Math.max(1.5, root.size / 6)
            fillColor: 'transparent'
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: root.size * 0.12
            startY: root.size * 0.55

            PathLine { x: root.size * 0.4; y: root.size * 0.82 }
            PathLine { x: root.size * 0.9; y: root.size * 0.18 }
        }
    }
}
