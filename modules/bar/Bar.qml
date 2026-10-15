import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.design
import qs.modules.startmenu
import qs.modules.tray
import qs.services
import '../../services/workspaceList.js' as WorkspaceList

// One bar per screen, at the bottom edge like the Windows 7 taskbar.
PanelWindow {
    id: root

    WlrLayershell.namespace: 'hypraero-bar'
    // Never the keyboard's, except for a moment at startup (`takingKeyboard`).
    WlrLayershell.keyboardFocus: takingKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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
    // back, or over the pins, no button lights up; a tray icon never goes to a workspace.
    readonly property int dropTarget: dropLayer.hovered && dropLayer.puttingBack === false && BarDrag.trayKey === '' && onPins(dropLayer.pointer) === false
        ? dropWorkspaceAt(dropLayer.pointer)
        : 0
    // The drop layer's pointer in bar coordinates: the bar runs along the layer's bottom edge.
    readonly property point dragPointer: Qt.point(dropLayer.pointer.x, dropLayer.pointer.y - dropLayer.height + root.height)
    // Where among the tray's icons on the bar a tray icon dragged over this screen would go if dropped now
    // (-1: not over them); the tray shows a mark there.
    readonly property int trayGap: dropLayer.hovered && dropLayer.puttingBack === false && BarDrag.trayKey !== '' && onTrayIcons(dragPointer)
        ? trayArea.gapAt(dragPointer.x)
        : -1
    // A tray icon dragged over the arrow opens the flyout, to be dropped in it.
    readonly property bool trayDragOverArrow: dropLayer.hovered && BarDrag.trayKey !== '' && overTrayArrow(dragPointer)
    // The window or the pinned app whose right-click menu is open (null: none).
    property var menuWindow: null
    property var menuApp: null
    // The tray icon whose app menu is open.
    property string trayMenuKey: ''
    // The icon-only control the pointer rests on (a pin, a tray icon, the tray's arrow), for its tooltip;
    // the same in the tray's flyout. Each has a `tooltipText`.
    property Item hoveredTip: null
    property Item hoveredFlyoutTip: null
    // How many workspace buttons there are. It holds still during a drag: rebuilding the buttons would
    // destroy the one a workspace drag started from.
    property int buttonCount: 0
    // Qt gives a popup that takes the keyboard (the start menu) only to a program that has had some input,
    // and closes it at once otherwise: opened by a key binding (IPC) right after the shell started, the
    // menu was gone as soon as it opened. So at startup the first screen's bar takes the keyboard for a
    // moment, which is input, and gives it back as soon as it has it (or after `keyboardTimer`). Not when
    // the menu opens: giving it back then raced with the menu's own grab and closed the menu at random
    // (Hyprland moves the keyboard off a layer and its popups once the layer stops taking it).
    property bool takingKeyboard: Quickshell.screens.length > 0 && root.screen === Quickshell.screens[0]

    Binding on buttonCount {
        value: Workspaces.entries.length
        when: BarDrag.active === false
        restoreMode: Binding.RestoreNone
    }

    implicitHeight: 48
    color: 'transparent'

    onTrayDragOverArrowChanged: {
        if (trayDragOverArrow) {
            Tray.openFlyout(root.screen.name, true)
        }
    }

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

    // Whether a point in bar coordinates is on the bar over the tray's arrow, or over its icons (and the gap
    // right of them).
    function overTrayArrow(point: point): bool {
        if (trayArea.arrowShown === false || point.y < 0) {
            return false
        }

        const left = trayArea.mapToItem(null, 0, 0).x
        return point.x >= left && point.x <= left + trayArea.arrow.width
    }

    function onTrayIcons(point: point): bool {
        if (point.y < 0) {
            return false
        }

        const left = trayArea.mapToItem(null, 0, 0).x + (trayArea.arrowShown ? trayArea.arrow.width : 0)
        return point.x > left && point.x <= trayArea.mapToItem(null, 0, 0).x + trayArea.width + Theme.space2
    }

    // A tray icon let go of at `point` (bar coordinates): into the flyout (hidden there), on the arrow (hidden,
    // last), on the bar's icons (always shown there); anywhere else nothing changes.
    function dropTrayIcon(point: point): void {
        const key = BarDrag.trayKey
        if (trayFlyout.contains(point)) {
            const mark = trayFlyout.gapAt(point)
            Tray.place(key, false, trayFlyout.keys, mark === null ? 0 : mark.gap)
        } else if (overTrayArrow(point)) {
            Tray.place(key, false, trayFlyout.keys, trayFlyout.keys.length)
        } else if (onTrayIcons(point)) {
            Tray.place(key, true, trayArea.keys, trayArea.gapAt(point.x))
        }
    }

    function openTrayMenu(item: var, at: point): void {
        if (item === null || item.hasMenu === false) {
            return
        }

        trayMenuKey = Tray.keyOf(item)
        trayMenu.show(item.menu, at)
    }

    // Straight from one control to the next, the tooltip still shown: through none, so it starts over
    // (fades out, waits, is placed again) instead of naming this control over the other.
    function tipHovered(control: Item, hovered: bool): void {
        if (hovered) {
            hoveredTip = null
            hoveredTip = control
        } else if (hoveredTip === control) {
            hoveredTip = null
        }
    }

    function flyoutTipHovered(control: Item, hovered: bool): void {
        if (hovered) {
            hoveredFlyoutTip = null
            hoveredFlyoutTip = control
        } else if (hoveredFlyoutTip === control) {
            hoveredFlyoutTip = null
        }
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

    // The bar's own menu, from a right click on its empty glass. For now only the way to the tray's
    // "Customize" page, a second way besides the flyout's link.
    function openBarOwnMenu(at: point): void {
        menuWindow = null
        menuApp = null
        barMenu.show([
            { text: qsTr('Customize notification icons...'), action: 'customizeTray' },
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
        } else if (item.action === 'customizeTray') {
            Tray.openCustomize()
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

    // Hyprland may not give the bar the keyboard (a lock screen or another layer holding it): the bar never
    // keeps it.
    Timer {
        id: keyboardTimer

        interval: 300
        running: root.takingKeyboard
        onTriggered: root.takingKeyboard = false
    }

    Item {
        Window.onActiveChanged: {
            if (Window.active && root.takingKeyboard) {
                root.takingKeyboard = false
            }
        }
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

            if (BarDrag.trayKey !== '') {
                root.dropTrayIcon(root.dragPointer)
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

    // The orb's popup starts at the bar's left end, centred on the bar's height, so its lower part lies past
    // the screen's bottom edge. Hyprland must not slide it back up: that would lift the orb off the bar's
    // middle and show the popup's bottom edge cutting it.
    StartButton {
        id: startButton

        anchor.window: root
        anchor.rect: Qt.rect(0, (root.height - height) / 2, width, height)
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.adjustment: PopupAdjustment.None
        barHeight: root.height
        menuOpen: StartMenuState.openScreen === root.screen.name
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
        target: root.hoveredTip
        // The arrow's "Show hidden icons" is not said while they are shown.
        shown: root.hoveredTip !== null
            && BarDrag.active === false
            && barMenu.visible === false
            && trayMenu.visible === false
            && (root.hoveredTip !== trayArea.arrow || trayFlyout.visible === false)
        text: root.hoveredTip === null ? '' : root.hoveredTip.tooltipText
    }

    TrayMenu {
        id: trayMenu

        anchor.window: root
    }

    TrayFlyout {
        id: trayFlyout

        anchor.window: root
        // It closes once nothing is left in it, unless a tray icon is being dragged (it can be dropped in).
        shown: Tray.flyoutScreen === root.screen.name && (Tray.hidden.length > 0 || BarDrag.trayKey !== '')
        byDrag: Tray.flyoutByDrag
        barScreen: root.screen
        barWidth: root.width
        // The bar's glass panel starts 2px left of the bar.
        arrowX: trayArea.x - 2 + trayArea.arrow.x + trayArea.arrow.width / 2
        dragPointer: root.dragPointer
        dragPointerShown: dropLayer.hovered && dropLayer.pointerKnown
        puttingBack: dropLayer.puttingBack
        onTipHovered: (control, hovered) => root.flyoutTipHovered(control, hovered)
    }

    BarTooltip {
        anchor.window: trayFlyout
        overTarget: true
        target: root.hoveredFlyoutTip
        shown: root.hoveredFlyoutTip !== null && trayFlyout.visible && BarDrag.active === false
        text: root.hoveredFlyoutTip === null ? '' : root.hoveredFlyoutTip.tooltipText
    }

    // Grows up and to the right from the bar's left end, its bottom on the top of the orb, as in Vista.
    StartMenu {
        anchor.window: root
        anchor.rect: Qt.rect(0, -2 - startButton.rise, 1, 1)
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Top | Edges.Right
        shown: StartMenuState.openScreen === root.screen.name
        barScreen: root.screen
        dragPointer: root.dragPointer
        dragPointerShown: dropLayer.hovered && dropLayer.pointerKnown
        puttingBack: dropLayer.puttingBack
    }

    // Its left and right borders lie just off the screen, so the bar reads as running on past both edges.
    GlassPanel {
        x: -2
        width: parent.width + 4
        height: parent.height

        // Under everything on the bar, so it only gets right clicks on the empty glass (the controls keep
        // theirs). Not on the workspace buttons either: there it would read as a menu of the workspace.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: mouse => {
                const onWorkspaces = strip.contains(mapToItem(strip, mouse.x, mouse.y))
                if (onWorkspaces === false) {
                    root.openBarOwnMenu(mapToItem(null, mouse.x, mouse.y))
                }
            }
        }

        // Right of the orb's corner (the orb takes the pointer there).
        PinBar {
            id: pinBar

            x: 2 + startButton.barWidth + Theme.space1
            anchors.verticalCenter: parent.verticalCenter
            screen: root.screen
            gap: root.pinGap
            menuApp: barMenu.visible && root.menuApp !== null ? root.menuApp.id : ''
            onMenuRequested: (app, at) => root.openPinMenu(app, pinBar.mapToItem(null, at))
            onPinHovered: (pin, hovered) => root.tipHovered(pin, hovered)
        }

        // Left of the "Show desktop" strip, as on Windows 7 (the clock will go between them).
        TrayArea {
            id: trayArea

            anchors.right: emptyButton.left
            anchors.rightMargin: Theme.space2
            anchors.verticalCenter: parent.verticalCenter
            width: implicitWidth
            screen: root.screen
            gap: root.trayGap
            flyoutOpen: trayFlyout.visible
            menuKey: trayMenu.visible ? root.trayMenuKey : ''
            onArrowClicked: Tray.toggleFlyout(root.screen.name)
            onCustomizeClicked: Tray.openCustomize()
            onMenuRequested: (item, at) => root.openTrayMenu(item, trayArea.mapToItem(null, at))
            onTipHovered: (control, hovered) => root.tipHovered(control, hovered)
        }

        // Inside the top and bottom glass borders and flush with the screen's right edge (the panel's right
        // border is off the screen), like Windows 7's "Show desktop".
        EmptyWorkspaceButton {
            id: emptyButton

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
