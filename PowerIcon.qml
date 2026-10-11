import QtQuick
import QtQuick.Shapes

// A glossy red button with the power symbol (icon-red material), the picture of a shut down question.
Item {
    id: root

    property int size: 32

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        border.width: 1
        border.color: Theme.iconRedEdge

        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.iconRedLight }
            GradientStop { position: 1.0; color: Theme.iconRedDark }
        }
    }

    // The symbol: a ring open at the top and a bar through the gap. Drawn in a 32 x 32 box.
    Shape {
        width: 32
        height: 32
        scale: root.size / 32
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Theme.iconInk
            strokeWidth: 3
            fillColor: 'transparent'
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: 16
                centerY: 17
                radiusX: 8.5
                radiusY: 8.5
                startAngle: -55
                sweepAngle: -290
            }
        }

        ShapePath {
            strokeColor: Theme.iconInk
            strokeWidth: 3
            fillColor: 'transparent'
            capStyle: ShapePath.RoundCap
            startX: 16
            startY: 6.5

            PathLine { x: 16; y: 15 }
        }
    }

    Rectangle {
        x: root.size * 0.18
        y: 1
        width: root.size * 0.64
        height: root.size * 0.45
        radius: height / 2

        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.iconGlossTop }
            GradientStop { position: 1.0; color: Theme.iconGlossBottom }
        }
    }
}
