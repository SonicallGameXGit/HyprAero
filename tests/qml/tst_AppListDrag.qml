import QtQuick
import QtTest
import qs.services
import '../../modules/startmenu'

// The start menu's app list (the real AppList and AppRow), long enough to scroll, read from the top.
//
// Touch controls off: dragging an app picks it up at once and the list never scrolls by dragging (not on a
// row, not between rows); the wheel and the scrollbar scroll it. On: dragging scrolls the list, and holding
// an app picks it up. A click starts the app either way, and the scrollbar can be dragged in both. An app
// with actions opens them under it with its arrow; a click on one starts that action, and the keyboard
// walks through them.
Item {
    id: root

    width: 300
    height: 300

    AppList {
        id: list

        property int launches: 0
        property int lastAction: -2

        anchors.fill: parent
        windowOffset: Qt.point(0, -600)
        returnArea: root
        // From the top: app0 to app3 (42px each), a header (26px), then app4 to app29; app1 has two actions.
        rows: {
            const rows = []
            for (let index = 0; index < 30; index++) {
                // A header between apps, high enough to be on screen: something to drag that is not an app.
                if (index === 4) {
                    rows.push({ kind: 'header', section: 'used' })
                }

                rows.push({
                    kind: 'app',
                    section: 'used',
                    app: {
                        id: 'app' + index,
                        name: 'App ' + index,
                        comment: '',
                        command: ['app' + index],
                        icon: '',
                        actions: index === 1 ? ['New Window', 'New Private Window'] : [],
                    },
                })
            }

            return rows
        }
        onLaunched: (app, actionIndex) => {
            launches++
            lastAction = actionIndex
        }
    }

    TestCase {
        name: 'AppListDrag'
        when: windowShown

        // The ListView inside the list.
        function view() {
            for (const child of list.children) {
                if (child.contentY !== undefined && child.model !== undefined) {
                    return child
                }
            }

            return null
        }

        function dragFrom(x, y, dx, dy) {
            mousePress(list, x, y)
            for (let step = 1; step <= 10; step++) {
                mouseMove(list, x + dx * step / 10, y + dy * step / 10)
                wait(10)
            }
            mouseRelease(list, x + dx, y + dy)
        }

        function init() {
            list.touchControls = false
            list.launches = 0
            list.lastAction = -2
            list.expanded = []
            list.select(-1)
            view().positionViewAtBeginning()
            BarDrag.begins = 0
            BarDrag.begunAppId = ''
        }

        function test_a_click_starts_the_app() {
            mouseClick(list, 150, 250)
            compare(list.launches, 1)
            compare(list.lastAction, -1)
            compare(BarDrag.begins, 0)
        }

        function test_dragging_an_app_picks_it_up_and_the_list_stays_still() {
            const before = view().contentY
            // Up, the way that would scroll the list toward its lower rows.
            dragFrom(150, 250, 10, -80)
            compare(BarDrag.begins, 1)
            compare(view().contentY, before)
            compare(list.launches, 0)
            // Dropping anywhere on the menu puts it back: the return area is the menu, not the row.
            compare(BarDrag.begunReturn, Qt.rect(0, -600, 300, 300))
            verify(BarDrag.begunOrigin.height < 100)
        }

        // On Wayland the compositor keeps the release that ends a drag: the row never sees it.
        function dragWithoutRelease(x, y, dx, dy) {
            mousePress(list, x, y)
            for (let step = 1; step <= 10; step++) {
                mouseMove(list, x + dx * step / 10, y + dy * step / 10)
                wait(10)
            }
        }

        function test_an_app_can_be_picked_up_again_after_a_drop_the_row_never_saw() {
            dragWithoutRelease(150, 250, 10, 40)
            compare(BarDrag.begins, 1)
            dragWithoutRelease(150, 250, 10, 40)
            compare(BarDrag.begins, 2)
            mouseRelease(list, 160, 290)
            mouseClick(list, 150, 250)
            compare(list.launches, 1)
        }

        // The press that started the last drag was never released (the compositor kept it): another app must
        // still take the next press, not the row that was dragged before.
        function test_another_app_can_be_picked_up_after_a_drop_the_row_never_saw() {
            dragWithoutRelease(150, 250, 10, 40)
            compare(BarDrag.begunAppId, 'app5')
            // One row up (42px).
            dragWithoutRelease(150, 208, 10, 40)
            compare(BarDrag.begins, 2)
            compare(BarDrag.begunAppId, 'app4')
            mouseRelease(list, 160, 248)
        }

        // The menu stays open after a drag, so the same row must be ready for the next one.
        function test_an_app_can_be_picked_up_again() {
            dragFrom(150, 250, 10, 40)
            compare(BarDrag.begins, 1)
            dragFrom(150, 250, 10, 40)
            compare(BarDrag.begins, 2)
            mouseClick(list, 150, 250)
            compare(list.launches, 1)
        }

        function test_touch_controls_an_app_can_be_held_again() {
            list.touchControls = true
            for (let time = 1; time <= 2; time++) {
                mousePress(list, 150, 250)
                tryCompare(BarDrag, 'begins', time, 1000)
                mouseRelease(list, 150, 250)
            }
            mouseClick(list, 150, 250)
            compare(list.launches, 1)
        }

        function test_dragging_between_apps_does_not_scroll_either() {
            const before = view().contentY
            // From the header between app3 and app4, up.
            dragFrom(150, 175, 0, -120)
            compare(view().contentY, before)
        }

        function test_a_long_press_without_touch_controls_still_starts_the_app() {
            mousePress(list, 150, 250)
            wait(600)
            mouseRelease(list, 150, 250)
            compare(list.launches, 1)
            compare(BarDrag.begins, 0)
        }

        // Over the list the view turns each notch into a short glide of its own, which a test cannot time
        // exactly, so a few notches are turned, as a hand does.
        function test_the_wheel_scrolls() {
            const before = view().contentY
            for (let notch = 0; notch < 3; notch++) {
                mouseWheel(list, 150, 100, 0, -120)
                wait(50)
            }
            tryVerify(() => view().contentY !== before)
        }

        // Over the scrollbar strip the wheel is passed on by hand, a notch's worth at once.
        function test_the_wheel_scrolls_over_the_scrollbar_too() {
            const before = view().contentY
            mouseWheel(list, 296, 100, 0, -120)
            compare(view().contentY, before + 120)
        }

        function test_the_scrollbar_can_be_dragged_to_the_bottom() {
            // At the top of the list, so the thumb is at the top of the bar at the right edge.
            mousePress(list, 296, 10)
            for (let step = 1; step <= 10; step++) {
                mouseMove(list, 296, 10 + step * 40)
            }
            mouseRelease(list, 296, 299)
            // The last row is shown (the view settles its height estimate once the rows are built).
            tryVerify(() => view().atYEnd)
            verify(view().itemAtIndex(view().count - 1) !== null)
            // Held, the thumb keeps the press: the rows scrolling under it never pick an app up.
            compare(BarDrag.begins, 0)
            compare(list.launches, 0)
        }

        // The scrollbar strip at the right edge, and its thumb.
        function scrollBar() {
            for (const child of list.children) {
                if (child.thumbHeight !== undefined) {
                    return child
                }
            }

            return null
        }

        function thumb() {
            return scrollBar().children[0]
        }

        // Held, the thumb keeps its size and stays under the pointer the whole way, also when the pointer
        // wanders off the strip over the apps; nothing is picked up or started.
        function test_a_held_thumb_keeps_its_size_and_stays_under_the_pointer() {
            const height = thumb().height
            mousePress(list, 296, 10)
            const offset = 10 - thumb().y
            for (let step = 1; step <= 12; step++) {
                const y = 10 + step * 15
                // Drifting left over the rows as it goes down.
                mouseMove(list, 296 - step * 12, y)
                wait(10)
                compare(thumb().height, height)
                compare(thumb().y, Math.min(y - offset, scrollBar().height - height))
            }
            mouseRelease(list, 150, 190)
            compare(BarDrag.begins, 0)
            compare(list.launches, 0)
            verify(view().contentY > 0)
        }

        // The rows stop where the scrollbar starts, so a press on it never reaches an app.
        function test_the_rows_do_not_reach_under_the_scrollbar() {
            verify(view().width <= scrollBar().x)
            mouseClick(list, 296, 250)
            compare(list.launches, 0)
        }

        function test_pressing_beside_the_thumb_brings_it_there() {
            const before = view().contentY
            mouseClick(list, 296, 290)
            verify(view().contentY > before)
        }

        function test_touch_controls_dragging_scrolls_the_list_instead() {
            list.touchControls = true
            const before = view().contentY
            dragFrom(150, 250, 0, -120)
            compare(BarDrag.begins, 0)
            verify(view().contentY !== before)
            compare(list.launches, 0)
        }

        function test_touch_controls_holding_an_app_picks_it_up() {
            list.touchControls = true
            mousePress(list, 150, 250)
            tryCompare(BarDrag, 'begins', 1, 1000)
            compare(BarDrag.begunAppId, 'app5')
            mouseRelease(list, 150, 250)
            compare(list.launches, 0)
        }

        function test_touch_controls_a_click_starts_the_app() {
            list.touchControls = true
            mouseClick(list, 150, 250)
            compare(list.launches, 1)
        }

        // The arrow at the right end of app1 (42 to 84), left of the scrollbar.
        function test_the_arrow_opens_the_actions_and_a_click_on_one_starts_it() {
            mouseClick(list, 270, 63)
            verify(list.isExpanded('app1'))
            compare(list.launches, 0)
            // The first action right under app1, once the branch has slid open (26px each).
            wait(300)
            mouseClick(list, 150, 84 + 13)
            compare(list.launches, 1)
            compare(list.lastAction, 0)
            // The second one, and the app itself still starts plainly.
            mouseClick(list, 150, 84 + 26 + 13)
            compare(list.lastAction, 1)
            mouseClick(list, 150, 63)
            compare(list.lastAction, -1)
        }

        function test_the_arrow_closes_them_again() {
            mouseClick(list, 270, 63)
            mouseClick(list, 270, 63)
            verify(list.isExpanded('app1') === false)
            // What was under the actions is back right under app1.
            wait(300)
            mouseClick(list, 150, 84 + 13)
            compare(list.lastAction, -1)
        }

        function test_an_app_without_actions_has_no_arrow() {
            mouseClick(list, 270, 21)
            verify(list.isExpanded('app0') === false)
            compare(list.launches, 1)
        }

        function test_the_keyboard_walks_through_the_actions() {
            list.select(1)
            list.expandSelected(1)
            list.move(1)
            compare(list.selected, 1)
            compare(list.selectedAction, 0)
            list.move(1)
            compare(list.selectedAction, 1)
            list.move(1)
            compare(list.selected, 2)
            compare(list.selectedAction, -1)
            // Back up lands on the last action, the row right above.
            list.move(-1)
            compare(list.selected, 1)
            compare(list.selectedAction, 1)
            list.move(-1)
            list.move(-1)
            compare(list.selectedAction, -1)
            list.move(-1)
            compare(list.selected, 0)
        }

        function test_closing_an_app_on_one_of_its_actions_goes_back_to_the_app() {
            list.select(1)
            list.expandSelected(1)
            list.move(1)
            list.expandSelected(0)
            compare(list.selected, 1)
            compare(list.selectedAction, -1)
        }
    }
}
