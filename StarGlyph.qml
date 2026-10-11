import QtQuick
import QtQuick.Shapes

// The "featured" star: a glossy gold star when on (icon-gold), a flat outline when off.
Item {
    id: root

    property int size: 16
    property bool on: false
    property color offColor: Theme.textMuted

    // The ten corners of a five-pointed star in the box, the first point straight up.
    readonly property var corners: {
        const result = []
        const center = size / 2
        const outer = size / 2 - 0.5
        const inner = outer * 0.45
        for (let index = 0; index <= 10; index++) {
            const angle = (-90 + index * 36) * Math.PI / 180
            const radius = index % 2 === 0 ? outer : inner
            result.push(Qt.point(center + radius * Math.cos(angle), center + 0.6 + radius * Math.sin(angle)))
        }

        return result
    }

    implicitWidth: size
    implicitHeight: size

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.on ? Theme.iconGoldEdge : root.offColor
            strokeWidth: 1
            joinStyle: ShapePath.RoundJoin
            fillColor: 'transparent'
            fillGradient: root.on ? gold : null

            PathPolyline {
                path: root.corners
            }
        }
    }

    LinearGradient {
        id: gold

        x1: 0
        y1: 0
        x2: 0
        y2: root.size

        GradientStop { position: 0.0; color: Theme.iconGoldLight }
        GradientStop { position: 1.0; color: Theme.iconGoldDark }
    }
}
