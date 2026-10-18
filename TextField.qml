import QtQuick

// A one-line text field: the sunken white field of `SearchField` (field-*), without the magnifier.
// `hidden` shows dots instead of the characters (a password or a network key). `input` is the text input
// itself, for focus and keys.
Item {
    id: root

    property alias text: input.text
    property alias input: input
    property bool hidden: false

    // Enter was pressed in the field; Escape was (taken here, so it does not also close what holds it).
    signal accepted()
    signal escaped()

    implicitWidth: 200
    implicitHeight: 26
    Accessible.role: Accessible.EditableText

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusControl
        color: Theme.fieldBackground
        border.width: 1
        border.color: input.activeFocus ? Theme.focusGlowRing : Theme.fieldBorder

        // The darker top edge and the inset shadow under it.
        Rectangle {
            x: 1
            y: 0
            width: parent.width - 2
            height: 1
            color: input.activeFocus ? Theme.focusGlowRing : Theme.fieldBorderTop
        }

        Rectangle {
            x: 1
            y: 1
            width: parent.width - 2
            height: Theme.fieldInnerShadowSize

            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.fieldInnerShadow }
                GradientStop { position: 1.0; color: 'transparent' }
            }
        }
    }

    TextInput {
        id: input

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.space2
        anchors.rightMargin: Theme.space2
        clip: true
        echoMode: root.hidden ? TextInput.Password : TextInput.Normal
        color: Theme.text
        selectionColor: Theme.rowSelectedBorder
        selectedTextColor: Theme.surface
        font.family: Theme.fontUi
        font.pixelSize: Theme.fontSizeBody
        onAccepted: root.accepted()
        Keys.onEscapePressed: event => {
            root.escaped()
            event.accepted = true
        }
    }
}
