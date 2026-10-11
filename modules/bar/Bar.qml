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
    // The workspace a window dragged over this screen would go to if dropped now (0: none); its button
    // lights up so the drop is never a surprise.
    // Over the ghost of what is dragged nothing would happen, so no button lights up.
    readonly property int dropTarget: dropLayer.hovered && dropLayer.overOrigin === false
        ? dropWorkspaceAt(dropLayer.pointer)
        : 0
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
    // from it.
    Timer {
        id: hideTimer

        interval: 150
        onTriggered: {
            if (popup.dragging) {
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
            if (dropLayer.overOrigin) {
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
        onWindowChosen: {
            hideTimer.stop()
            root.popupButton = null
        }
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

    // Grows up and to the right from the bar's left end, its bottom on the top of the orb, as in Vista.
    StartMenu {
        anchor.window: root
        anchor.rect: Qt.rect(0, -2 - startButton.rise, 1, 1)
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Top | Edges.Right
        shown: StartMenuState.openScreen === root.screen.name
    }

    // Its left and right borders lie just off the screen, so the bar reads as running on past both edges.
    GlassPanel {
        x: -2
        width: parent.width + 4
        height: parent.height

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
