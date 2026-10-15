import QtQuick
import QtQuick.Effects

// The family button. kind: 'normal', 'accent' (the one main action), 'tool' (flat until hovered) or
// 'danger' (red, for what destroys something); standing on the shell's glass, 'glass' (a button of glass,
// white words) or 'glassTool' (flat until hovered), which light up as glass (glass-button-*). `current` marks
// the selected one on glass (a button whose flyout is open). With keyboard focus it glows (focus-glow) and
// Enter or Space press it. Disabled, it is flat and grey (control-*-disabled).
Item {
    id: root

    property string kind: 'normal'
    property string text: ''
    // Looks hovered without the pointer on it, e.g. while something dragged is over it.
    property bool highlighted: false
    // On glass: the selected one, brighter than under the pointer.
    property bool current: false

    // Hover counts over the button's own children too (a button inside a button keeps both lit).
    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: mouseArea.pressed
    readonly property bool lit: hovered || highlighted
    readonly property bool glassy: kind === 'glass' || kind === 'glassTool'
    readonly property bool flat: (kind === 'tool' || kind === 'glassTool') && !lit && !pressed && !current
    readonly property bool accent: kind === 'accent'
    readonly property bool danger: kind === 'danger'
    readonly property var face: {
        if (enabled === false) {
            return [Theme.controlFaceDisabled, Theme.controlFaceDisabled, Theme.controlFaceDisabled, Theme.controlFaceDisabled]
        }

        if (accent) {
            return pressed ? Theme.accentFaceActive : (lit ? Theme.accentFaceHover : Theme.accentFace)
        }

        if (danger) {
            return pressed ? Theme.dangerFaceActive : (lit ? Theme.dangerFaceHover : Theme.dangerFace)
        }

        if (glassy) {
            if (pressed) {
                return Theme.glassButtonFaceActive
            }

            if (current) {
                return Theme.glassButtonFaceCurrent
            }

            return lit ? Theme.glassButtonFaceHover : Theme.glassButtonFace
        }

        return pressed ? Theme.controlFaceActive : (lit ? Theme.controlFaceHover : Theme.controlFace)
    }

    // The face and border fade between states instead of switching; a flat tool button fades in.
    property color faceTop: face[0]
    property color faceUpper: face[1]
    property color faceLower: face[2]
    property color faceBottom: face[3]
    property color borderColor: {
        if (enabled === false) {
            return Theme.controlBorderDisabled
        }

        if (accent) {
            return Theme.accentBorder
        }

        if (danger) {
            return Theme.dangerControlBorder
        }

        if (glassy) {
            return Theme.glassButtonBorder
        }

        return lit ? Theme.controlBorderHover : Theme.controlBorder
    }

    signal clicked()

    Behavior on faceTop { ColorAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }
    Behavior on faceUpper { ColorAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }
    Behavior on faceLower { ColorAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }
    Behavior on faceBottom { ColorAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }
    Behavior on borderColor { ColorAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }

    implicitWidth: label.implicitWidth + Theme.space3 * 2
    implicitHeight: 28
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: clicked()
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onSpacePressed: clicked()

    // The glow sits outside the button, so it is drawn first.
    RectangularShadow {
        anchors.fill: parent
        radius: Theme.radiusControl
        blur: Theme.focusGlowBlur
        spread: Theme.focusGlowSpread
        color: Theme.focusGlowColor
        visible: root.activeFocus
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusControl
        opacity: root.flat && root.activeFocus === false ? 0 : 1
        border.width: 1
        border.color: root.activeFocus ? Theme.focusGlowRing : root.borderColor

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
        }

        gradient: Gradient {
            GradientStop { position: 0.0; color: root.faceTop }
            GradientStop { position: 0.49; color: root.faceUpper }
            GradientStop { position: 0.5; color: root.faceLower }
            GradientStop { position: 1.0; color: root.faceBottom }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(Theme.radiusControl - 1, 0)
            color: 'transparent'
            border.width: 1
            border.color: root.glassy ? Theme.glassButtonInner : Theme.controlInner
            opacity: root.pressed ? 0 : 1

            Behavior on opacity {
                NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
            }
        }
    }

    GlassText {
        id: label

        anchors.centerIn: parent
        text: root.text
        color: {
            if (root.enabled === false) {
                return Theme.controlTextDisabled
            }

            if (root.glassy) {
                return Theme.taskbarGlassText
            }

            return root.accent || root.danger ? Theme.accentText : Theme.controlText
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
