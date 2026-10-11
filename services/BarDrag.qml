pragma Singleton

import Quickshell
import QtQuick

// What is being dragged out of a bar or its start menu, shared by every screen: one window (a preview
// card), a whole workspace (its button) or an app to start (a start menu row). The drop layer of each
// screen shows the picture under the pointer and takes the drop. Nothing here talks to Hyprland.
Singleton {
    id: root

    // The dragged window ('' when it is not a window), workspace (0 when it is not a workspace) or app
    // (its desktop entry id, '' when it is not an app).
    property string address: ''
    property int workspaceId: 0
    property string appId: ''
    // What it was taken out of when that matters: 'pins' (a pin, which a drop on the pins moves) or
    // 'startMenu' (an app row); '' otherwise.
    property string from: ''
    // The dragged item's picture (a grab result, kept here so its image stays alive), its size, and the
    // point of it the pointer holds.
    property var picture: null
    property size pictureSize: Qt.size(0, 0)
    property point hotSpot: Qt.point(0, 0)
    // Where it was taken from: the screen, and its place in that screen's bar coordinates (the bar's
    // top-left is 0, 0; above the bar is negative). A drop back there changes nothing.
    property var originScreen: null
    property rect originRect: Qt.rect(0, 0, 0, 0)
    // Where a drop counts as putting it back, in the same coordinates: the ghost itself, or more (the
    // whole start menu for an app).
    property rect returnRect: Qt.rect(0, 0, 0, 0)

    readonly property bool active: address !== '' || workspaceId !== 0 || appId !== ''

    function begin(windowAddress: string, workspace: int, app: string, source: string, grab: var, size: size, point: point, screen: var, rect: rect, returnArea: rect): void {
        from = source
        picture = grab
        pictureSize = size
        hotSpot = point
        originScreen = screen
        originRect = rect
        returnRect = returnArea
        address = windowAddress
        workspaceId = workspace
        appId = app
    }

    function end(): void {
        address = ''
        workspaceId = 0
        appId = ''
        from = ''
        picture = null
        originScreen = null
    }
}
