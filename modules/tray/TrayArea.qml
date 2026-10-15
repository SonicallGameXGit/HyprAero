pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.design
import qs.services
import '../../services/pins.js' as PinList

// The notification area on the bar, after Windows 7's: the "Show hidden icons" arrow, then the icons
// that are always shown (and those asking for attention). While nothing is hidden the arrow stays, turned to
// point at the icons, and opens the "Customize" page instead of the (empty) flyout, so the way to hide icons
// again never disappears; with no icon ever seen there is nothing to customise and it shows only while a
// tray icon is dragged (to be dropped on it and hidden). A tray icon dragged over the icons shows a glowing
// mark where it would go (`gap`); where a drop goes is the bar's decision.
Item {
    id: root

    // The bar's screen, for the ghost a dragged icon leaves.
    property var screen: null
    // Where a drop would put it: the gap before icon `gap` (the number of icons: after the last), -1: none.
    property int gap: -1
    // The flyout of this bar is open: the arrow stays lit.
    property bool flyoutOpen: false
    // The icon whose menu is open stays lit.
    property string menuKey: ''
    // The icons shown. They hold still during a drag: rebuilding them would destroy the one a drag started
    // from.
    property var items: []

    readonly property bool arrowShown: Tray.icons.length > 0 || BarDrag.trayKey !== ''
    // Some icons wait in the flyout (or one is dragged, which can be hidden there): the arrow points up.
    readonly property bool anyHidden: Tray.hidden.length > 0 || BarDrag.trayKey !== ''
    readonly property Item arrow: arrowButton
    readonly property var keys: items.map(item => Tray.keyOf(item))
    readonly property int iconWidth: 24
    readonly property int iconHeight: 40

    signal arrowClicked()
    // The turned arrow was clicked.
    signal customizeClicked()
    // `at` is in this item.
    signal menuRequested(var item, point at)
    signal tipHovered(Item control, bool hovered)

    // The gap closest to `x` (in the bar window's coordinates).
    function gapAt(x: real): int {
        const slots = []
        for (let index = 0; index < icons.count; index++) {
            const icon = icons.itemAt(index)
            if (icon !== null) {
                const left = icon.mapToItem(null, 0, 0).x
                slots.push({ left: left, right: left + icon.width })
            }
        }

        return PinList.gapAt(x, slots)
    }

    Binding on items {
        value: Tray.shown
        when: BarDrag.active === false
        restoreMode: Binding.RestoreNone
    }

    implicitWidth: row.x + row.width
    implicitHeight: iconHeight

    ControlButton {
        id: arrowButton

        readonly property string tooltipText: root.anyHidden ? qsTr('Show hidden icons') : qsTr('Customize notification icons')

        kind: 'glassTool'
        visible: root.arrowShown
        width: 18
        height: root.iconHeight
        current: root.flyoutOpen
        Accessible.name: tooltipText
        onClicked: {
            if (root.anyHidden) {
                root.arrowClicked()
            } else {
                root.customizeClicked()
            }
        }
        onHoveredChanged: root.tipHovered(arrowButton, hovered)

        ChevronGlyph {
            anchors.centerIn: parent
            rotation: root.anyHidden ? -90 : 0
            color: Theme.taskbarGlassText

            Behavior on rotation {
                NumberAnimation {
                    duration: Theme.motionSoft
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    Row {
        id: row

        x: root.arrowShown ? arrowButton.width : 0
        // With nothing shown, one icon's room while a tray icon is dragged, so there is a place to drop it.
        width: Math.max(implicitWidth, BarDrag.trayKey !== '' ? root.iconWidth : 0)
        height: root.iconHeight

        Repeater {
            id: icons

            model: root.items

            TrayIcon {
                id: icon

                required property var modelData

                item: modelData
                screen: root.screen
                from: 'tray'
                width: root.iconWidth
                height: root.iconHeight
                current: root.menuKey !== '' && root.menuKey === icon.key
                onMenuRequested: at => root.menuRequested(icon.modelData, icon.mapToItem(root, at))
                onHoveredChanged: root.tipHovered(icon, icon.hovered)
            }
        }
    }

    // The mark between two icons, glowing like a focused control.
    Item {
        readonly property real gapX: {
            if (icons.count === 0) {
                return row.width / 2
            }

            const after = icons.itemAt(Math.min(root.gap, icons.count - 1))
            if (after === null) {
                return 0
            }

            return root.gap < icons.count ? after.x : after.x + after.width
        }

        x: row.x + gapX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: root.iconHeight - Theme.space1 * 2
        visible: root.gap >= 0

        RectangularShadow {
            anchors.fill: parent
            blur: Theme.focusGlowBlur
            spread: Theme.focusGlowSpread
            color: Theme.focusGlowColor
        }

        Rectangle {
            anchors.fill: parent
            radius: 1
            color: Theme.focusGlowRing
        }
    }
}
