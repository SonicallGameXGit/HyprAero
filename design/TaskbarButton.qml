import QtQuick
import QtQuick.Shapes

// An app's button on the taskbar strip, Windows 7's (.aero/STYLE.md, "Taskbar items"): only its icon at
// rest; under the pointer two side lines fading out to the top and bottom, a small light at the bottom
// centre and a light in the app's own colour following the pointer along the bottom; pressed, a face
// darkening through the middle, and what is inside it a pixel down and right. An `open` app is a rounded
// button of its own (`TaskbarItemFace`), the `current` one brighter, fading in and out as it changes. What is
// put inside (the icon) is drawn over all of it.
Item {
    id: root

    // The icon whose main colour lights the button ('' or an icon without colour: the neutral light).
    property string iconSource: ''
    property bool open: false
    property bool current: false
    // Looks hovered without the pointer on it, e.g. while something dragged is over it.
    property bool highlighted: false
    default property alias content: contentItem.data

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: mouseArea.pressed
    readonly property bool lit: hovered || highlighted
    readonly property color glowColor: colorReader.mainColor === '' ? Theme.taskbarItemGlowNeutral : colorReader.mainColor
    // The glow's middle, the colour lit toward white.
    readonly property color glowCore: Qt.tint(glowColor, Qt.rgba(1, 1, 1, Theme.taskbarItemGlowCore))
    // Where the light stands along the bottom: under the pointer, in the middle without one.
    property real glowX: hovered ? hoverHandler.point.position.x : width / 2
    // Only an open app lights up in its colour; anything else (an empty workspace, a pin) has the small light
    // at the bottom centre only, as on Windows 7.
    readonly property bool glowShown: open && (lit || pressed)
    readonly property bool faceShown: (open || current) && pressed === false
    readonly property var faceNow: {
        if (current) {
            return Theme.taskbarItemFaceCurrent
        }

        return lit ? Theme.taskbarItemFaceOpenHover : Theme.taskbarItemFaceOpen
    }

    signal clicked()

    // The light's colour `along` the way out from its middle (0) to its edge (1): its alpha falls off smoothly
    // (smoothstep), and its middle is lit toward white (`taskbar-item-glow-core`) on a soft bell, so the white
    // runs into the colour with no visible ring.
    function glowAt(along: real): color {
        const eased = along * along * (3 - 2 * along)
        const white = Theme.taskbarItemGlowCore * Math.exp(-(along * along) / 0.06)
        return Qt.alpha(Qt.tint(glowColor, Qt.rgba(1, 1, 1, white)), Theme.taskbarItemGlowStrength * (1 - eased))
    }

    // A dark or light side line, fading out to the top and bottom.
    component SideLine: Rectangle {
        id: line

        property color lineColor: 'transparent'

        width: 1
        height: parent.height

        gradient: Gradient {
            GradientStop { position: 0.0; color: 'transparent' }
            GradientStop { position: 0.5; color: line.lineColor }
            GradientStop { position: 1.0; color: 'transparent' }
        }
    }

    Behavior on glowX {
        NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
    }

    Accessible.role: Accessible.Button
    Accessible.onPressAction: clicked()

    IconColorReader {
        id: colorReader

        source: root.iconSource
    }

    // An open app's face; its outline is drawn over the light, further down.
    TaskbarItemFace {
        anchors.fill: parent
        face: root.faceNow
        outline: false
        opacity: root.faceShown ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionSoft; easing.type: Easing.OutCubic }
        }
    }

    // The faces fading out to the top and bottom: a faint one under the pointer, a darker one pressed.
    Rectangle {
        anchors.fill: parent
        opacity: root.lit && root.open === false && root.current === false && root.pressed === false ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
        }

        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.taskbarItemFaceHover[0] }
            GradientStop { position: 0.5; color: Theme.taskbarItemFaceHover[1] }
            GradientStop { position: 1.0; color: Theme.taskbarItemFaceHover[2] }
        }
    }

    Rectangle {
        anchors.fill: parent
        opacity: root.pressed ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
        }

        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.taskbarItemFacePressed[0] }
            GradientStop { position: 0.5; color: Theme.taskbarItemFacePressed[1] }
            GradientStop { position: 1.0; color: Theme.taskbarItemFacePressed[2] }
        }
    }

    // The side lines, each a dark line and a faint light one right of it; an open button has its own edge,
    // so it shows them only pressed.
    Item {
        anchors.fill: parent
        opacity: root.pressed || (root.lit && root.open === false && root.current === false) ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
        }

        SideLine {
            x: 0
            lineColor: Theme.taskbarItemEdge
        }

        SideLine {
            x: 1
            lineColor: Theme.taskbarItemEdgeLight
        }

        SideLine {
            x: parent.width - 2
            lineColor: Theme.taskbarItemEdge
        }

        SideLine {
            x: parent.width - 1
            lineColor: Theme.taskbarItemEdgeLight
        }
    }

    // The small light at the bottom centre, of a button that is not open.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: (root.lit || root.pressed) && root.glowShown === false ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionSoft; easing.type: Easing.OutCubic }
        }

        ShapePath {
            strokeWidth: -1
            strokeColor: 'transparent'

            fillGradient: RadialGradient {
                centerX: root.width / 2
                centerY: root.height
                centerRadius: root.width * 0.22
                focalX: centerX
                focalY: centerY

                GradientStop { position: 0.0; color: Theme.taskbarItemSpot }
                GradientStop { position: 0.5; color: Qt.alpha(Theme.taskbarItemSpot, Theme.taskbarItemSpot.a * 0.4) }
                GradientStop { position: 1.0; color: Qt.alpha(Theme.taskbarItemSpot, 0) }
            }

            PathRectangle {
                width: root.width
                height: root.height
                radius: Theme.radiusControl
            }
        }
    }

    // An open app's light, from the bottom edge under the pointer.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: root.glowShown ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionSoft; easing.type: Easing.OutCubic }
        }

        ShapePath {
            strokeWidth: -1
            strokeColor: 'transparent'

            fillGradient: RadialGradient {
                centerX: root.glowX
                centerY: root.height
                centerRadius: root.width * 0.9
                focalX: centerX
                focalY: centerY

                GradientStop { position: 0.0; color: root.glowAt(0.0) }
                GradientStop { position: 0.1; color: root.glowAt(0.1) }
                GradientStop { position: 0.2; color: root.glowAt(0.2) }
                GradientStop { position: 0.3; color: root.glowAt(0.3) }
                GradientStop { position: 0.4; color: root.glowAt(0.4) }
                GradientStop { position: 0.55; color: root.glowAt(0.55) }
                GradientStop { position: 0.7; color: root.glowAt(0.7) }
                GradientStop { position: 0.85; color: root.glowAt(0.85) }
                GradientStop { position: 1.0; color: root.glowAt(1.0) }
            }

            PathRectangle {
                width: root.width
                height: root.height
                radius: Theme.radiusControl
            }
        }
    }

    // The open face's outline over the light, so it stays dark all round as Windows 7's does.
    TaskbarItemFace {
        anchors.fill: parent
        fill: false
        opacity: root.faceShown || root.glowShown ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionSoft; easing.type: Easing.OutCubic }
        }
    }

    // What is put inside; under the button's own MouseArea, so a drag handler in it lets clicks through.
    Item {
        id: contentItem

        anchors.fill: parent

        transform: Translate {
            x: root.pressed ? 1 : 0
            y: root.pressed ? 1 : 0
        }
    }

    HoverHandler {
        id: hoverHandler
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        onClicked: root.clicked()
    }
}
