import QtQuick
import QtTest
import qs.services
import '../../design'

// A drag source inside a button must not take the button's clicks: clicking a workspace with windows, or
// a preview card, has to keep working while both can also be dragged.
Item {
    id: root

    width: 200
    height: 200

    // Shaped like design/ControlButton.qml: its MouseArea first, the user's children after it.
    Item {
        id: button

        property int clicks: 0

        x: 30
        y: 40
        width: 100
        height: 100

        MouseArea {
            anchors.fill: parent
            onClicked: button.clicks++
        }

        DragSource {
            id: source

            workspaceId: 3
            windowOffset: Qt.point(5, -500)
        }
    }

    TestCase {
        name: 'DragSource'
        when: windowShown

        function init() {
            button.clicks = 0
            BarDrag.begins = 0
        }

        function test_a_click_still_reaches_the_button() {
            mouseClick(button, 50, 50)
            compare(button.clicks, 1)
        }

        function test_moving_far_enough_starts_a_drag_instead_of_a_click() {
            mousePress(button, 50, 50)
            for (let step = 1; step <= 10; step++) {
                mouseMove(button, 50, 50 + step * 5)
            }
            tryCompare(BarDrag, 'begins', 1)
            compare(BarDrag.begunWorkspaceId, 3)
            // Where it was taken from, in bar coordinates: its place in its window plus the window's offset.
            compare(BarDrag.begunOrigin, Qt.rect(35, -460, 100, 100))
            mouseRelease(button, 50, 100)
            compare(button.clicks, 0)
        }
    }
}
