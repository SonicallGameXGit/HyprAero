import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.design
import qs.modules.startmenu
import qs.services
import '../../services/workspaceList.js' as WorkspaceList

// One bar per screen, at the bottom edge like the Windows 7 taskbar.
PanelWindow {
    id: root

    WlrLayershell.namespace: 'hypraero-bar'

    anchors {
        bottom: true
        left: true
        right: true
    }

    // The button whose window list is open. Cleared after a short delay so the pointer can move
    // from the button onto the popup without it closing.
    property var popupButton: null
    // The last hovered button that had windows; the popup keeps showing it while it fades out.
    property var lastButton: null

    // How far above the bar a dragged window still counts as on it (`WorkspaceList.dropWorkspace`), so
    // the bar need not be hit exactly: a little over the buttons, a lot beside them.
    readonly property var dropReach: ({ buttons: 48, sides: 240 })
    // The app of what is dragged, if it can be pinned: an app (from the start menu or a pin), or a window
    // whose app has a desktop entry; '' otherwise (a workspace, a window of an unknown app).
    readonly property string dragApp: {
        if (BarDrag.appId !== '') {
            return BarDrag.appId
        }

        if (BarDrag.address === '') {
            return ''
        }

        const window = Workspaces.windows.find(item => item.address === BarDrag.address)
        return window === undefined ? '' : Apps.appFor(window.appId)
    }
    // Where on the pins an app or a window dragged over this screen would be pinned if dropped now (-1:
    // not over the pins); the pins show a mark there.
    readonly property int pinGap: dropLayer.hovered && dropLayer.puttingBack === false
        ? pinGapAt(dropLayer.pointer)
        : -1
    // The workspace a window (or a workspace's windows, or an app) dragged over this screen would go to if
    // dropped now (0: none); its button lights up so the drop is never a surprise. Where it would be put
    // back, or over the pins, no button lights up.
    readonly property int dropTarget: dropLayer.hovered && dropLayer.puttingBack === false && onPins(dropLayer.pointer) === false
        ? dropWorkspaceAt(dropLayer.pointer)
        : 0
    // The window or the pinned app whose right-click menu is open (null: none).
    property var menuWindow: null
    property var menuApp: null
    // The pin the pointer rests on, for its tooltip.
    property Item hoveredPin: null
    // How many workspace buttons there are. It holds still during a drag: rebuilding the buttons would
    // destroy the one a workspace drag started from.
    property int buttonCount: 0

    Binding on buttonCount {
        value: Workspaces.entries.length
        when: BarDrag.active === false
        restoreMode: Binding.RestoreNone
    }

    implicitHeight: 48
    color: 'transparent'

    // The drop layer covers the whole screen with the bar along its bottom edge, both as wide as the
    // screen, so its x is the bar's x and the bar's top is the layer's height minus the bar's.
    function dropWorkspaceAt(point: point): int {
        const slots = []
        for (let index = 0; index < buttons.count; index++) {
            const button = buttons.itemAt(index)
            if (button === null || button.entry === null) {
                continue
            }

            const left = button.mapToItem(null, 0, 0).x
            slots.push({
                id: button.entry.id,
                left: left,
                right: left + button.width,
                empty: button.entry.windows.length === 0,
            })
        }

        const away = dropLayer.height - root.height - point.y
        return WorkspaceList.dropWorkspace(point.x, away, slots, dropReach)
    }

    // Whether a drop at `point` (drop layer coordinates) belongs to the pins: an app or a window over the
    // pins, on the bar itself. A workspace is never pinned, so the pins are no place for it.
    function onPins(point: point): bool {
        if (BarDrag.appId === '' && BarDrag.address === '') {
            return false
        }

        const left = pinBar.mapToItem(null, 0, 0).x
        const onBar = point.y >= dropLayer.height - root.height
        return onBar && point.x >= left && point.x <= left + pinBar.width
    }

    // The gap of the pins a drop at `point` would pin the dragged app in, -1 when it is not over the pins
    // or cannot be pinned (a window of an app without a desktop entry: nothing happens there).
    function pinGapAt(point: point): int {
        if (onPins(point) === false || dragApp === '') {
            return -1
        }

        return pinBar.gapAt(point.x)
    }

    // A preview card's menu, `at` in the bar's coordinates. Windows 7 bolds what a click does.
    function openWindowMenu(window: var, at: point): void {
        const app = Apps.appFor(window.appId)
        const pinned = Pins.isPinned(app)
        menuApp = null
        menuWindow = window
        barMenu.show([
            { text: qsTr('Focus'), bold: true, action: 'focus' },
            { separator: true },
            { text: qsTr('Fit into layout'), enabled: window.floating, action: 'tile' },
            { text: qsTr('Float freely'), enabled: window.floating === false, action: 'float' },
            { text: pinned ? qsTr('Unpin from bar') : qsTr('Pin to bar'), enabled: app !== '', action: pinned ? 'unpin' : 'pin', app: app },
            { separator: true },
            { text: qsTr('Close'), action: 'close' },
        ], at)
    }

    // A pin's menu: the app, its own actions hanging under it, and unpinning.
    function openPinMenu(app: var, at: point): void {
        const items = [{ text: app.name, bold: true, action: 'open' }]
        for (let index = 0; index < app.actions.length; index++) {
            items.push({ text: app.actions[index], indent: true, action: 'action', index: index })
        }

        items.push({ separator: true })
        items.push({ text: qsTr('Unpin from bar'), action: 'unpin', app: app.id })
        menuWindow = null
        menuApp = app
        barMenu.show(items, at)
    }

    function menuChosen(item: var): void {
        if (item.action === 'focus') {
            Workspaces.focusWindow(menuWindow.address)
            hideTimer.stop()
            root.popupButton = null
        } else if (item.action === 'tile' || item.action === 'float') {
            Workspaces.setFloating(menuWindow.address, item.action === 'float')
        } else if (item.action === 'pin') {
            Pins.pin(item.app)
        } else if (item.action === 'unpin') {
            Pins.unpin(item.app)
        } else if (item.action === 'close') {
            Workspaces.closeWindow(menuWindow.address)
        } else if (item.action === 'open') {
            Apps.launch(menuApp.id, -1)
        } else if (item.action === 'action') {
            Apps.launch(menuApp.id, item.index)
        }
    }

    function buttonHoverChanged(button: var): void {
        if (button.hovered) {
            hideTimer.stop()
            popupButton = button
            if (button.entry.windows.length > 0) {
                lastButton = button
            }

            return
        }

        hideTimer.restart()
    }

    // While a card is dragged the pointer is off the popup, but the popup stays (hidden): the drag started
    // from it. It stays too while a card's menu is open over it.
    Timer {
        id: hideTimer

        interval: 150
        onTriggered: {
            if (popup.dragging || barMenu.visible) {
                return
            }

            root.popupButton = null
        }
    }

    DropLayer {
        id: dropLayer

        screen: root.screen
        barHeight: root.height
        onDropped: {
            // Back where it was taken from: as if it was never taken.
            if (dropLayer.puttingBack) {
                return
            }

            // Pinned there (a pin moves there); a window stays where it is. A start menu it came from stays
            // open: nothing was started.
            if (root.onPins(dropLayer.pointer)) {
                const gap = root.pinGapAt(dropLayer.pointer)
                if (gap >= 0) {
                    Pins.placeAt(root.dragApp, gap)
                }

                return
            }

            const target = root.dropWorkspaceAt(dropLayer.pointer)
            if (target === 0) {
                return
            }

            if (BarDrag.address !== '') {
                Workspaces.moveWindow(BarDrag.address, target)
                return
            }

            if (BarDrag.workspaceId !== 0) {
                Workspaces.moveWorkspace(BarDrag.workspaceId, target)
                return
            }

            // Started, so the menu it came from has done its job, as after a click.
            if (BarDrag.appId !== '') {
                Apps.launchOn(BarDrag.appId, target)
                StartMenuState.close()
            }
        }
    }

    WorkspacePopup {
        id: popup

        // The window spans the whole bar on its top edge and stays put; the panel inside glides.
        anchor.window: root
        anchor.rect: Qt.rect(0, -2, root.width, 1)
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        barScreen: root.screen
        shown: root.popupButton !== null && root.popupButton.entry.windows.length > 0
        workspaceId: root.lastButton === null ? 0 : root.lastButton.entry.id
        windows: root.lastButton === null ? [] : root.lastButton.entry.windows
        centerX: root.lastButton === null ? 0 : root.lastButton.mapToItem(null, root.lastButton.width / 2, 0).x
        onHoverChanged: hovered => {
            if (hovered) {
                hideTimer.stop()
                return
            }

            hideTimer.restart()
        }
        menuAddress: barMenu.visible && root.menuWindow !== null ? root.menuWindow.address : ''
        onWindowChosen: {
            hideTimer.stop()
            root.popupButton = null
        }
        onWindowMenuRequested: (window, at) => root.openWindowMenu(window, at)
        // After a drop the pointer is wherever it was let go; the popup closes unless it is on a button
        // or on the popup again.
        onDraggingChanged: {
            if (dragging === false) {
                hideTimer.restart()
            }
        }
    }

    // The orb's popup has its bottom-left corner on the bar's.
    StartButton {
        id: startButton

        anchor.window: root
        anchor.rect: Qt.rect(0, root.height - height, width, height)
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        barHeight: root.height
        onClicked: StartMenuState.toggle(root.screen.name)
    }

    BarMenu {
        id: barMenu

        anchor.window: root
        onChosen: item => root.menuChosen(item)
        // The previews it was opened over close unless the pointer is back on them.
        onDismissed: hideTimer.restart()
    }

    BarTooltip {
        anchor.window: root
        target: root.hoveredPin
        shown: root.hoveredPin !== null && BarDrag.active === false && barMenu.visible === false
        text: root.hoveredPin === null ? '' : root.hoveredPin.app.name
    }

    // Grows up and to the right from the bar's left end, its bottom on the top of the orb, as in Vista.
    StartMenu {
        anchor.window: root
        anchor.rect: Qt.rect(0, -2 - startButton.rise, 1, 1)
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Top | Edges.Right
        shown: StartMenuState.openScreen === root.screen.name
        barScreen: root.screen
        // The drop layer's pointer in bar coordinates: the bar runs along the layer's bottom edge.
        dragPointer: Qt.point(dropLayer.pointer.x, dropLayer.pointer.y - dropLayer.height + root.height)
        dragPointerShown: dropLayer.hovered && dropLayer.pointerKnown
        puttingBack: dropLayer.puttingBack
    }

    // Its left and right borders lie just off the screen, so the bar reads as running on past both edges.
    GlassPanel {
        x: -2
        width: parent.width + 4
        height: parent.height

        // Right of the orb's corner (the orb takes the pointer there).
        PinBar {
            id: pinBar

            x: 2 + startButton.barWidth + Theme.space1
            anchors.verticalCenter: parent.verticalCenter
            screen: root.screen
            gap: root.pinGap
            menuApp: barMenu.visible && root.menuApp !== null ? root.menuApp.id : ''
            onMenuRequested: (app, at) => root.openPinMenu(app, pinBar.mapToItem(null, at))
            onPinHovered: (pin, hovered) => {
                if (hovered) {
                    root.hoveredPin = pin
                } else if (root.hoveredPin === pin) {
                    root.hoveredPin = null
                }
            }
        }

        // Inside the top and bottom glass borders and flush with the screen's right edge (the panel's right
        // border is off the screen), like Windows 7's "Show desktop".
        EmptyWorkspaceButton {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: 2
            width: implicitWidth
            onClicked: Workspaces.switchToFirstEmpty()
        }

        Item {
            id: strip

            anchors.centerIn: parent
            width: row.width
            height: row.height

            WorkspaceHighlight {
                y: row.y
                height: row.height
                targetX: row.focusedButton === null ? 0 : row.x + row.focusedButton.x
                targetWidth: row.focusedButton === null ? 0 : row.focusedButton.width
            }

            Row {
                id: row

                readonly property var focusedButton: {
                    for (let index = 0; index < buttons.count; index++) {
                        const button = buttons.itemAt(index)
                        if (button !== null && button.entry !== null && button.entry.focused) {
                            return button
                        }
                    }

                    return null
                }

                spacing: Theme.space1

                Repeater {
                    id: buttons

                    // Counting only, so a change inside one entry (an icon) does not rebuild every button.
                    model: root.buttonCount

                    WorkspaceButton {
                        id: button

                        required property int index

                        // The count can lag behind the list during a drag.
                        entry: index < Workspaces.entries.length ? Workspaces.entries[index] : null
                        onClicked: Workspaces.switchTo(entry.id)
                        screen: root.screen
                        highlighted: root.dropTarget === entry.id
                        onHoveredChanged: root.buttonHoverChanged(button)
                    }
                }
            }
        }
    }
}
