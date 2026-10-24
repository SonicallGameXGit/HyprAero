import QtQuick
import QtTest
import qs.design

// The Aero scrollbar (the real design/ScrollBar.qml) on a plain list: shown only while the list is longer
// than its view, the thumb follows the list, dragging it scrolls, and a press on the track pages.
Item {
    id: root

    width: 300
    height: 300

    ListView {
        id: list

        width: 200
        height: 200
        model: 20

        delegate: Item {
            width: 200
            height: 40
        }
    }

    ScrollBar {
        id: bar

        view: list
        x: 200
        height: 200
    }

    TestCase {
        name: 'ScrollBar'
        when: windowShown

        function init() {
            list.model = 20
            list.contentY = list.originY
        }

        function test_shown_only_while_the_list_is_longer_than_its_view() {
            compare(bar.visible, true)
            // 20 rows of 40 in 200: a quarter is shown.
            compare(bar.thumbHeight, 50)
            list.model = 3
            tryCompare(bar, 'visible', false)
        }

        function test_the_thumb_follows_the_list() {
            compare(bar.thumbY, 0)
            list.positionViewAtEnd()
            tryCompare(bar, 'thumbY', bar.travel)
        }

        function test_dragging_the_thumb_scrolls() {
            mousePress(bar, bar.width / 2, 10)
            mouseMove(bar, bar.width / 2, 10 + bar.travel / 2)
            mouseRelease(bar, bar.width / 2, 10 + bar.travel / 2)
            fuzzyCompare(list.contentY - list.originY, bar.scrollRange / 2, 1)
            // Past the end it stops at the end.
            mousePress(bar, bar.width / 2, bar.thumbY + 10)
            mouseMove(bar, bar.width / 2, bar.height + 50)
            mouseRelease(bar, bar.width / 2, bar.height + 50)
            fuzzyCompare(list.contentY - list.originY, bar.scrollRange, 1)
        }

        function test_a_press_on_the_track_pages_towards_it() {
            mouseClick(bar, bar.width / 2, bar.height - 5)
            compare(bar.thumbY, bar.thumbHeight)
            mouseClick(bar, bar.width / 2, 5)
            compare(bar.thumbY, 0)
        }
    }
}
