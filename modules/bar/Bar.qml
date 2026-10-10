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

    implicitHeight: 48
    color: 'transparent'

    GlassPanel {
        anchors.fill: parent

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
                        required property int index

                        entry: Workspaces.entries[index]
                        onClicked: Workspaces.switchTo(entry.id)
                    }
                }
            }
        }
    }
}
