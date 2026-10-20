import QtQuick
import qs.design

// The narrow block at the right end of the bar, where Windows 7 has "Show desktop", drawn like it
// (.aero/STYLE.md, "Show desktop"): set off by a dark line with a faint light one after it, a darker glass
// with a light inner line all round and the glass's sharp-edged gloss over its top (`GlassShine`), lighter under the pointer
// and darker pressed. Here it goes to the first workspace without windows.
Item {
    id: root

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: mouseArea.pressed
    readonly property var face: {
        if (pressed) {
            return Theme.showDesktopFaceActive
        }

        return hovered ? Theme.showDesktopFaceHover : Theme.showDesktopFace
    }

    // The face fades between states instead of switching.
    property color faceTop: face[0]
    property color faceUpper: face[1]
    property color faceBottom: face[2]

    signal clicked()

    // Between two colours, `along` 0 to 1, eased in and out.
    function faceAt(from: color, to: color, along: real): color {
        const eased = along * along * (3 - 2 * along)
        return Qt.rgba(
            from.r + (to.r - from.r) * eased,
            from.g + (to.g - from.g) * eased,
            from.b + (to.b - from.b) * eased,
            from.a + (to.a - from.a) * eased,
        )
    }

    Behavior on faceTop { ColorAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }
    Behavior on faceUpper { ColorAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }
    Behavior on faceBottom { ColorAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }

    implicitWidth: 15
    Accessible.role: Accessible.Button
    Accessible.name: qsTr('Go to an empty workspace')
    Accessible.onPressAction: clicked()

    Rectangle {
        width: 1
        height: parent.height
        color: Theme.taskbarItemEdge
    }

    Rectangle {
        x: 1
        width: 1
        height: parent.height
        color: Theme.taskbarItemEdgeLight
    }

    Rectangle {
        x: 2
        width: parent.width - 2
        height: parent.height
        border.width: 1
        border.color: Theme.taskbarGlassBorderInner

        // Eased between the stops, so neither shows: quickly into the dark, then slowly back out of it.
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.faceAt(root.faceTop, root.faceUpper, 0.0) }
            GradientStop { position: 0.08; color: root.faceAt(root.faceTop, root.faceUpper, 0.33) }
            GradientStop { position: 0.16; color: root.faceAt(root.faceTop, root.faceUpper, 0.66) }
            GradientStop { position: 0.25; color: root.faceUpper }
            GradientStop { position: 0.5; color: root.faceAt(root.faceUpper, root.faceBottom, 0.33) }
            GradientStop { position: 0.75; color: root.faceAt(root.faceUpper, root.faceBottom, 0.66) }
            GradientStop { position: 1.0; color: root.faceBottom }
        }

        GlassShine {
            anchors.fill: parent
            anchors.margins: 1
            leftY: 0.35
            rightY: 0.12
            strong: Theme.showDesktopShine
            faint: Qt.alpha(Theme.showDesktopShine, Theme.showDesktopShine.a * 0.25)
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
