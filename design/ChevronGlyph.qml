import QtQuick
import QtQuick.Shapes

// The flat small triangle of a button that opens a menu, pointing right (Windows 7's shut down arrow).
Item {
    id: root

    property int size: 8
    property color color: Theme.controlText

    implicitWidth: size
    implicitHeight: size

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: 'transparent'
            fillColor: root.color
            startX: root.size * 0.25
            startY: 0

            PathLine { x: root.size * 0.8; y: root.size / 2 }
            PathLine { x: root.size * 0.25; y: root.size }
            PathLine { x: root.size * 0.25; y: 0 }
        }
    }
}
