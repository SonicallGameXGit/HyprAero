import QtQuick
import QtTest
import qs.services
import '../../modules/startmenu'

// The start menu's app list (the real AppList and AppRow), long enough to scroll.
//
// Touch controls off: dragging an app picks it up at once and the list never scrolls by dragging (not on a
// row, not between rows); the wheel and the scrollbar scroll it. On: dragging scrolls the list, and holding
// an app picks it up. A click starts the app either way, and the scrollbar can be dragged in both.
Item {
    id: root

    width: 300
    height: 300

    AppList {
        id: list

        property int launches: 0

        anchors.fill: parent
        windowOffset: Qt.point(0, -600)
        returnArea: root
        rows: {
            const rows = []
            for (let index = 0; index < 30; index++) {
                // A header between apps, low enough to be on screen: something to drag that is not an app.
                if (index === 28) {
                    rows.push({ kind: 'header', section: 'featured' })
                }

                rows.push({
                    kind: 'app',
                    section: 'others',
                    app: { id: 'app' + index, name: 'App ' + index, comment: '', command: ['app' + index], icon: '', actions: [] },
                })
            }

            rows.push({ kind: 'header', section: 'others' })
            return rows
        }
        onLaunched: launches++
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
            view().positionViewAtBeginning()
            BarDrag.begins = 0
            BarDrag.begunAppId = ''
        }

        function test_a_click_starts_the_app() {
            mouseClick(list, 150, 250)
            compare(list.launches, 1)
            compare(BarDrag.begins, 0)
        }

        function test_dragging_an_app_picks_it_up_and_the_list_stays_still() {
            const before = view().contentY
            // Down toward the bar, the way that would scroll the list toward its upper rows.
            dragFrom(150, 20, 10, 80)
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
            compare(BarDrag.begunAppId, 'app29')
            // One row up (42px).
            dragWithoutRelease(150, 208, 10, 40)
            compare(BarDrag.begins, 2)
            compare(BarDrag.begunAppId, 'app28')
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
            // From the bottom: the header (26px), two apps (42px each), the header in between.
            dragFrom(150, 175, 0, 120)
            compare(view().contentY, before)
        }

        function test_a_long_press_without_touch_controls_still_starts_the_app() {
            mousePress(list, 150, 250)
            wait(600)
            mouseRelease(list, 150, 250)
            compare(list.launches, 1)
            compare(BarDrag.begins, 0)
        }

        function test_the_wheel_scrolls() {
            const before = view().contentY
            mouseWheel(list, 150, 100, 0, 120)
            tryVerify(() => view().contentY !== before)
        }

        function test_the_scrollbar_can_be_dragged_to_the_top() {
            // At the bottom of the list, so the thumb is at the bottom of the bar at the right edge.
            mousePress(list, 296, 290)
            for (let step = 1; step <= 10; step++) {
                mouseMove(list, 296, 290 - step * 40)
            }
            mouseRelease(list, 296, 0)
            fuzzyCompare(view().visibleArea.yPosition, 0, 0.001)
            compare(list.launches, 0)
        }

        function test_pressing_beside_the_thumb_brings_it_there() {
            const before = view().contentY
            mouseClick(list, 296, 10)
            verify(view().contentY < before)
        }

        function test_touch_controls_dragging_scrolls_the_list_instead() {
            list.touchControls = true
            const before = view().contentY
            dragFrom(150, 20, 0, 120)
            compare(BarDrag.begins, 0)
            verify(view().contentY !== before)
            compare(list.launches, 0)
        }

        function test_touch_controls_holding_an_app_picks_it_up() {
            list.touchControls = true
            mousePress(list, 150, 250)
            tryCompare(BarDrag, 'begins', 1, 1000)
            compare(BarDrag.begunAppId, 'app29')
            mouseRelease(list, 150, 250)
            compare(list.launches, 0)
        }

        function test_touch_controls_a_click_starts_the_app() {
            list.touchControls = true
            mouseClick(list, 150, 250)
            compare(list.launches, 1)
        }
    }
}
