import QtQuick
import QtTest
import qs.design
import qs.services
import '../../modules/bar'

// The workspace buttons reordered by dragging one along the bar, as Windows 7 does (the real WorkspaceStrip
// and WorkspaceButton, a fake Workspaces): the held button follows the pointer sideways, the others make room,
// it stops dead at the limits, and let go it goes to its slot (past the ends the first or the last) and the
// reorder is asked of Hyprland. Covering a third of another button for a moment it joins it instead: that
// one lights up, and let go its windows are asked to go there; passing over it does not. Until the entries have caught up the buttons keep what
// they showed.
Item {
    id: root

    // Four workspaces, one window each: button pitch 75, 72 wide.
    function entriesOf(addresses) {
        return addresses.map((address, index) => ({
            id: index + 1,
            focused: index === 0,
            mainApp: address === '' ? null : 'app',
            secondApp: null,
            windows: address === '' ? [] : [{ address: address, appId: 'app' }],
        }))
    }

    width: 600
    height: 100

    WorkspaceStrip {
        id: strip

        property int began: 0

        x: 100
        height: 48
        buttonCount: 4
        // Room for half a button past the strip on the left, none on the right.
        leftLimit: 64
        rightLimit: strip.x + strip.width
        onReorderBegan: began++
    }

    TestCase {
        name: 'WorkspaceStrip'
        when: windowShown

        function init() {
            Workspaces.entries = root.entriesOf(['0xa', '0xb', '0xc', '0xd'])
            Workspaces.reordered = null
            Workspaces.joined = null
            Workspaces.switchedTo = 0
            strip.began = 0
            tryVerify(() => strip.reordering === false, 3000)
        }

        // Presses the button in slot `slot` and moves it `dx` sideways, `steps` moves; not let go.
        function hold(slot, dx) {
            const x = slot * strip.pitch + 36
            mousePress(strip, x, 24)
            for (let step = 1; step <= 10; step++) {
                mouseMove(strip, x + dx * step / 10, 24)
                wait(10)
            }
            return x + dx
        }

        function test_a_click_switches_and_reorders_nothing() {
            mouseClick(strip, 75 + 36, 24)
            compare(Workspaces.switchedTo, 2)
            compare(strip.began, 0)
            compare(Workspaces.reordered, null)
        }

        // Its middle past the middle of button 2 (186) and out of its joining part: they trade.
        function test_held_it_follows_the_pointer_and_the_others_make_room() {
            const at = hold(0, 170)
            compare(strip.began, 1)
            verify(strip.reordering)
            // Over slot 2: buttons 1 and 2 have moved one slot left, 3 stays.
            compare(strip.dragTo, 2)
            compare(strip.joinTarget, -1)
            compare(strip.buttonAt(0).x, 170)
            tryCompare(strip.buttonAt(1), 'x', 0)
            tryCompare(strip.buttonAt(2), 'x', 75)
            compare(strip.buttonAt(3).x, 225)
            mouseRelease(strip, at, 24)
        }

        function test_let_go_it_goes_to_its_slot_and_hyprland_is_asked() {
            const at = hold(0, 170)
            mouseRelease(strip, at, 24)
            tryCompare(strip.buttonAt(0), 'x', 150)
            compare(Workspaces.reordered.from, 0)
            compare(Workspaces.reordered.to, 2)
            compare(Workspaces.reordered.ids, [1, 2, 3, 4])
            compare(Workspaces.joined, null)
            // Still what it showed, though the entries say nothing yet.
            compare(strip.buttonAt(0).entry.windows[0].address, '0xa')
            verify(strip.reordering)
        }

        function test_once_hyprland_has_caught_up_the_live_entries_show_in_order() {
            const at = hold(0, 170)
            mouseRelease(strip, at, 24)
            wait(300)
            // Half done: not yet.
            Workspaces.entries = root.entriesOf(['', '0xb', '0xc', '0xd'])
            verify(strip.reordering)
            Workspaces.entries = root.entriesOf(['0xb', '0xc', '0xa', '0xd'])
            compare(strip.reordering, false)
            // Each button in its own slot again, showing the new order, at once.
            compare(strip.buttonAt(0).x, 0)
            compare(strip.buttonAt(2).x, 150)
            compare(strip.buttonAt(2).entry.windows[0].address, '0xa')
        }

        function test_it_stops_dead_at_the_limits() {
            // Far left: the limit is 36 left of the strip.
            let at = hold(1, -400)
            compare(strip.buttonAt(1).x, -36)
            mouseRelease(strip, at, 24)
            tryVerify(() => strip.reordering === false, 3000)
            Workspaces.reordered = null
            // Far right: the last slot is as far as it goes.
            at = hold(1, 400)
            compare(strip.buttonAt(1).x, 225)
            mouseRelease(strip, at, 24)
        }

        function test_past_the_end_it_falls_into_the_first_slot() {
            const at = hold(2, -400)
            mouseRelease(strip, at, 24)
            compare(Workspaces.reordered.to, 0)
            tryCompare(strip.buttonAt(2), 'x', 0)
        }

        function test_dropped_where_it_was_nothing_is_asked() {
            const at = hold(1, 20)
            mouseRelease(strip, at, 24)
            compare(Workspaces.reordered, null)
            tryVerify(() => strip.reordering === false, 1000)
        }

        function test_hyprland_not_answering_still_ends_it() {
            const at = hold(0, 170)
            mouseRelease(strip, at, 24)
            tryVerify(() => strip.reordering === false, strip.catchUpLimit + 1000)
        }

        // 30 to the right it covers 27 of button 1 (75 to 147), still nearer its own slot; resting there.
        function test_covering_a_third_of_another_for_a_moment_would_join_it() {
            const at = hold(0, 30)
            compare(strip.joinTarget, -1)
            tryCompare(strip, 'joinTarget', 1, strip.joinDelay + 500)
            compare(strip.dragTo, 0)
            verify(strip.buttonAt(1).highlighted)
            // Button 1 stays where it is, and the held one turns see-through over it.
            compare(strip.buttonAt(1).x, 75)
            tryCompare(strip.buttonAt(0), 'opacity', Theme.dragImageOpacity)
            mouseRelease(strip, at, 24)
        }

        function test_let_go_there_its_windows_go_to_that_workspace() {
            const at = hold(0, 30)
            tryCompare(strip, 'joinTarget', 1, strip.joinDelay + 500)
            mouseRelease(strip, at, 24)
            compare(Workspaces.joined.from, 1)
            compare(Workspaces.joined.to, 2)
            compare(Workspaces.reordered, null)
            // It fades into the joined one while waiting.
            tryCompare(strip.buttonAt(0), 'x', 75)
            tryCompare(strip.buttonAt(0), 'opacity', 0)
            verify(strip.reordering)
            // Hyprland has moved the windows: back to the live entries, each button in its own slot.
            Workspaces.entries = root.entriesOf(['', '0xa', '0xc', '0xd'])
            compare(strip.reordering, false)
            compare(strip.buttonAt(0).x, 0)
            compare(strip.buttonAt(0).entry.windows.length, 0)
            tryCompare(strip.buttonAt(0), 'opacity', 1)
        }

        // Past button 1 first (they trade), then back onto it where it now stands: joined from the other side.
        function test_a_button_that_made_room_can_still_be_joined() {
            mousePress(strip, 36, 24)
            for (let x = 36; x <= 140; x += 8) {
                mouseMove(strip, x, 24)
                wait(10)
            }
            compare(strip.dragTo, 1)
            // Button 1 now stands in slot 0 (0 to 72): back over a third of it (held at 40), resting, joins.
            for (let x = 140; x >= 76; x -= 4) {
                mouseMove(strip, x, 24)
                wait(10)
            }
            compare(strip.dragTo, 1)
            tryCompare(strip, 'joinTarget', 1, strip.joinDelay + 500)
            mouseRelease(strip, 76, 24)
            compare(Workspaces.joined.to, 2)
            // The one that had made room glides back to its own slot.
            tryCompare(strip.buttonAt(1), 'x', 75)
        }

        function test_moving_on_reorders_instead() {
            const at = hold(0, 30)
            tryCompare(strip, 'joinTarget', 1, strip.joinDelay + 500)
            mouseMove(strip, at + 30, 24)
            compare(strip.joinTarget, -1)
            compare(strip.dragTo, 1)
            verify(strip.buttonAt(1).highlighted === false)
            mouseRelease(strip, at + 30, 24)
            compare(Workspaces.joined, null)
            compare(Workspaces.reordered.to, 1)
        }

        // Over a third of button 1 and let go before the wait is over: nothing joined, nothing moved.
        function test_passing_by_does_not_join() {
            const at = hold(0, 30)
            mouseRelease(strip, at, 24)
            compare(Workspaces.joined, null)
            compare(Workspaces.reordered, null)
        }

        // Moving on while still covering it keeps the wait going; uncovering it ends the wait.
        function test_the_wait_ends_when_the_pointer_moves_away() {
            const at = hold(0, 28)
            mouseMove(strip, at + 4, 24)
            mouseMove(strip, at - 30, 24)
            wait(strip.joinDelay + 200)
            compare(strip.joinTarget, -1)
            mouseRelease(strip, at - 30, 24)
        }
    }
}
