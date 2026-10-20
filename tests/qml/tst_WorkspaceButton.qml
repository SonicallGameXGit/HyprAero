import QtQuick
import QtTest
import '../../modules/bar'

// A workspace button (the real WorkspaceButton and TaskbarButton): a click switches, a sideways drag of one
// with windows asks the bar to reorder (started, moved by the offset along the bar, ended) and never clicks;
// an up-and-down drag or an empty workspace starts nothing.
Item {
    id: root

    width: 300
    height: 100

    WorkspaceButton {
        id: button

        property int clicks: 0
        property int starts: 0
        property int ends: 0
        property real lastOffset: 0

        x: 100
        y: 20
        width: 72
        height: 48
        entry: ({ id: 2, focused: false, mainApp: 'kitty', secondApp: null, windows: [{ address: '0x1', appId: 'kitty' }] })
        onClicked: clicks++
        onReorderStarted: starts++
        onReorderMoved: offset => lastOffset = offset
        onReorderEnded: ends++
    }

    TestCase {
        name: 'WorkspaceButton'
        when: windowShown

        function init() {
            button.clicks = 0
            button.starts = 0
            button.ends = 0
            button.lastOffset = 0
            button.entry = { id: 2, focused: false, mainApp: 'kitty', secondApp: null, windows: [{ address: '0x1', appId: 'kitty' }] }
        }

        function drag(dx, dy) {
            mousePress(button, 36, 24)
            for (let step = 1; step <= 10; step++) {
                mouseMove(button, 36 + dx * step / 10, 24 + dy * step / 10)
                wait(10)
            }
            mouseRelease(button, 36 + dx, 24 + dy)
        }

        function test_a_click_switches() {
            mouseClick(button, 36, 24)
            compare(button.clicks, 1)
            compare(button.starts, 0)
        }

        function test_a_sideways_drag_reorders_and_does_not_click() {
            drag(80, 0)
            compare(button.starts, 1)
            compare(button.ends, 1)
            compare(button.lastOffset, 80)
            compare(button.clicks, 0)
        }

        function test_the_offset_is_along_the_bar_only() {
            drag(-60, 15)
            compare(button.starts, 1)
            compare(button.lastOffset, -60)
        }

        function test_an_up_and_down_drag_starts_nothing() {
            drag(0, -40)
            compare(button.starts, 0)
        }

        function test_an_empty_workspace_is_not_dragged() {
            button.entry = { id: 3, focused: false, mainApp: null, secondApp: null, windows: [] }
            drag(80, 0)
            compare(button.starts, 0)
            compare(button.clicks, 0)
        }
    }
}
