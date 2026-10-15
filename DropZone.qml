import QtQuick
import QtQuick.Effects

// A place to drop something on: a slot of the shell's taskbar glass with a glyph and, when it fits, a short text saying what a
// drop there does. While what is dragged is over it (`lit`) its edge glows like a focused control.
// Behind it the compositor's blur shows when the user's layer rule asks for it (README.md).
Item {
    id: root

    property bool lit: false
    property string text: ''

    // The glow sits outside the slot, so it is drawn first and the glass on top of it.
    RectangularShadow {
        anchors.fill: parent
        radius: Theme.radiusControl
        blur: Theme.focusGlowBlur
        spread: Theme.focusGlowSpread
        color: Theme.focusGlowColor
        opacity: root.lit ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
        }
    }

    GlassPanel {
        anchors.fill: parent
        cornerRadius: Theme.radiusControl
        kind: 'taskbar'
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusControl
        color: 'transparent'
        border.width: 1
        border.color: Theme.focusGlowRing
        opacity: root.lit ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
        }
    }

    Row {
        id: content

        // The text only when it fits with room around it; the glyph says it alone otherwise.
        readonly property bool textFits: glyph.width + spacing + label.implicitWidth + Theme.space3 * 2 <= root.width

        anchors.centerIn: parent
        spacing: Theme.space2

        ReturnGlyph {
            id: glyph

            anchors.verticalCenter: parent.verticalCenter
            size: 14
        }

        GlassText {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            visible: content.textFits && root.text !== ''
            text: root.text
        }
    }
}
