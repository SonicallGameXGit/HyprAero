import Quickshell
import QtQuick

// A family menu (`MenuPanel`) in a popup window of its own, like Windows 7's context menus: it opens
// above-right of a point and takes the keyboard. Made to fit the menu, so it can stand over other popups
// and past its window's edge; a click anywhere else closes it (the compositor ends its grab). The bar's
// right-click menus (a pin, a preview card, a system icon) and the tray flyout's system icons use it. As
// Windows 7's taskbar menus it fades in rising a little, and fades out sinking back once something is chosen
// or it is closed by the keyboard (a click outside ends the compositor's grab, and the popup with it, at once).
//
// A popup that takes the keyboard may only sit on the bar itself or on another such popup, so it is a popup
// of the bar, or of a grabbing popup of the bar (the tray's flyout).
PopupWindow {
    id: root

    // Room around the menu for its shadow.
    readonly property int shadowRoom: Theme.menuShadowBlur + Theme.menuShadowOffset
    // The point the menu opens from, in its window's coordinates.
    property point at: Qt.point(0, 0)
    // 0 hidden, 1 shown: the menu's opacity, and how far up it has risen (`rise`, inside the shadow room).
    property real appear: 0
    readonly property int rise: shadowRoom - 1

    // `chosen` gets the chosen item itself (`items` are MenuPanel items with whatever the owner needs).
    signal chosen(var item)
    signal dismissed()

    // A popup is placed when it is shown, so one still open is closed first.
    function show(items: var, windowPoint: point): void {
        disappearAnimation.stop()
        menu.keepShown = false
        visible = false
        at = windowPoint
        menu.items = items
        menu.current = -1
        menu.open = true
        appear = 0
        visible = true
        appearAnimation.restart()
    }

    function close(): void {
        menu.close()
    }

    // Its bottom-left corner (the panel's, past the shadow room) on the point.
    anchor.rect: Qt.rect(at.x - shadowRoom, at.y + shadowRoom, 1, 1)
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Top | Edges.Right
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

        appearAnimation.stop()
        disappearAnimation.stop()
        menu.keepShown = false
        menu.close()
        root.dismissed()
    }

    NumberAnimation {
        id: appearAnimation

        target: root
        property: 'appear'
        to: 1
        duration: Theme.motionSoft
        easing.type: Easing.OutCubic
    }

    // The menu stays drawn while it fades out, then the popup goes.
    SequentialAnimation {
        id: disappearAnimation

        NumberAnimation {
            target: root
            property: 'appear'
            to: 0
            duration: Theme.motionFast
            easing.type: Easing.OutCubic
        }

        ScriptAction {
            script: root.visible = false
        }
    }

    Item {
        id: keyHandler

        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                menu.step(event.key === Qt.Key_Up ? -1 : 1)
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                menu.choose(menu.current)
            } else if (event.key === Qt.Key_Escape) {
                menu.close()
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
        opacity: root.appear
        // Nothing more is chosen while it fades out.
        enabled: disappearAnimation.running === false
        onChosen: index => root.chosen(menu.items[index])
        onOpenChanged: {
            if (menu.open === false && root.visible) {
                appearAnimation.stop()
                menu.keepShown = true
                disappearAnimation.restart()
            }
        }

        transform: Translate {
            y: (1 - root.appear) * root.rise
        }
    }
}
