import QtQuick
import QtTest
import qs.design

// The family menu with what apps' tray menus need: a submenu row asks for its submenu and keeps the menu
// open, an ordinary row is chosen and closes it, a greyed row does nothing, the panel is as wide as its
// longest row, and the keyboard skips separators and greyed rows.
Item {
    id: root

    width: 400
    height: 400

    MenuPanel {
        id: menu

        anchors.fill: parent
        at: Qt.point(10, 10)
        items: [
            { text: 'Open' },
            { separator: true },
            { text: 'Greyed', enabled: false },
            { text: 'Enable Wi-Fi', check: 'box', checked: true },
            { text: 'Not ticked', check: 'box', checked: false },
            { text: 'Available networks', submenu: true },
        ]
    }

    SignalSpy {
        id: chosenSpy

        target: menu
        signalName: 'chosen'
    }

    SignalSpy {
        id: submenuSpy

        target: menu
        signalName: 'submenuRequested'
    }

    TestCase {
        name: 'MenuPanel'
        when: windowShown

        function row(index) {
            const rect = menu.rowRect(index)
            return Qt.point(rect.x + rect.width / 2, rect.y + rect.height / 2)
        }

        function visibleChild(item, typeName) {
            for (const child of item.children) {
                if (child.visible && child.toString().startsWith(typeName)) {
                    return true
                }
            }

            return false
        }

        function init() {
            menu.open = true
            menu.current = -1
            chosenSpy.clear()
            submenuSpy.clear()
            wait(0)
        }

        function test_a_submenu_row_asks_for_its_submenu_and_stays_open() {
            const point = row(5)
            mouseClick(menu, point.x, point.y)
            compare(submenuSpy.count, 1)
            compare(submenuSpy.signalArguments[0][0], 5)
            compare(chosenSpy.count, 0)
            compare(menu.open, true)
            compare(menu.current, 5)
        }

        function test_an_ordinary_row_is_chosen_and_closes_the_menu() {
            const point = row(3)
            mouseClick(menu, point.x, point.y)
            compare(chosenSpy.count, 1)
            compare(chosenSpy.signalArguments[0][0], 3)
            compare(menu.open, false)
        }

        function test_a_greyed_row_does_nothing() {
            const point = row(2)
            mouseClick(menu, point.x, point.y)
            compare(chosenSpy.count, 0)
            compare(menu.open, true)
        }

        function test_rows_are_stacked_and_a_submenu_can_open_beside_its_row() {
            const first = menu.rowRect(0)
            const last = menu.rowRect(5)
            verify(last.y > first.y)
            compare(last.x, first.x)
            verify(last.width > 0)
            compare(menu.rowRect(42), Qt.rect(0, 0, 0, 0))
        }

        function test_the_panel_is_as_wide_as_its_widest_row() {
            const narrow = menu.panelWidth
            menu.items = menu.items.concat([{ text: 'Connect to a Hidden Wi-Fi Network with a very long name…' }])
            verify(menu.panelWidth > narrow)
            const last = menu.rowRect(menu.items.length - 1)
            verify(last.width >= 300)
            menu.items = menu.items.slice(0, -1)
            compare(menu.panelWidth, narrow)
        }

        function test_the_keyboard_skips_separators_and_greyed_rows() {
            menu.step(1)
            compare(menu.current, 0)
            menu.step(1)
            compare(menu.current, 3)
            menu.step(-1)
            compare(menu.current, 0)
        }
    }
}
