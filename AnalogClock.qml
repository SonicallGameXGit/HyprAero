pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import 'clockHands.js' as ClockHands

// The round clock of the time flyout, after Windows 7's (.aero/STYLE.md "Analog clock"): a dark blue glass
// disc, light ticks, white hour and minute hands and a thin red second hand that ticks, a shine over the
// upper half. Drawn, never a picture, so it is sharp at any size.
Item {
    id: root

    property real diameter: 120
    property var date: new Date()

    readonly property var angles: ClockHands.handAngles(date)
    readonly property real radius: diameter / 2

    implicitWidth: diameter
    implicitHeight: diameter
    Accessible.role: Accessible.StaticText
    Accessible.name: Qt.formatTime(date, 'h:mm')

    // A hand turns about the disc's middle; `tail` reaches past it, backwards.
    component Hand: Item {
        id: hand

        property real angle: 0
        property real length: 0
        property real thickness: 1
        property real tail: 0
        property color color: 'white'

        x: root.radius
        y: root.radius
        rotation: angle

        Rectangle {
            x: -hand.thickness / 2
            y: -hand.length
            width: hand.thickness
            height: hand.length + hand.tail
            radius: hand.thickness / 2
            color: hand.color
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.clockEdge
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: width / 2

        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.clockFaceTop }
            GradientStop { position: 1.0; color: Theme.clockFaceBottom }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: width / 2
        color: 'transparent'
        border.width: 1
        border.color: Theme.clockRim
    }

    // The twelve marks, the ones at 12, 3, 6 and 9 longer.
    Repeater {
        model: 12

        Item {
            id: tick

            required property int index
            readonly property bool major: index % 3 === 0

            x: root.radius
            y: root.radius
            rotation: index * 30

            Rectangle {
                x: -width / 2
                y: -root.radius + root.diameter * 0.06
                width: tick.major ? 2 : 1
                height: root.diameter * (tick.major ? 0.08 : 0.05)
                color: Theme.clockTick
            }
        }
    }

    Hand {
        angle: root.angles.hour
        length: root.radius * 0.5
        thickness: 3
        color: Theme.clockHand
    }

    Hand {
        angle: root.angles.minute
        length: root.radius * 0.75
        thickness: 2
        color: Theme.clockHand
    }

    Hand {
        angle: root.angles.second
        length: root.radius * 0.82
        thickness: 1
        tail: root.radius * 0.18
        color: Theme.clockSecondHand
    }

    // The cap over the hands' pivot.
    Rectangle {
        anchors.centerIn: parent
        width: 6
        height: 6
        radius: 3
        color: Theme.clockSecondHand
    }

    // The shine: an ellipse over the upper half, kept inside the disc (a rounded rectangle's corners
    // stuck out past the edge).
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: 'transparent'

            fillGradient: LinearGradient {
                x1: 0
                y1: root.diameter * 0.04
                x2: 0
                y2: root.diameter * 0.5

                GradientStop { position: 0.0; color: Theme.clockShineTop }
                GradientStop { position: 1.0; color: Theme.clockShineBottom }
            }

            PathAngleArc {
                centerX: root.radius
                centerY: root.diameter * 0.27
                radiusX: root.diameter * 0.36
                radiusY: root.diameter * 0.23
                startAngle: 0
                sweepAngle: 360
            }
        }
    }
}
