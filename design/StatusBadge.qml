import QtQuick
import QtQuick.Shapes

// The small sign Windows 7 lays over the corner of a notification-area icon to say how things are, from the
// icon materials: 'error' (a red cross: nothing works), 'warning' (a gold triangle with "!": works only in
// part), 'available' (a gold star: something is there to connect to), 'busy' (a turning blue disc:
// working), 'check' (a green disc with a tick: done, safe), 'muted' (a red no-entry sign); 'none' draws
// nothing. Drawn in a 10 x 10 box.
Item {
    id: root

    property string kind: 'none'
    property real size: 10

    implicitWidth: size
    implicitHeight: size
    visible: kind !== 'none'

    Item {
        width: 10
        height: 10
        scale: root.size / 10
        transformOrigin: Item.TopLeft

        // The cross: a dark edge under the red strokes.
        Shape {
            anchors.fill: parent
            visible: root.kind === 'error'
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Theme.iconRedEdge
                strokeWidth: 3.6
                fillColor: 'transparent'
                capStyle: ShapePath.RoundCap
                startX: 2
                startY: 2

                PathLine { x: 8; y: 8 }
                PathMove { x: 8; y: 2 }
                PathLine { x: 2; y: 8 }
            }

            ShapePath {
                strokeColor: Theme.iconRedDark
                strokeWidth: 2
                fillColor: 'transparent'
                capStyle: ShapePath.RoundCap
                startX: 2
                startY: 2

                PathLine { x: 8; y: 8 }
                PathMove { x: 8; y: 2 }
                PathLine { x: 2; y: 8 }
            }
        }

        Shape {
            anchors.fill: parent
            visible: root.kind === 'warning'
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Theme.iconGoldEdge
                strokeWidth: 1
                joinStyle: ShapePath.RoundJoin
                fillGradient: LinearGradient {
                    y2: 10

                    GradientStop { position: 0.0; color: Theme.iconGoldLight }
                    GradientStop { position: 1.0; color: Theme.iconGoldDark }
                }
                startX: 5
                startY: 0.6

                PathLine { x: 9.5; y: 9.4 }
                PathLine { x: 0.5; y: 9.4 }
                PathLine { x: 5; y: 0.6 }
            }

            ShapePath {
                strokeColor: Theme.iconInkDark
                strokeWidth: 1.4
                fillColor: 'transparent'
                capStyle: ShapePath.RoundCap
                startX: 5
                startY: 3.6

                PathLine { x: 5; y: 6.2 }
                PathMove { x: 5; y: 8 }
                PathLine { x: 5; y: 8.1 }
            }
        }

        // A five-pointed star.
        Shape {
            anchors.fill: parent
            visible: root.kind === 'available'
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Theme.iconGoldEdge
                strokeWidth: 0.8
                joinStyle: ShapePath.RoundJoin
                fillGradient: LinearGradient {
                    y2: 10

                    GradientStop { position: 0.0; color: Theme.iconGoldLight }
                    GradientStop { position: 1.0; color: Theme.iconGoldDark }
                }
                startX: 5
                startY: 0.4

                PathLine { x: 6.3; y: 3.4 }
                PathLine { x: 9.6; y: 3.7 }
                PathLine { x: 7.1; y: 5.9 }
                PathLine { x: 7.9; y: 9.3 }
                PathLine { x: 5; y: 7.5 }
                PathLine { x: 2.1; y: 9.3 }
                PathLine { x: 2.9; y: 5.9 }
                PathLine { x: 0.4; y: 3.7 }
                PathLine { x: 3.7; y: 3.4 }
                PathLine { x: 5; y: 0.4 }
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 0.5
            visible: root.kind === 'busy' || root.kind === 'check'
            radius: width / 2
            border.width: 1
            border.color: root.kind === 'busy' ? Theme.iconBlueEdge : Theme.iconGreenEdge

            gradient: Gradient {
                GradientStop { position: 0.0; color: root.kind === 'busy' ? Theme.iconBlueLight : Theme.iconGreenLight }
                GradientStop { position: 1.0; color: root.kind === 'busy' ? Theme.iconBlueDark : Theme.iconGreenDark }
            }
        }

        // The busy disc's turning arc.
        Shape {
            id: arc

            anchors.fill: parent
            visible: root.kind === 'busy'
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Theme.iconInk
                strokeWidth: 1.4
                fillColor: 'transparent'
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: 5
                    centerY: 5
                    radiusX: 2.6
                    radiusY: 2.6
                    startAngle: 0
                    sweepAngle: 250
                }
            }

            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
                running: arc.visible
            }
        }

        CheckGlyph {
            x: 2
            y: 2
            visible: root.kind === 'check'
            size: 6
            color: Theme.iconInk
        }

        // No entry: a red ring and a slash on white.
        Shape {
            anchors.fill: parent
            visible: root.kind === 'muted'
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Theme.iconRedDark
                strokeWidth: 1.6
                fillColor: Theme.iconInk

                PathAngleArc {
                    centerX: 5
                    centerY: 5
                    radiusX: 4
                    radiusY: 4
                    startAngle: 0
                    sweepAngle: 360
                }
            }

            ShapePath {
                strokeColor: Theme.iconRedDark
                strokeWidth: 1.6
                fillColor: 'transparent'
                startX: 2.4
                startY: 2.4

                PathLine { x: 7.6; y: 7.6 }
            }
        }
    }
}
