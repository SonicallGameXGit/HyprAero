import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.design
import qs.services

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

    implicitHeight: 48
    color: 'transparent'

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

    Timer {
        id: hideTimer

        interval: 150
        onTriggered: root.popupButton = null
    }

    WorkspacePopup {
        // The window spans the whole bar on its top edge and stays put; the panel inside glides.
        anchor.window: root
        anchor.rect: Qt.rect(0, -2, root.width, 1)
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
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
    }

    GlassPanel {
        anchors.fill: parent

        // Inside both glass borders, flush with the right end like Windows 7's "Show desktop".
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
                    model: Workspaces.entries.length

                    WorkspaceButton {
                        id: button

                        required property int index

                        entry: Workspaces.entries[index]
                        onClicked: Workspaces.switchTo(entry.id)
                        onHoveredChanged: root.buttonHoverChanged(button)
                    }
                }
            }
        }
    }
}
