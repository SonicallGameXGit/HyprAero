import QtQuick
import QtTest
import qs.design

// The small controls of a settings page: a check box says its new state and leaves `checked` to the owner,
// a drop-down box asks for its list, a link follows on a click and on the keyboard.
Item {
    id: root

    width: 400
    height: 200

    CheckBox {
        id: check

        y: 10
        text: 'Always show all icons'
        onToggled: on => check.checked = on
    }

    ChoiceBox {
        id: choice

        y: 50
        width: 200
        choice: 'Only show notifications'
    }

    LinkText {
        id: link

        y: 100
        text: 'Restore default icon behaviors'
    }

    SignalSpy {
        id: listSpy

        target: choice
        signalName: 'listRequested'
    }

    SignalSpy {
        id: linkSpy

        target: link
        signalName: 'clicked'
    }

    TestCase {
        name: 'FormControls'
        when: windowShown

        function init() {
            check.checked = false
            listSpy.clear()
            linkSpy.clear()
        }

        function test_a_click_on_the_box_or_its_words_turns_it_over() {
            mouseClick(check, 5, check.height / 2)
            compare(check.checked, true)
            mouseClick(check, check.width - 5, check.height / 2)
            compare(check.checked, false)
            compare(check.activeFocus, true)
            keyClick(Qt.Key_Space)
            compare(check.checked, true)
        }

        function test_the_box_asks_for_its_list_on_a_click_and_on_the_keyboard() {
            mouseClick(choice)
            compare(listSpy.count, 1)
            compare(choice.activeFocus, true)
            keyClick(Qt.Key_Down)
            keyClick(Qt.Key_Return)
            compare(listSpy.count, 3)
        }

        function test_a_disabled_box_asks_for_nothing() {
            choice.enabled = false
            mouseClick(choice)
            compare(listSpy.count, 0)
            choice.enabled = true
        }

        function test_a_link_follows_on_a_click_and_on_enter() {
            mouseClick(link)
            compare(linkSpy.count, 1)
            link.forceActiveFocus()
            keyClick(Qt.Key_Return)
            compare(linkSpy.count, 2)
        }
    }
}
