pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// The start orb, after the Windows 7 one (.aero/STYLE.md "Start orb"): a dark glass sphere lit from
// below, the Hyprland mark glowing in it, a shine over its upper half. Drawn, never a picture, so it is
// sharp at any size. Hover makes it glow, press darkens it; `highlighted` glows as hover does without
// the pointer on it (the bar lights it while its menu is open).
Item {
    id: root

    property real diameter: 40
    property bool hovered: false
    property bool pressed: false
    // Looks hovered without the pointer on it, as `ControlButton.highlighted`.
    property bool highlighted: false

    readonly property bool lit: hovered || highlighted

    implicitWidth: diameter
    implicitHeight: diameter

    // A circle filling the item, for the shapes below.
    component Disc: Shape {
        id: disc

        property alias fill: discPath.fillGradient
        property alias fillColor: discPath.fillColor

        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            id: discPath

            strokeColor: 'transparent'

            PathAngleArc {
                centerX: disc.width / 2
                centerY: disc.height / 2
                radiusX: disc.width / 2
                radiusY: disc.height / 2
                startAngle: 0
                sweepAngle: 360
            }
        }
    }

    // Its shadow on what is under it, so it stands on the bar instead of looking set into it.
    RectangularShadow {
        anchors.fill: parent
        radius: width / 2
        offset.y: 1
        blur: Theme.orbGlowBlur / 2
        color: Theme.iconShadow
    }

    // The glow sits outside the orb, so it is drawn first.
    RectangularShadow {
        anchors.fill: parent
        radius: width / 2
        blur: Theme.orbGlowBlur
        color: Theme.orbGlow
        opacity: root.lit && root.pressed === false ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionSoft; easing.type: Easing.OutCubic }
        }
    }

    Disc {
        anchors.fill: parent
        fillColor: Theme.orbEdge
    }

    // The body, lit from its bottom centre.
    Disc {
        anchors.fill: parent
        anchors.margins: 1

        fill: RadialGradient {
            centerX: root.diameter / 2 - 1
            centerY: root.diameter * 0.92
            centerRadius: root.diameter * 0.8
            focalX: centerX
            focalY: centerY

            GradientStop { position: 0.0; color: Theme.orbBodyCenter }
            GradientStop { position: 0.45; color: Theme.orbBodyMiddle }
            GradientStop { position: 1.0; color: Theme.orbBodyOuter }
        }
    }

    Disc {
        anchors.fill: parent
        anchors.margins: 1
        fillColor: root.pressed ? Theme.orbPressedTint : Theme.orbHoverTint
        opacity: root.lit || root.pressed ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
        }
    }

    HyprlandMark {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.diameter * 0.02
        size: root.diameter * 0.56
        layer.enabled: true

        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.orbMarkGlow
            shadowBlur: 0.6
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            brightness: root.lit && root.pressed === false ? 0.15 : 0
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: width / 2
        color: 'transparent'
        border.width: 1
        border.color: Theme.orbRim
    }

    // The shine: a flattened disc over the upper half.
    Disc {
        x: root.diameter * 0.14
        y: root.diameter * 0.04
        width: root.diameter * 0.72
        height: root.diameter * 0.46

        fill: LinearGradient {
            x1: 0
            y1: 0
            x2: 0
            y2: root.diameter * 0.46

            GradientStop { position: 0.0; color: Theme.orbShineTop }
            GradientStop { position: 1.0; color: Theme.orbShineBottom }
        }
    }
}
