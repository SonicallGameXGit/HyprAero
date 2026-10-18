import QtQuick
import QtTest
import qs.services
import '../../modules/tray'

// The notification area on the bar (the real TrayArea and TrayIcon) against a fake tray: the arrow points
// up while icons wait in the flyout and stays, turned, while none do, then opening the Customize page; a
// click asks the app (the shell's own icons ask for their flyout, or their menu), a right click
// asks for its menu, a middle click and the wheel go to the app, and a dragged icon starts a tray drag that
// knows where it came from.
Item {
    id: root

    width: 300
    height: 100

    TrayArea {
        id: area

        property var lastMenu: null
        property var lastFlyout: null
        property int arrowClicks: 0
        property int customizeClicks: 0

        x: 20
        y: 30
        onMenuRequested: (item, at) => area.lastMenu = { id: item.id, at: at }
        onFlyoutRequested: (name, x) => area.lastFlyout = { name: name, x: x }
        onArrowClicked: area.arrowClicks++
        onCustomizeClicked: area.customizeClicks++
    }

    SignalSpy {
        id: tipSpy

        target: area
        signalName: 'tipHovered'
    }

    TestCase {
        name: 'TrayArea'
        when: windowShown

        readonly property var ids: ['steam', 'menuOnly', 'system:volume', 'system:drives']

        function icon(index) {
            const row = area.children.find(child => child.toString().startsWith('QQuickRow'))
            return row.children.find(child => child.key === ids[index])
        }

        function initTestCase() {
            Tray.icons = [{ key: 'steam' }, { key: 'menuOnly' }, { key: 'system:volume' }, { key: 'system:drives' }]
            Tray.shown = [
                { id: 'steam', title: 'Steam', icon: '', onlyMenu: false, hasMenu: true },
                { id: 'menuOnly', title: 'Only a menu', icon: '', onlyMenu: true, hasMenu: true },
                { id: 'system:volume', title: 'Volume', icon: '', system: 'volume', onlyMenu: false, hasMenu: true },
                { id: 'system:drives', title: 'Safely Remove', icon: '', system: 'drives', onlyMenu: true, hasMenu: true },
            ]
            // The row places its icons on the next polish.
            tryVerify(() => icon(3) !== undefined && icon(3).x > 0)
        }

        function init() {
            Tray.hidden = []
            Tray.activated = []
            Tray.secondary = []
            Tray.scrolled = []
            area.lastMenu = null
            area.lastFlyout = null
            area.arrowClicks = 0
            area.customizeClicks = 0
            BarDrag.begins = 0
            BarDrag.end()
            tipSpy.clear()
        }

        function test_the_arrow_points_up_only_while_icons_wait_behind_it() {
            // Nothing hidden: the arrow stays, turned, and opens the Customize page (the flyout would be empty).
            compare(area.arrowShown, true)
            compare(area.anyHidden, false)
            tryCompare(icon(0).mapToItem(area, 0, 0), 'x', area.arrow.width)
            mouseClick(area.arrow)
            compare(area.customizeClicks, 1)
            compare(area.arrowClicks, 0)
            compare(area.arrow.tooltipText, 'Customize notification icons')
            // Icons hidden: it points up; the icons do not move.
            Tray.hidden = [{ id: 'nm-applet', title: 'Network', icon: '', onlyMenu: false, hasMenu: true }]
            compare(area.anyHidden, true)
            compare(area.arrow.visible, true)
            compare(icon(0).mapToItem(area, 0, 0).x, area.arrow.width)
            mouseClick(area.arrow)
            compare(area.arrowClicks, 1)
            compare(area.customizeClicks, 1)
            compare(area.arrow.tooltipText, 'Show hidden icons')
        }

        function test_with_no_icon_ever_seen_there_is_no_arrow() {
            const icons = Tray.icons
            Tray.icons = []
            compare(area.arrowShown, false)
            Tray.icons = icons
        }

        function test_a_click_asks_the_app_and_a_menu_only_app_opens_its_menu() {
            mouseClick(icon(0))
            compare(Tray.activated, ['steam'])
            mouseClick(icon(1))
            compare(Tray.activated, ['steam'])
            compare(area.lastMenu.id, 'menuOnly')
        }

        function test_a_system_icon_asks_for_its_flyout_or_its_menu_never_the_app() {
            mouseClick(icon(2))
            compare(area.lastFlyout.name, 'volume')
            compare(area.lastFlyout.x, icon(2).mapToItem(area, icon(2).width / 2, 0).x)
            compare(Tray.activated, [])
            mouseClick(icon(3))
            compare(area.lastMenu.id, 'system:drives')
            compare(area.lastFlyout.name, 'volume')
            compare(Tray.activated, [])
        }

        function test_right_click_asks_for_the_menu_where_it_was_pressed() {
            mouseClick(icon(0), 5, 7, Qt.RightButton)
            compare(area.lastMenu.id, 'steam')
            compare(area.lastMenu.at, icon(0).mapToItem(area, 5, 7))
            compare(Tray.activated, [])
        }

        function test_middle_click_and_wheel_go_to_the_app() {
            mouseClick(icon(0), 5, 5, Qt.MiddleButton)
            compare(Tray.secondary, ['steam'])
            mouseWheel(icon(0), 5, 5, 0, -120)
            compare(Tray.scrolled.length, 1)
            compare(Tray.scrolled[0].id, 'steam')
            compare(Tray.scrolled[0].delta, -120)
            compare(Tray.scrolled[0].horizontal, false)
        }

        function test_hovering_an_icon_asks_for_its_tooltip() {
            mouseMove(icon(0), 5, 5)
            tryVerify(() => tipSpy.count > 0)
            compare(tipSpy.signalArguments[0][1], true)
            compare(icon(0).tooltipText, 'Steam')
        }

        function test_the_gap_closest_to_the_pointer() {
            const left = icon(0).mapToItem(null, 0, 0).x
            compare(area.gapAt(left + 2), 0)
            compare(area.gapAt(left + area.iconWidth - 2), 1)
            compare(area.gapAt(left + area.iconWidth * 4 + 30), 4)
        }

        function test_dragging_an_icon_starts_a_tray_drag_from_the_bar() {
            const button = icon(0)
            mousePress(button, 10, 20)
            for (let step = 1; step <= 10; step++) {
                mouseMove(button, 10, 20 - step * 5)
            }
            tryCompare(BarDrag, 'begins', 1)
            compare(BarDrag.begunTrayKey, 'steam')
            compare(BarDrag.begunAppId, '')
            mouseRelease(button, 10, -30)
            compare(Tray.activated, [])
        }
    }
}
