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

    // The face and border fade between states instead of switching; a flat tool button fades in.
    property color faceTop: face[0]
    property color faceUpper: face[1]
    property color faceLower: face[2]
    property color faceBottom: face[3]
    property color borderColor: accent ? Theme.accentBorder : (hovered ? Theme.controlBorderHover : Theme.controlBorder)

    signal clicked()

    Behavior on faceTop { ColorAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }
    Behavior on faceUpper { ColorAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }
    Behavior on faceLower { ColorAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }
    Behavior on faceBottom { ColorAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }
    Behavior on borderColor { ColorAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }

    implicitWidth: label.implicitWidth + Theme.space3 * 2
    implicitHeight: 28

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusControl
        opacity: root.flat ? 0 : 1
        border.width: 1
        border.color: root.borderColor

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
            border.color: Theme.controlInner
            opacity: root.pressed ? 0 : 1

            Behavior on opacity {
                NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
            }
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
