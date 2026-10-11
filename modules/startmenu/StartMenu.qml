pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.design
import qs.services
import '../../services/startMenu.js' as StartMenuList

// The start menu, opened by the orb at the bar's left end. Laid out like the Windows 7 one, read from the
// search field upwards for a bar at the bottom: on the left a white pane with "Featured" and the featured
// apps right above the search field, the dark line, then "Most used" and every other app above it (most
// used first, then A to Z); on the right, on the glass, the user's places and the shut down button.
//
// It takes the keyboard while open (typing goes to the search) and closes on Escape, on a click outside,
// and once something was started. An app can also be dragged out of it and dropped on a workspace, to
// start it there; where a drop goes is the bar's decision, as for windows (`Bar.dropTarget`).
PopupWindow {
    id: root

    property bool shown: false
    // The bar's screen, and where this window's top-left is in the bar's coordinates (its bottom-left
    // corner sits on the anchor), for the ghost a dragged app leaves behind.
    property var barScreen: null
    readonly property point barOffset: Qt.point(anchor.rect.x, anchor.rect.y - height)
    // Hyprland draws the bar's popups above every layer, the drop layer too, so over the menu the drop
    // layer's picture of a dragged app and its ghost would be hidden. The menu draws them itself, in the same
    // places: the bar gives where the pointer is (bar coordinates), whether it is known yet, and whether a
    // drop now would put the app back.
    property point dragPointer: Qt.point(0, 0)
    property bool dragPointerShown: false
    property bool puttingBack: false
    // An app is being dragged out of this menu.
    readonly property bool dragFromHere: BarDrag.appId !== '' && BarDrag.originScreen === barScreen

    readonly property int menuWidth: 440
    readonly property int menuHeight: 560
    readonly property int leftWidth: 272
    readonly property var rows: {
        if (search.text.trim() !== '') {
            return StartMenuList.searchRows(StartMenuList.searchApps(Apps.list, search.text, Apps.scores))
        }

        return StartMenuList.menuRows(StartMenuList.buildSections(Apps.list, Apps.scores, Apps.featured))
    }
    // What the confirmation dialog would do: 'powerOff', 'reboot' or 'logOut' ('' when none).
    property string pendingPower: ''
    // The app whose context menu is open.
    property var menuApp: null
    // The menu open over the content: 'app' or 'power'.
    property string menuKind: ''
    // What the power menu's rows do, in its order.
    readonly property var powerActions: ['reboot', 'suspend', 'lock', 'logOut']

    implicitWidth: menuWidth
    implicitHeight: menuHeight
    color: 'transparent'
    grabFocus: true
    visible: false
    // While an app is dragged out the menu stays open, with a ghost where the app was, and lets the pointer
    // through so the drop layer gets the drop: anywhere on the menu puts the app back. It closes only once
    // the app was started somewhere (the bar closes it then).
    mask: Region {
        item: BarDrag.active ? null : content
    }
    // Hyprland dismisses the popup (its focus grab) when a drag out of it ends, a put back included. A
    // dismissal during a drag from here, or within `regrabWindow` after one, shows the menu again as it was:
    // no reset, no fade.
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
            reset()
            visible = true
            return
        }

        visible = false
    }

    onVisibleChanged: {
        if (visible) {
            search.input.forceActiveFocus()
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

        StartMenuState.close()
    }

    // A search starts on its best result; back without one, nothing is current and the list is back at
    // the bottom.
    onRowsChanged: {
        if (search.text.trim() !== '') {
            list.selectFirst()
            return
        }

        list.selected = -1
        list.scrollToBottom()
    }

    function reset(): void {
        search.text = ''
        list.selected = -1
        list.scrollToBottom()
        contextMenu.close()
        dialog.open = false
        pendingPower = ''
        menuTooltip.shown = false
    }

    function launch(app: var, actionIndex: int): void {
        Apps.launch(app.id, actionIndex)
        StartMenuState.close()
    }

    function openAppMenu(app: var, at: point): void {
        menuApp = app
        menuKind = 'app'
        const items = [{ text: qsTr('Open'), enabled: true }]
        for (const name of app.actions) {
            items.push({ text: name, enabled: true })
        }

        items.push({ separator: true })
        items.push({ text: Apps.isFeatured(app.id) ? qsTr('Remove from Featured') : qsTr('Add to Featured'), enabled: true })
        items.push({ text: qsTr('Forget usage'), enabled: Apps.scores[app.id] !== undefined })
        contextMenu.items = items
        contextMenu.at = at
        contextMenu.above = false
        contextMenu.current = -1
        contextMenu.open = true
    }

    function appMenuChosen(index: int): void {
        const app = menuApp
        const actionCount = app.actions.length
        if (index <= actionCount) {
            launch(app, index - 1)
            return
        }

        // After the actions: the separator, then featuring, then forgetting.
        if (index === actionCount + 2) {
            Apps.setFeatured(app.id, Apps.isFeatured(app.id) === false)
            return
        }

        if (index === actionCount + 3) {
            Apps.forget(app.id)
        }
    }

    function openPowerMenu(at: point): void {
        menuKind = 'power'
        contextMenu.items = [
            { text: qsTr('Restart'), enabled: true },
            { text: qsTr('Sleep'), enabled: true },
            { text: qsTr('Lock'), enabled: true },
            { text: qsTr('Log out'), enabled: true },
        ]
        // Above the arrow, ending at its right edge (`at`).
        contextMenu.at = at
        contextMenu.above = true
        contextMenu.current = -1
        contextMenu.open = true
    }

    // Leaving the session closes every app, so it is asked first; sleeping and locking keep everything.
    function requestPower(action: string): void {
        if (action === 'suspend' || action === 'lock') {
            StartMenuState.close()
            if (action === 'suspend') {
                Session.suspend()
            } else {
                Session.lock()
            }

            return
        }

        pendingPower = action
        dialog.open = true
    }

    function confirmPower(): void {
        const action = pendingPower
        pendingPower = ''
        StartMenuState.close()
        if (action === 'powerOff') {
            Session.powerOff()
        } else if (action === 'reboot') {
            Session.reboot()
        } else if (action === 'logOut') {
            Session.logOut()
        }
    }

    function handleKey(event: var): void {
        if (contextMenu.open) {
            if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                contextMenu.step(event.key === Qt.Key_Up ? -1 : 1)
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                contextMenu.choose(contextMenu.current)
            } else if (event.key === Qt.Key_Escape) {
                contextMenu.close()
            } else {
                return
            }

            event.accepted = true
            return
        }

        if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            list.move(event.key === Qt.Key_Up ? -1 : 1)
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            const app = list.selectedApp()
            if (app !== null) {
                launch(app, -1)
            }
        } else if (event.key === Qt.Key_Menu) {
            const app = list.selectedApp()
            if (app !== null) {
                openAppMenu(app, Qt.point(Theme.space5, list.height / 2))
            }
        } else if (event.key === Qt.Key_Escape) {
            // A search is cleared first; an empty one closes the menu.
            if (search.text !== '') {
                search.text = ''
            } else {
                StartMenuState.close()
            }
        } else {
            return
        }

        event.accepted = true
    }

    Item {
        id: content

        anchors.fill: parent
        opacity: root.visible || root.reshowing ? 1 : 0

        Behavior on opacity {
            enabled: root.reshowing === false

            NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
        }

        GlassPanel {
            anchors.fill: parent
            cornerRadius: Theme.radiusPanel
        }

        // The white pane with the apps.
        Rectangle {
            id: pane

            x: Theme.space2
            y: Theme.space2
            width: root.leftWidth
            height: search.y - Theme.space2 - y
            radius: Theme.radiusControl
            color: Theme.surface
            border.width: 1
            border.color: Theme.surfaceBorder

            AppList {
                id: list

                anchors.fill: parent
                anchors.topMargin: 1
                anchors.bottomMargin: 1
                rows: root.rows
                tooltip: menuTooltip
                screen: root.barScreen
                windowOffset: root.barOffset
                returnArea: content
                touchControls: Config.startMenu.touchControls
                onLaunched: app => root.launch(app, -1)
                onMenuRequested: (app, at) => root.openAppMenu(app, list.mapToItem(content, at))
            }
        }

        SearchField {
            id: search

            x: Theme.space2
            y: parent.height - height - Theme.space2
            width: root.leftWidth
            placeholder: qsTr('Search apps')
            onKeyPressed: event => root.handleKey(event)
        }

        PlacesColumn {
            x: pane.x + pane.width + Theme.space2
            y: Theme.space3
            width: parent.width - x - Theme.space2
            height: parent.height - y - Theme.space2
            tooltip: menuTooltip
            onOpened: StartMenuState.close()
            onPowerRequested: action => root.requestPower(action)
            onPowerMenuRequested: at => root.openPowerMenu(mapToItem(content, at))
        }

        MenuPanel {
            id: contextMenu

            anchors.fill: parent
            onChosen: index => {
                if (root.menuKind === 'app') {
                    root.appMenuChosen(index)
                    return
                }

                root.requestPower(root.powerActions[index])
            }
            onOpenChanged: {
                if (open === false) {
                    search.input.forceActiveFocus()
                }
            }
        }

        TaskDialog {
            id: dialog

            anchors.fill: parent
            heading: {
                if (root.pendingPower === 'reboot') {
                    return qsTr('Restart the computer?')
                }

                if (root.pendingPower === 'logOut') {
                    return qsTr('Log out?')
                }

                return qsTr('Shut down the computer?')
            }
            text: qsTr('Open apps will be closed. Work that is not saved may be lost.')
            actionText: {
                if (root.pendingPower === 'reboot') {
                    return qsTr('Restart')
                }

                if (root.pendingPower === 'logOut') {
                    return qsTr('Log out')
                }

                return qsTr('Shut down')
            }
            actionKind: 'danger'
            picture: Component {
                PowerIcon {
                    size: 32
                }
            }
            onAccepted: root.confirmPower()
            onCancelled: {
                root.pendingPower = ''
                search.input.forceActiveFocus()
            }
        }

        Tooltip {
            id: menuTooltip
        }

        // The ghost over the dragged app's empty row, as the drop layer draws it elsewhere.
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

        // The dragged app under the pointer while it is over the menu; past the menu's edge the drop
        // layer's copy goes on in the same place.
        Image {
            x: root.dragPointer.x - root.barOffset.x - BarDrag.hotSpot.x
            y: root.dragPointer.y - root.barOffset.y - BarDrag.hotSpot.y
            width: BarDrag.pictureSize.width
            height: BarDrag.pictureSize.height
            source: root.dragFromHere && BarDrag.picture !== null ? BarDrag.picture.url : ''
            visible: root.dragFromHere && root.dragPointerShown
            opacity: Theme.dragImageOpacity
            smooth: true
        }
    }
}
