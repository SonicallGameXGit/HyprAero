pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.design
import qs.services

// An app's tray menu (its DBus menu), drawn like every other menu of the shell (`MenuPanel`) instead of in
// the app's own toolkit look: ticks, radio dots, icons and submenus included. It opens above-right of the
// pointer and takes the keyboard (Up / Down, Enter, Right opens a submenu, Left or Escape closes one); a
// click anywhere else closes it and every submenu (the compositor ends their grab).
//
// It is a popup of the window the icon is in (the bar or the flyout): a popup that takes the keyboard may
// only sit on such a window or on another such popup. A submenu is another of these, a popup of this one,
// opening beside its row.
PopupWindow {
    id: root

    // Room around the menu for its shadow.
    readonly property int shadowRoom: Theme.menuShadowBlur + Theme.menuShadowOffset
    // The point the menu opens from, in its window's coordinates.
    property point at: Qt.point(0, 0)
    // A submenu opens right of its row (`beside`, in the parent menu's window), going down.
    property bool isSubmenu: false
    property rect beside: Qt.rect(0, 0, 0, 0)
    // Shown once the app has sent the entries: before that the menu's size is not known.
    property bool waiting: false
    // The row whose submenu is open (-1: none).
    property int submenuIndex: -1

    readonly property var entries: opener.children === null ? [] : opener.children.values
    readonly property var items: entries.map(entry => ({
        text: entry.text,
        enabled: entry.enabled,
        separator: entry.isSeparator,
        check: checkKind(entry),
        checked: entry.checkState === Qt.Checked,
        icon: entry.icon,
        submenu: entry.hasChildren,
    }))

    // An entry was chosen: the whole chain of menus closes.
    signal chosen()
    signal dismissed()

    function checkKind(entry: var): string {
        if (entry.buttonType === QsMenuButtonType.CheckBox) {
            return 'box'
        }

        if (entry.buttonType === QsMenuButtonType.RadioButton) {
            return 'radio'
        }

        return ''
    }

    // Opens the menu of `handle` (an item's `menu`, or an entry with children) at `point`. A popup is placed
    // when it is shown, so one still open is closed first.
    function show(handle: var, point: point): void {
        close()
        at = point
        opener.menu = handle
        waiting = true
        waitTimer.restart()
        showIfReady()
    }

    function showIfReady(): void {
        if (waiting === false || entries.length === 0) {
            return
        }

        waiting = false
        waitTimer.stop()
        menu.current = -1
        menu.open = true
        visible = true
    }

    function close(): void {
        waiting = false
        waitTimer.stop()
        closeSubmenu()
        visible = false
    }

    function openSubmenu(index: int): void {
        const entry = entries[index]
        if (entry === undefined || entry.hasChildren === false || entry.enabled === false) {
            return
        }

        if (submenuIndex === index && submenu.item !== null && submenu.item.visible) {
            return
        }

        submenuIndex = index
        submenu.active = true
        const child = submenu.item
        if (child === null) {
            return
        }

        child.anchor.window = root
        child.isSubmenu = true
        child.beside = menu.rowRect(index)
        child.show(entry, Qt.point(0, 0))
    }

    function closeSubmenu(): void {
        submenuIndex = -1
        if (submenu.item !== null) {
            submenu.item.close()
        }
    }

    onEntriesChanged: showIfReady()

    // A menu: its bottom-left corner (the panel's, past the shadow room) on the point. A submenu: its top-left
    // corner beside its row's top-right, the panels just overlapping.
    anchor.rect: isSubmenu
        ? Qt.rect(beside.x + beside.width + 2 - shadowRoom, beside.y - 2 - shadowRoom, 1, 1)
        : Qt.rect(at.x - shadowRoom, at.y + shadowRoom, 1, 1)
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: isSubmenu ? Edges.Bottom | Edges.Right : Edges.Top | Edges.Right
    implicitWidth: menu.panelWidth + shadowRoom * 2
    implicitHeight: menu.panelHeight + shadowRoom * 2
    color: 'transparent'
    grabFocus: true
    visible: false

    onVisibleChanged: {
        if (visible) {
            keyHandler.forceActiveFocus()
            return
        }

        menu.close()
        closeSubmenu()
        // Letting go of the menu tells the app it was closed.
        opener.menu = null
        root.dismissed()
    }

    QsMenuOpener {
        id: opener
    }

    // An app that sends nothing (or an empty menu) gets no menu, rather than an empty box.
    Timer {
        id: waitTimer

        interval: 1000
        onTriggered: {
            root.waiting = false
            opener.menu = null
        }
    }

    // A row with a submenu opens it once the pointer rests on it; moving on to another row closes it.
    Timer {
        id: hoverTimer

        interval: 350
        onTriggered: {
            const item = root.items[menu.current]
            if (item !== undefined && item.submenu) {
                root.openSubmenu(menu.current)
            } else if (root.submenuIndex >= 0) {
                root.closeSubmenu()
            }
        }
    }

    LazyLoader {
        id: submenu

        source: 'TrayMenu.qml'
    }

    Connections {
        target: submenu.item

        function onChosen(): void {
            root.chosen()
            root.close()
        }

        function onDismissed(): void {
            root.submenuIndex = -1
            if (root.visible) {
                keyHandler.forceActiveFocus()
            }
        }
    }

    Item {
        id: keyHandler

        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                menu.step(event.key === Qt.Key_Up ? -1 : 1)
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                menu.choose(menu.current)
            } else if (event.key === Qt.Key_Right) {
                root.openSubmenu(menu.current)
            } else if (event.key === Qt.Key_Escape || (event.key === Qt.Key_Left && root.isSubmenu)) {
                root.close()
            } else {
                return
            }

            event.accepted = true
        }
    }

    MenuPanel {
        id: menu

        anchors.fill: parent
        at: Qt.point(root.shadowRoom, root.shadowRoom)
        items: root.items
        onCurrentChanged: hoverTimer.restart()
        onSubmenuRequested: index => root.openSubmenu(index)
        onChosen: index => {
            const entry = root.entries[index]
            if (entry !== undefined) {
                Tray.trigger(entry)
            }

            root.chosen()
            root.close()
        }
        // Later, not at once: `MenuPanel` closes before it says what was chosen, and hiding lets go of the
        // app's menu, whose entries the choice still needs.
        onOpenChanged: {
            if (menu.open === false) {
                Qt.callLater(() => {
                    if (menu.open === false) {
                        root.visible = false
                    }
                })
            }
        }
    }
}
