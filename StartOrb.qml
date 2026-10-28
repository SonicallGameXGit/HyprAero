pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// The start orb, after the Windows 7 one (.aero/STYLE.md "Start orb"): a dark glass sphere lit from
// below, the Hyprland mark (or a `logo` the module gives) glowing in it, a shine over its upper half. Drawn,
// never a picture, so it is sharp at any size; a `logo` should be an SVG for the same reason. Hover makes it glow, press darkens it; `highlighted` glows as hover does without
// the pointer on it (the bar lights it while its menu is open).
Item {
    id: root

    property real diameter: 40
    property bool hovered: false
    property bool pressed: false
    // Looks hovered without the pointer on it, as `ControlButton.highlighted`.
    property bool highlighted: false
    // The mark's colours and gaps (`HyprlandMark.colors`, `gaps`).
    property string markColors: 'hyprland'
    property bool markGaps: false
    // A picture in place of the mark (Windows 7's flag, from the module's own resources), '' for the mark.
    property url logo: ''

    readonly property bool lit: hovered || highlighted
    // The drop sits a little low, to look centred; a logo is centred as it is (its picture's frame is
    // centred on what it shows).
    readonly property real markOffset: logo.toString() === '' ? diameter * 0.02 : 0

    implicitWidth: diameter
    implicitHeight: diameter

    // The mark, or the logo in its place; the glow and the sharp one below are both this.
    component Mark: Item {
        implicitWidth: root.logo.toString() === '' ? mark.implicitWidth : logo.width
        implicitHeight: root.logo.toString() === '' ? mark.implicitHeight : logo.height

        HyprlandMark {
            id: mark

            anchors.centerIn: parent
            visible: root.logo.toString() === ''
            size: root.diameter * 0.56
            colors: root.markColors
            gaps: root.markGaps
            weight: Theme.orbMarkWeight
        }

        // Drawn at the screen's own pixels from its vectors (`sourceSize` follows the pixel ratio).
        Image {
            id: logo

            anchors.centerIn: parent
            visible: root.logo.toString() !== ''
            source: root.logo
            width: root.diameter * 0.635
            height: width * (implicitHeight > 0 ? implicitHeight / Math.max(implicitWidth, 1) : 1)
            sourceSize.width: width
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }
    }

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

    // The mark's glow is a blurred copy of the mark in its own colours: a shadow takes one colour, and
    // its teal around the mark's blue bottom read as a second, blurred mark.
    Mark {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.markOffset
        opacity: Theme.orbMarkGlow
        layer.enabled: true

        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 0.6
            blurMax: 16
        }
    }

    Mark {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.markOffset
        layer.enabled: true

        layer.effect: MultiEffect {
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
