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

    implicitHeight: 40
    color: 'transparent'

    GlassPanel {
        anchors.fill: parent

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Theme.space2
            spacing: Theme.space1

            Repeater {
                model: Workspaces.entries

                ControlButton {
                    required property var modelData

                    width: 36
                    text: modelData.id
                    kind: modelData.focused ? 'accent' : (modelData.occupied ? 'normal' : 'tool')
                    onClicked: Workspaces.switchTo(modelData.id)
                }
            }
        }
    }
}
