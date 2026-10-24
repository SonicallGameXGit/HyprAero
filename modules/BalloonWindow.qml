pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.design
import qs.services

// The balloons' window: a layer surface fastened to the corner or edge the config names (`balloons.position`,
// `Notifications.placement`), shown only while there are balloons, on the screen `Notifications.screen`
// picks. It keeps out of the room other bars reserve (a taskbar at the bottom puts the balloons above it, as
// on Windows 7) without the bar having to be there, takes no keyboard and lets clicks through around the
// balloons.
PanelWindow {
    id: root

    readonly property var placement: Notifications.placement
    // Room around the balloons for their shadow; taken off the margin so the margin is what the user sees.
    readonly property int shadowRoom: Theme.space2
    readonly property int margin: Math.max(0, Config.balloons.margin - shadowRoom)

    screen: Notifications.screen
    visible: Notifications.shown.length > 0
    color: 'transparent'
    anchors.top: placement.top
    anchors.bottom: placement.bottom
    anchors.left: placement.left
    anchors.right: placement.right
    margins.top: margin
    margins.bottom: margin
    margins.left: margin
    margins.right: margin
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    implicitWidth: stack.implicitWidth + shadowRoom * 2
    implicitHeight: stack.implicitHeight + shadowRoom * 2
    WlrLayershell.namespace: 'hypraero-notifications'
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {
        item: stack
    }

    Column {
        id: stack

        x: root.shadowRoom
        y: root.shadowRoom
        spacing: Theme.space2

        Repeater {
            // Keeps each balloon while the list around it changes, so one closing does not restart the others.
            model: ScriptModel {
                values: Notifications.shown
            }

            NotificationBalloon {
                required property var modelData
                required property int index

                // Lined up on the side of the screen they sit on.
                x: {
                    if (root.placement.right) {
                        return stack.width - width
                    }

                    return root.placement.left ? 0 : (stack.width - width) / 2
                }
                notification: modelData
                stemEdge: index === Notifications.stemIndex ? root.placement.stemEdge : 'none'
                stemSide: root.placement.stemSide
            }
        }
    }
}
