import QtQuick
import qs.design

// The marker of the current workspace. It slides to the new button and stretches while it travels:
// the edge in the direction of travel moves faster than the one behind it, then both settle.
Item {
    id: root

    // Where the marker should end up (x and width in the parent's coordinates).
    property real targetX: 0
    property real targetWidth: 0

    property real leftEdge: 0
    property real rightEdge: 0
    property bool placed: false
    property int leadDuration: Theme.motionFast
    property int trailDuration: Theme.motionSoft

    x: leftEdge
    width: Math.max(rightEdge - leftEdge, 0)

    onTargetXChanged: retarget()
    onTargetWidthChanged: retarget()

    function retarget(): void {
        if (targetWidth <= 0) {
            return
        }

        // The very first placement must not animate in from the left corner.
        if (!placed) {
            placed = true
            leftEdge = targetX
            rightEdge = targetX + targetWidth
            return
        }

        const movingRight = targetX > leftEdge
        leftEdgeAnimation.duration = movingRight ? trailDuration : leadDuration
        rightEdgeAnimation.duration = movingRight ? leadDuration : trailDuration
        leftEdge = targetX
        rightEdge = targetX + targetWidth
    }

    Behavior on leftEdge {
        NumberAnimation {
            id: leftEdgeAnimation

            easing.type: Easing.OutCubic
        }
    }

    Behavior on rightEdge {
        NumberAnimation {
            id: rightEdgeAnimation

            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusControl
        border.width: 1
        border.color: Theme.controlBorderHover

        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.controlFaceActive[0] }
            GradientStop { position: 0.49; color: Theme.controlFaceActive[1] }
            GradientStop { position: 0.5; color: Theme.controlFaceActive[2] }
            GradientStop { position: 1.0; color: Theme.controlFaceActive[3] }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(Theme.radiusControl - 1, 0)
            color: 'transparent'
            border.width: 1
            border.color: Theme.controlInner
        }
    }
}
