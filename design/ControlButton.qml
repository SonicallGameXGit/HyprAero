import QtQuick

// The family button. kind: 'normal', 'accent' (the one main action) or 'tool' (flat until hovered).
Item {
    id: root

    property string kind: 'normal'
    property string text: ''

    readonly property bool hovered: mouseArea.containsMouse
    readonly property bool pressed: mouseArea.pressed
    readonly property bool flat: kind === 'tool' && !hovered && !pressed
    readonly property bool accent: kind === 'accent'
    readonly property var face: {
        if (accent) {
            return pressed ? Theme.accentFaceActive : (hovered ? Theme.accentFaceHover : Theme.accentFace)
        }

        return pressed ? Theme.controlFaceActive : (hovered ? Theme.controlFaceHover : Theme.controlFace)
    }

    signal clicked()

    implicitWidth: label.implicitWidth + Theme.space3 * 2
    implicitHeight: 28

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusControl
        visible: !root.flat
        border.width: 1
        border.color: root.accent ? Theme.accentBorder : (root.hovered ? Theme.controlBorderHover : Theme.controlBorder)

        gradient: Gradient {
            GradientStop { position: 0.0; color: root.face[0] }
            GradientStop { position: 0.49; color: root.face[1] }
            GradientStop { position: 0.5; color: root.face[2] }
            GradientStop { position: 1.0; color: root.face[3] }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(Theme.radiusControl - 1, 0)
            color: 'transparent'
            border.width: 1
            border.color: Theme.controlInner
            visible: !root.pressed
        }
    }

    Text {
        id: label

        anchors.centerIn: parent
        text: root.text
        color: root.accent ? Theme.accentText : Theme.controlText
        font.family: Theme.fontUi
        font.pixelSize: Theme.fontSizeBody
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
