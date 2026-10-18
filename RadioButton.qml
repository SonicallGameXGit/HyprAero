import QtQuick
import QtQuick.Effects

// A radio button with its words, as in Windows 7: the check box's materials (check-box-*) made round, a dot
// in the middle when chosen. A click anywhere on it, or Space with keyboard focus (it then glows,
// focus-glow), asks for it (`picked`); the owner sets `checked`.
Item {
    id: root

    property bool checked: false
    property string text: ''

    readonly property int boxSize: 15

    signal picked()

    implicitWidth: box.width + Theme.space2 + label.implicitWidth
    implicitHeight: Math.max(box.height, label.implicitHeight)
    activeFocusOnTab: true
    Accessible.role: Accessible.RadioButton
    Accessible.name: text
    Accessible.checked: checked
    Accessible.onPressAction: picked()
    Keys.onSpacePressed: picked()

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
            radius: width / 2
            blur: Theme.focusGlowBlur
            spread: Theme.focusGlowSpread
            color: Theme.focusGlowColor
            visible: root.activeFocus
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: box.lit ? Theme.checkBoxGapHover : Theme.checkBoxGap
            border.width: 1
            border.color: {
                if (root.activeFocus) {
                    return Theme.focusGlowRing
                }

                return box.lit ? Theme.checkBoxBorderHover : Theme.checkBoxBorder
            }
        }

        // The sunken disc, dark at its top-left, light at its bottom-right.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: width / 2
            rotation: -45
            border.width: 1
            border.color: {
                if (mouseArea.pressed) {
                    return Theme.checkBoxRingActive
                }

                return hoverHandler.hovered ? Theme.checkBoxRingHover : Theme.checkBoxRing
            }

            gradient: Gradient {
                GradientStop { position: 0.0; color: box.face[0] }
                GradientStop { position: 0.5; color: box.face[1] }
                GradientStop { position: 1.0; color: box.face[2] }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 5
            height: 5
            radius: 2.5
            visible: root.checked
            color: Theme.text
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
            root.picked()
        }
    }
}
