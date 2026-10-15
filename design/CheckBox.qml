import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// A check box with its words, as in Windows 7 (check-box-*): a small box, a light gap, and a sunken square
// inside it shaded from its top-left corner; under the pointer it turns light blue, pressed a deeper blue. It
// shows a check mark when on. A click anywhere on it, or Space with keyboard focus (it then glows,
// focus-glow), turns it over; `toggled` says the new state, the owner sets `checked`.
Item {
    id: root

    property bool checked: false
    property string text: ''

    readonly property int boxSize: 15

    signal toggled(bool checked)

    implicitWidth: box.width + Theme.space2 + label.implicitWidth
    implicitHeight: Math.max(box.height, label.implicitHeight)
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: text
    Accessible.checked: checked
    Accessible.onToggleAction: toggled(checked === false)
    Accessible.onPressAction: toggled(checked === false)
    Keys.onSpacePressed: toggled(checked === false)

    Item {
        id: box

        readonly property bool lit: hoverHandler.hovered || mouseArea.pressed
        readonly property var face: {
            if (mouseArea.pressed) {
                return Theme.checkBoxFaceActive
            }

            return hoverHandler.hovered ? Theme.checkBoxFaceHover : Theme.checkBoxFace
        }

        anchors.verticalCenter: parent.verticalCenter
        width: root.boxSize
        height: root.boxSize

        RectangularShadow {
            anchors.fill: parent
            blur: Theme.focusGlowBlur
            spread: Theme.focusGlowSpread
            color: Theme.focusGlowColor
            visible: root.activeFocus
        }

        // The box and the light gap inside its border.
        Rectangle {
            anchors.fill: parent
            color: box.lit ? Theme.checkBoxGapHover : Theme.checkBoxGap
            border.width: 1
            border.color: {
                if (root.activeFocus) {
                    return Theme.focusGlowRing
                }

                return box.lit ? Theme.checkBoxBorderHover : Theme.checkBoxBorder
            }
        }

        // The sunken square: dark in the top-left corner, light in the bottom-right one.
        Shape {
            id: square

            anchors.fill: parent
            anchors.margins: 2
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: -1
                fillGradient: LinearGradient {
                    x1: 0
                    y1: 0
                    x2: square.width
                    y2: square.height

                    GradientStop { position: 0.0; color: box.face[0] }
                    GradientStop { position: 0.5; color: box.face[1] }
                    GradientStop { position: 1.0; color: box.face[2] }
                }

                PathRectangle {
                    width: square.width
                    height: square.height
                }
            }
        }

        Rectangle {
            anchors.fill: square
            color: 'transparent'
            border.width: 1
            border.color: {
                if (mouseArea.pressed) {
                    return Theme.checkBoxRingActive
                }

                return hoverHandler.hovered ? Theme.checkBoxRingHover : Theme.checkBoxRing
            }
        }

        CheckGlyph {
            anchors.centerIn: parent
            visible: root.checked
            size: root.boxSize - 4
        }
    }

    Text {
        id: label

        x: box.width + Theme.space2
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: Theme.text
        font.family: Theme.fontUi
        font.pixelSize: Theme.fontSizeBody
    }

    HoverHandler {
        id: hoverHandler
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        onClicked: {
            root.forceActiveFocus()
            root.toggled(root.checked === false)
        }
    }
}
