import QtQuick
import QtTest
import qs.design
import qs.services
import '../../modules/bar'

// A workspace button (the real WorkspaceButton and TaskbarButton): a click switches, a sideways drag of one
// with windows asks the bar to reorder (started, moved by the offset along the bar, ended) and never clicks;
// an up-and-down drag or an empty workspace starts nothing. A right click asks for its menu. A workspace with
// an icon of its own shows only that, whatever its windows, and empty it stays a plain (not open) button.
// One whose window asks for attention flashes orange `bar.attentionFlashes` times, then stays orange until the
// window no longer asks; asking again starts the flashing over.
Item {
    id: root

    width: 300
    height: 100

    WorkspaceButton {
        id: button

        property int clicks: 0
        property int menus: 0
        property int starts: 0
        property int ends: 0
        property real lastOffset: 0

        x: 100
        y: 20
        width: 72
        height: 48
        entry: ({ id: 2, focused: false, mainApp: 'kitty', secondApp: null, windows: [{ address: '0x1', appId: 'kitty' }] })
        onClicked: clicks++
        onMenuRequested: menus++
        onReorderStarted: starts++
        onReorderMoved: offset => lastOffset = offset
        onReorderEnded: ends++
    }

    TestCase {
        name: 'WorkspaceButton'
        when: windowShown

        function init() {
            IconOverrides.workspaceIcons = {}
            Config.bar = { attentionFlashes: 7 }
            button.clicks = 0
            button.menus = 0
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

        function test_a_right_click_asks_for_the_menu_and_does_not_switch() {
            mouseClick(button, 36, 24, Qt.RightButton)
            compare(button.menus, 1)
            compare(button.clicks, 0)
        }

        function test_an_own_icon_wins_over_the_windows() {
            button.entry = { id: 2, focused: false, mainApp: 'kitty', secondApp: 'firefox', windows: [{ address: '0x1', appId: 'kitty' }, { address: '0x2', appId: 'firefox' }] }
            IconOverrides.workspaceIcons = { 2: 'file:///icons/star.png' }
            compare(button.mainPath, 'file:///icons/star.png')
            compare(button.secondPath, '')
            compare(button.iconSource, 'file:///icons/star.png')
            verify(button.open)
        }

        function test_an_empty_workspace_with_its_own_icon_is_not_an_open_button() {
            button.entry = { id: 3, focused: false, mainApp: null, secondApp: null, windows: [] }
            compare(button.mainPath, '')
            IconOverrides.workspaceIcons = { 3: 'file:///icons/star.png' }
            compare(button.mainPath, 'file:///icons/star.png')
            compare(button.open, false)
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

        function asking() {
            return { id: 2, focused: false, mainApp: 'kitty', secondApp: null, attention: true, windows: [{ address: '0x1', appId: 'kitty', urgent: true }] }
        }

        function test_a_window_asking_for_attention_flashes_the_button_then_keeps_it_orange() {
            Config.bar = { attentionFlashes: 2 }
            button.entry = asking()
            verify(button.attention)
            verify(button.attentionShown)
            tryCompare(button, 'attentionShown', false, 1000)
            tryCompare(button, 'attentionShown', true, 1000)
            wait(Theme.taskbarItemFlashInterval * 2)
            verify(button.attentionShown)
            Config.bar = { attentionFlashes: 7 }
        }

        function test_the_orange_goes_once_the_window_no_longer_asks() {
            button.entry = asking()
            verify(button.attentionShown)
            button.entry = { id: 2, focused: false, mainApp: 'kitty', secondApp: null, attention: false, windows: [{ address: '0x1', appId: 'kitty', urgent: false }] }
            compare(button.attention, false)
            compare(button.attentionShown, false)
        }

        function test_asking_again_starts_the_flashing_over() {
            Config.bar = { attentionFlashes: 1 }
            button.entry = asking()
            verify(button.attentionShown)
            Config.bar = { attentionFlashes: 3 }
            button.flashStep = 4
            Workspaces.attentionRequested('0x9')
            compare(button.flashStep, 4)
            Workspaces.attentionRequested('0x1')
            compare(button.flashStep, 0)
            tryCompare(button, 'attentionShown', false, 1000)
            Config.bar = { attentionFlashes: 7 }
        }

        function test_an_empty_workspace_is_not_dragged() {
            button.entry = { id: 3, focused: false, mainApp: null, secondApp: null, windows: [] }
            drag(80, 0)
            compare(button.starts, 0)
            compare(button.clicks, 0)
        }
    }
}
