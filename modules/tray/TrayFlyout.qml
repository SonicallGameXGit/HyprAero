pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Effects
import qs.design
import qs.services
import '../../services/tray.js' as TrayList

// The flyout of the "Show hidden icons" arrow, after Windows 7's: the icons that wait behind the arrow in a
// grid as square as it can be, on glass, and "Customize..." under them (the "Notification Area Icons"
// page). It sits above the arrow and takes the keyboard; Escape, a click outside or the arrow close it, and
// so does using an icon (its app takes over, as on Windows).
//
// An icon can be dragged out of it onto the bar's icons (always shown from then on), and a tray icon
// dragged over the arrow opens it, to be dropped in it (hidden from then on); where a drop goes is the
// bar's decision. While something is dragged the flyout lets the pointer through to the drop layer, and
// draws the dragged icon, its ghost and the drop mark itself: Hyprland draws the bar's popups above every
// layer, so the drop layer's would be hidden under it.
PopupWindow {
    id: root

    property bool shown: false
    // Opened by a drag over the arrow: no keyboard (a popup cannot take it during a drag), and it closes
    // with the drag (`Tray`).
    property bool byDrag: false
    // The bar's screen and width, and the middle of the arrow in the bar's coordinates.
    property var barScreen: null
    property real barWidth: 0
    property real arrowX: 0
    // Where this window's top-left is in the bar's coordinates.
    readonly property point barOffset: Qt.point(anchor.rect.x, anchor.rect.y - height)
    // The drop layer's pointer in the bar's coordinates, whether it is known yet, and whether a drop now
    // would put the dragged icon back.
    property point dragPointer: Qt.point(0, 0)
    property bool dragPointerShown: false
    property bool puttingBack: false
    // An icon is being dragged out of this flyout.
    readonly property bool dragFromHere: BarDrag.from === 'trayFlyout' && BarDrag.originScreen === barScreen
    // A tray icon dragged over this flyout: where it would go if dropped now (`TrayList.gridGapAt`).
    readonly property var dropMark: BarDrag.trayKey !== '' && dragPointerShown && puttingBack === false && contains(dragPointer)
        ? gapAt(dragPointer)
        : null
    // The icons shown. They hold still during a drag: rebuilding them would destroy the one a drag started
    // from.
    property var items: []
    readonly property var keys: items.map(item => Tray.keyOf(item))

    readonly property int cell: 32
    readonly property int columns: TrayList.gridColumns(items.length)
    readonly property int rows: Math.max(1, Math.ceil(items.length / columns))
    // The icon whose menu is open stays lit.
    property string menuKey: ''

    signal tipHovered(Item control, bool hovered)

    // Whether a point in the bar's coordinates is on this flyout.
    function contains(barPoint: point): bool {
        return visible
            && barPoint.x >= barOffset.x
            && barPoint.x <= barOffset.x + width
            && barPoint.y >= barOffset.y
            && barPoint.y <= barOffset.y + height
    }

    // The gap of the grid closest to a point in the bar's coordinates, and its mark there; null while the
    // grid is empty (a drop then goes first).
    function gapAt(barPoint: point): var {
        const slots = []
        for (let index = 0; index < icons.count; index++) {
            const icon = icons.itemAt(index)
            if (icon !== null) {
                const place = icon.mapToItem(null, 0, 0)
                const left = place.x + barOffset.x
                const top = place.y + barOffset.y
                slots.push({ left: left, top: top, right: left + icon.width, bottom: top + icon.height })
            }
        }

        return TrayList.gridGapAt(barPoint.x, barPoint.y, slots)
    }

    function openMenu(item: var, at: point): void {
        if (item === null || item.hasMenu === false) {
            return
        }

        menuKey = Tray.keyOf(item)
        menu.show(item.menu, at)
    }

    Binding on items {
        value: Tray.hidden
        when: BarDrag.active === false
        restoreMode: Binding.RestoreNone
    }

    // Above the arrow, centred on it and kept on the bar (so on the screen); placed here and not slid by
    // the compositor, so `barOffset` is where it really is.
    anchor.rect: Qt.rect(Math.max(2, Math.min(arrowX - width / 2, barWidth - width - 2)), -Theme.space1, 1, 1)
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Top | Edges.Right
    anchor.adjustment: PopupAdjustment.None
    implicitWidth: Math.max(columns * cell, link.implicitWidth + Theme.space3 * 2) + Theme.space2 * 2
    implicitHeight: rows * cell + Theme.space2 * 2 + strip.height + Theme.space1
    color: 'transparent'
    grabFocus: byDrag === false
    visible: false
    mask: Region {
        item: BarDrag.active ? null : content
    }
    // Hyprland dismisses the popup (its focus grab) when a drag out of it ends, a put back included. A
    // dismissal during a drag from here, or within `regrabWindow` after one, shows it again as it was.
    property real dragEndedAt: 0
    readonly property int regrabWindow: 500
    property bool reshowing: false

    onDragFromHereChanged: {
        if (dragFromHere === false) {
            dragEndedAt = Date.now()
        }
    }

    // `visible` is set here and not bound: the popup also hides itself on a click outside.
    onShownChanged: {
        if (shown) {
            menuKey = ''
            visible = true
            return
        }

        menu.close()
        visible = false
    }

    onVisibleChanged: {
        if (visible) {
            keyHandler.forceActiveFocus()
            reshowing = false
            return
        }

        if (shown && (dragFromHere || Date.now() - dragEndedAt < regrabWindow)) {
            reshowing = true
            Qt.callLater(() => {
                if (root.shown) {
                    root.visible = true
                }
            })
            return
        }

        Tray.closeFlyout()
    }

    Item {
        id: content

        anchors.fill: parent
        opacity: root.visible || root.reshowing ? 1 : 0

        Behavior on opacity {
            enabled: root.reshowing === false

            NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
        }

        Item {
            id: keyHandler

            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Tray.closeFlyout()
        }

        GlassPanel {
            anchors.fill: parent
            cornerRadius: Theme.radiusPanel
        }

        Grid {
            id: grid

            x: (parent.width - width) / 2
            y: Theme.space2
            columns: root.columns

            Repeater {
                id: icons

                model: root.items

                TrayIcon {
                    id: icon

                    required property var modelData

                    item: modelData
                    screen: root.barScreen
                    from: 'trayFlyout'
                    windowOffset: root.barOffset
                    width: root.cell
                    height: root.cell
                    highlighted: menu.visible && root.menuKey === icon.key
                    onActivated: Tray.closeFlyout()
                    onMenuRequested: at => root.openMenu(icon.modelData, icon.mapToItem(null, at))
                    onHoveredChanged: root.tipHovered(icon, icon.hovered)
                }
            }
        }

        // Solid under the link, so its words read on any backdrop.
        Rectangle {
            id: strip

            x: Theme.space1
            y: parent.height - height - Theme.space1
            width: parent.width - Theme.space1 * 2
            height: link.implicitHeight + Theme.space2 * 2
            radius: Theme.radiusControl
            color: Theme.surfaceSunken
            border.width: 1
            border.color: Theme.surfaceBorder

            LinkText {
                id: link

                anchors.centerIn: parent
                text: qsTr('Customize...')
                activeFocusOnTab: true
                onClicked: Tray.openCustomize()
            }
        }

        // The mark where a dragged icon would go, glowing like a focused control.
        Item {
            x: root.dropMark === null ? grid.x + grid.width / 2 - 1 : root.dropMark.x - root.barOffset.x - 1
            y: root.dropMark === null ? grid.y + Theme.space1 : root.dropMark.top - root.barOffset.y + Theme.space1
            width: 2
            height: root.cell - Theme.space1 * 2
            visible: BarDrag.trayKey !== '' && root.dragPointerShown && root.puttingBack === false && root.contains(root.dragPointer)

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

        // The ghost over the dragged icon's empty place, as the drop layer draws it elsewhere.
        DropZone {
            x: BarDrag.originRect.x - root.barOffset.x
            y: BarDrag.originRect.y - root.barOffset.y
            width: BarDrag.originRect.width
            height: BarDrag.originRect.height
            visible: root.dragFromHere
            lit: root.puttingBack
            text: qsTr('Put back')
            Accessible.name: qsTr('Put back')
        }

        // The dragged icon under the pointer while it is over the flyout; past its edge the drop layer's copy
        // goes on in the same place.
        Image {
            x: root.dragPointer.x - root.barOffset.x - BarDrag.hotSpot.x
            y: root.dragPointer.y - root.barOffset.y - BarDrag.hotSpot.y
            width: BarDrag.pictureSize.width
            height: BarDrag.pictureSize.height
            source: BarDrag.trayKey !== '' && BarDrag.picture !== null ? BarDrag.picture.url : ''
            visible: BarDrag.trayKey !== '' && root.dragPointerShown && root.contains(root.dragPointer)
            opacity: Theme.dragImageOpacity
            smooth: true
        }
    }

    TrayMenu {
        id: menu

        anchor.window: root
        // Something was done: the app takes over, as after a click.
        onChosen: Tray.closeFlyout()
    }
}
