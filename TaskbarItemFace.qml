import QtQuick

// The face of an open app's button on the taskbar strip, Windows 7's (.aero/STYLE.md, "Taskbar items"): a
// rounded button with a dark border and a light inner line, bright at the top and easing out by 70% of its
// height, no horizon, and the glass's sharp-edged gloss over its top-left (`GlassShine`). `face` is one of the
// taskbar-item-face-* tokens (top, 70%, bottom); a change fades. The fill and the outline can be drawn apart
// (`fill`, `outline`), so a light can go between them.
Item {
    id: root

    property var face: Theme.taskbarItemFaceOpen
    property bool fill: true
    property bool outline: true

    property color faceTop: face[0]
    property color faceMiddle: face[1]
    property color faceBottom: face[2]

    Behavior on faceTop { ColorAnimation { duration: Theme.motionSoft; easing.type: Easing.OutCubic } }
    Behavior on faceMiddle { ColorAnimation { duration: Theme.motionSoft; easing.type: Easing.OutCubic } }
    Behavior on faceBottom { ColorAnimation { duration: Theme.motionSoft; easing.type: Easing.OutCubic } }

    // The face from the top to 70% of the height, eased out as Windows 7's (fast first, then settling), so
    // no stop shows; `along` 0 is the top, 1 is 70%.
    function faceAt(along: real): color {
        const eased = 1 - (1 - along) * (1 - along)
        return Qt.rgba(
            faceTop.r + (faceMiddle.r - faceTop.r) * eased,
            faceTop.g + (faceMiddle.g - faceTop.g) * eased,
            faceTop.b + (faceMiddle.b - faceTop.b) * eased,
            faceTop.a + (faceMiddle.a - faceTop.a) * eased,
        )
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(Theme.radiusControl - 1, 0)
        visible: root.fill

        gradient: Gradient {
            GradientStop { position: 0.0; color: root.faceAt(0.0) }
            GradientStop { position: 0.14; color: root.faceAt(0.2) }
            GradientStop { position: 0.28; color: root.faceAt(0.4) }
            GradientStop { position: 0.42; color: root.faceAt(0.6) }
            GradientStop { position: 0.56; color: root.faceAt(0.8) }
            GradientStop { position: 0.7; color: root.faceAt(1.0) }
            GradientStop { position: 1.0; color: root.faceBottom }
        }

        GlassShine {
            anchors.fill: parent
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusControl
        visible: root.outline
        color: 'transparent'
        border.width: 1
        border.color: Theme.taskbarItemBorder

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(Theme.radiusControl - 1, 0)
            color: 'transparent'
            border.width: 1
            border.color: Theme.taskbarItemInner
        }
    }
}
