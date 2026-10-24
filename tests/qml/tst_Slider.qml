import QtQuick
import QtTest
import qs.design

// The family slider (the volume control): a press brings the thumb to the pointer and a drag follows it,
// the most at the top when vertical; arrows, Page Up / Down, Home and End and the wheel move it by its step;
// it only tells (`moved`), the owner sets the value.
Item {
    id: root

    width: 300
    height: 300

    Slider {
        id: slider

        property real told: -1

        x: 20
        y: 20
        height: 211
        value: 0.5
        onMoved: value => slider.told = value
    }

    Slider {
        id: wide

        property real told: -1

        x: 60
        y: 260
        width: 211
        vertical: false
        value: 0.5
        onMoved: value => wide.told = value
    }

    Slider {
        id: quietOne

        x: 100
        y: 20
        height: 211
        quiet: true
    }

    // A group's name, its first letter underlined when it is the accelerator, the words escaped.
    GroupFrame {
        id: group

        x: 140
        y: 20
        width: 100
        height: 60
        title: 'Device'
        accelerator: true
    }

    TestCase {
        name: 'Slider'
        when: windowShown

        function init() {
            slider.value = 0.5
            slider.told = -1
            wide.told = -1
        }

        function test_a_press_tells_the_value_under_it_top_is_the_most() {
            mousePress(slider, slider.width / 2, 0)
            compare(slider.told, 1)
            mouseMove(slider, slider.width / 2, slider.height - 1)
            compare(slider.told, 0)
            mouseMove(slider, slider.width / 2, slider.height / 2)
            fuzzyCompare(slider.told, 0.5, 0.01)
            mouseRelease(slider, slider.width / 2, slider.height / 2)
            // It only tells: the owner has not set the value.
            compare(slider.value, 0.5)
        }

        function test_horizontal_runs_left_to_right() {
            mouseClick(wide, 0, wide.height / 2)
            compare(wide.told, 0)
            mouseClick(wide, wide.width - 1, wide.height / 2)
            compare(wide.told, 1)
        }

        function test_keys_move_it_by_its_step() {
            slider.forceActiveFocus()
            keyClick(Qt.Key_Up)
            fuzzyCompare(slider.told, 0.52, 0.0001)
            keyClick(Qt.Key_PageDown)
            fuzzyCompare(slider.told, 0.4, 0.0001)
            keyClick(Qt.Key_Home)
            compare(slider.told, 1)
            keyClick(Qt.Key_End)
            compare(slider.told, 0)
        }

        function test_the_wheel_moves_it_and_stays_in_range() {
            mouseWheel(slider, 5, 5, 0, 120)
            fuzzyCompare(slider.told, 0.52, 0.0001)
            slider.value = 0.99
            mouseWheel(slider, 5, 5, 0, 360)
            compare(slider.told, 1)
        }

        function test_a_quiet_slider_is_grey_until_it_has_the_keyboard() {
            verify(quietOne.plain)
            quietOne.forceActiveFocus()
            compare(quietOne.plain, false)
            slider.forceActiveFocus()
            verify(quietOne.plain)
            compare(slider.plain, false)
        }

        function test_a_group_underlines_its_accelerator_and_escapes_its_name() {
            compare(group.markup, '<u>D</u>evice')
            group.accelerator = false
            compare(group.markup, 'Device')
            group.title = 'A <b> & c'
            group.accelerator = true
            compare(group.markup, '<u>A</u> &lt;b&gt; &amp; c')
            group.title = 'Device'
        }
    }
}
