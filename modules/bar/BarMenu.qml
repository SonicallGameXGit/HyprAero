import Quickshell
import QtQuick
import qs.design

// The right-click menu of what is on the bar or in its previews (a pin, a preview card), like Windows 7's:
// it opens above-right of the pointer and takes the keyboard. It is its own popup of the bar, made to fit
// the menu, so it can stand over the previews and past the bar's edge; a click anywhere else closes it
// (the compositor ends its grab).
//
// It is a popup of the bar, not of the previews: a popup that takes the keyboard may only sit on the bar
// itself or on another such popup.
PopupWindow {
    id: root

    // Room around the menu for its shadow.
    readonly property int shadowRoom: Theme.menuShadowBlur + Theme.menuShadowOffset
    // The point the menu opens from, in the bar's coordinates.
    property point at: Qt.point(0, 0)

    // `chosen` gets the chosen item itself (`items` are MenuPanel items with whatever the owner needs).
    signal chosen(var item)
    signal dismissed()

    // A popup is placed when it is shown, so one still open is closed first.
    function show(items: var, barPoint: point): void {
        visible = false
        at = barPoint
        menu.items = items
        menu.current = -1
        menu.open = true
        visible = true
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

        menu.close()
        root.dismissed()
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
        onChosen: index => root.chosen(menu.items[index])
        onOpenChanged: {
            if (menu.open === false) {
                root.visible = false
            }
        }
    }
}
