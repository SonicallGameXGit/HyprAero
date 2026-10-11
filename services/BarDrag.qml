pragma Singleton

import Quickshell
import QtQuick

// What is being dragged out of a bar, shared by every screen: one window (a preview card) or a whole
// workspace (its button). The drop layer of each screen shows the picture under the pointer and takes
// the drop. Nothing here talks to Hyprland.
Singleton {
    id: root

    // The dragged window ('' when it is not a window) or workspace (0 when it is not a workspace).
    property string address: ''
    property int workspaceId: 0
    // The dragged item's picture (a grab result, kept here so its image stays alive), its size, and the
    // point of it the pointer holds.
    property var picture: null
    property size pictureSize: Qt.size(0, 0)
    property point hotSpot: Qt.point(0, 0)
    // Where it was taken from: the screen, and its place in that screen's bar coordinates (the bar's
    // top-left is 0, 0; above the bar is negative). A drop back there changes nothing.
    property var originScreen: null
    property rect originRect: Qt.rect(0, 0, 0, 0)

    readonly property bool active: address !== '' || workspaceId !== 0

    function begin(windowAddress: string, workspace: int, grab: var, size: size, point: point, screen: var, rect: rect): void {
        picture = grab
        pictureSize = size
        hotSpot = point
        originScreen = screen
        originRect = rect
        address = windowAddress
        workspaceId = workspace
    }

    function end(): void {
        address = ''
        workspaceId = 0
        picture = null
        originScreen = null
    }
}
