import QtQuick
import qs.design

// The narrow strip at the right end of the bar, where Windows 7 has "Show desktop". Here it goes to the
// first workspace without windows. Plain glass behind a separator until hovered, then it lights up as
// glass, like a glass button.
Item {
    id: root

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: mouseArea.pressed
    readonly property var face: pressed ? Theme.glassButtonFaceActive : Theme.glassButtonFaceHover

    signal clicked()

    implicitWidth: 14
    Accessible.role: Accessible.Button
    Accessible.name: qsTr('Go to an empty workspace')

    // The separator: a dark line and a bright one, like the glass edge.
    Rectangle {
        width: 1
        height: parent.height
        color: Theme.taskbarGlassBorderOuter
    }

    Rectangle {
        x: 1
        width: 1
        height: parent.height
        color: Theme.taskbarGlassBorderInner
    }

    Rectangle {
        x: 2
        width: parent.width - 2
        height: parent.height
        opacity: root.hovered || root.pressed ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
        }

        gradient: Gradient {
            GradientStop { position: 0.0; color: root.face[0] }
            GradientStop { position: 0.49; color: root.face[1] }
            GradientStop { position: 0.5; color: root.face[2] }
            GradientStop { position: 1.0; color: root.face[3] }
        }

        Rectangle {
            anchors.fill: parent
            color: 'transparent'
            border.width: 1
            border.color: Theme.glassButtonInner
            opacity: root.pressed ? 0 : 1
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
