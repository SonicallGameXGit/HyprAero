pragma ComponentBehavior: Bound

import QtQuick

// Windows 7's vertical scrollbar for a list (`view`): a sunken track and a glossy thumb (scroll-thumb-*,
// lighter on the left, the horizon down its middle) with three grip lines. The thumb turns blue under the
// pointer and deeper blue while held, and can be dragged; a press on the track pages towards the pointer.
// Only shown while the list is longer than its view.
Item {
    id: root

    property Flickable view: null

    readonly property real shownPart: view === null || view.contentHeight <= 0 ? 1 : Math.min(1, view.height / view.contentHeight)
    readonly property real scrollRange: view === null ? 0 : Math.max(0, view.contentHeight - view.height)
    readonly property real thumbHeight: Math.max(Math.round(height * shownPart), 20)
    readonly property real travel: Math.max(0, height - thumbHeight)
    readonly property real thumbY: {
        if (view === null || scrollRange === 0) {
            return 0
        }

        return Math.round(travel * Math.min(1, Math.max(0, (view.contentY - view.originY) / scrollRange)))
    }

    // Scrolls so the thumb's top is at `y`.
    function scrollTo(y: real): void {
        if (view === null || travel === 0) {
            return
        }

        view.contentY = view.originY + scrollRange * Math.min(1, Math.max(0, y / travel))
    }

    implicitWidth: 17
    visible: shownPart < 1

    Rectangle {
        anchors.fill: parent
        color: Theme.surfaceSunken
        border.width: 1
        border.color: Theme.rowSeparator
    }

    // A press on the track pages towards the pointer, as long as it is held.
    MouseArea {
        id: track

        property real pointerY: 0

        anchors.fill: parent
        onPressed: mouse => {
            pointerY = mouse.y
            page()
            repeat.start()
        }
        onPositionChanged: mouse => pointerY = mouse.y
        onReleased: repeat.stop()
        onCanceled: repeat.stop()

        function page(): void {
            if (pointerY < root.thumbY) {
                root.scrollTo(root.thumbY - root.thumbHeight)
            } else if (pointerY > root.thumbY + root.thumbHeight) {
                root.scrollTo(root.thumbY + root.thumbHeight)
            }
        }

        Timer {
            id: repeat

            interval: 120
            repeat: true
            onTriggered: track.page()
        }
    }

    Item {
        id: thumb

        x: 1
        y: root.thumbY
        width: root.width - 2
        height: root.thumbHeight

        // Windows 7's thumb: the gloss turned on its side, its horizon running down the middle.
        Rectangle {
            id: thumbFace

            readonly property var face: {
                if (grab.pressed) {
                    return Theme.scrollThumbFaceActive
                }

                return grab.containsMouse ? Theme.scrollThumbFaceHover : Theme.scrollThumbFace
            }
            readonly property color edge: {
                if (grab.pressed) {
                    return Theme.scrollThumbBorderActive
                }

                return grab.containsMouse ? Theme.scrollThumbBorderHover : Theme.scrollThumbBorder
            }

            anchors.fill: parent
            radius: Theme.radiusControl
            border.width: 1
            border.color: edge
            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop { position: 0.0; color: thumbFace.face[0] }
                GradientStop { position: 0.49; color: thumbFace.face[1] }
                GradientStop { position: 0.5; color: thumbFace.face[2] }
                GradientStop { position: 1.0; color: thumbFace.face[3] }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Theme.radiusControl - 1
                color: 'transparent'
                border.width: 1
                border.color: Theme.scrollThumbInner
            }
        }

        // The grip: three short etched lines in the middle, when the thumb is tall enough.
        Column {
            anchors.centerIn: parent
            spacing: 1
            visible: thumb.height >= 20

            Repeater {
                model: 3

                Item {
                    width: 7
                    height: 2

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: thumbFace.edge
                    }

                    Rectangle {
                        y: 1
                        width: parent.width
                        height: 1
                        color: Theme.scrollThumbInner
                    }
                }
            }
        }

        MouseArea {
            id: grab

            property real grabOffset: 0

            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            onPressed: mouse => grabOffset = mouse.y
            onPositionChanged: mouse => {
                if (pressed) {
                    root.scrollTo(thumb.mapToItem(root, 0, mouse.y).y - grabOffset)
                }
            }
        }
    }
}
