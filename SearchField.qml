import QtQuick

// A one-line search field: sunken white field (field-*), grey hint text while empty, the magnifier at
// its right end. `input` is the text input itself, for focus and keys.
Item {
    id: root

    property alias text: input.text
    property alias input: input
    property string placeholder: ''

    // Every key pressed in the field, before the field handles it; set `accepted` to keep it.
    signal keyPressed(var event)

    implicitHeight: 26
    Accessible.role: Accessible.EditableText
    Accessible.name: placeholder

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
        anchors.right: glyph.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.space2
        anchors.rightMargin: Theme.space1
        clip: true
        color: Theme.text
        selectionColor: Theme.rowSelectedBorder
        selectedTextColor: Theme.surface
        font.family: Theme.fontUi
        font.pixelSize: Theme.fontSizeBody
        Keys.onPressed: event => root.keyPressed(event)
    }

    Text {
        anchors.fill: input
        verticalAlignment: Text.AlignVCenter
        visible: input.text === ''
        text: root.placeholder
        elide: Text.ElideRight
        color: Theme.textMuted
        font.family: Theme.fontUi
        font.pixelSize: Theme.fontSizeBody
        font.italic: true
    }

    SearchGlyph {
        id: glyph

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: Theme.space2
        size: 14
    }
}
