pragma Singleton

import Quickshell
import QtQuick
import 'peek.js' as PeekLogic

// The peek: resting on a window's preview card of the bar for a moment shows that window (and the workspace
// around it) darkened but for the window, resting on a workspace button for twice as long shows the whole
// workspace, both drawn by `PeekLayer`. Moving to another card or button while one shows switches at once;
// leaving them ends it after a blink, so crossing the gap between two does not flash the screen. What is
// worth showing is decided in `peek.js`.
Singleton {
    id: root

    // What is peeked at: `kind` is 'window' (`address`), 'workspace' (`workspaceId`) or '' while none, and
    // the screen of the bar it was asked from.
    property string kind: ''
    property string address: ''
    property int workspaceId: 0
    property string screenName: ''
    readonly property bool active: kind !== ''
    // The same for what the pointer rests on, waiting for its delay.
    property string pendingKind: ''
    property string pendingAddress: ''
    property int pendingWorkspaceId: 0
    property string pendingScreen: ''
    readonly property int minDelay: 100
    readonly property int maxDelay: 3000
    // A workspace reacts later than a window: its picture is bigger and it is easier to cross by accident.
    readonly property int workspaceDelayFactor: 2
    // Leaving a card for the next one must not end the peek.
    readonly property int leaveGrace: 80

    // The pointer is on a card of the window. Does nothing when peeking is off.
    function hoverWindow(windowAddress: string, screen: string): void {
        if (Config.bar.peek === false) {
            return
        }

        const window = Workspaces.windows.find(item => item.address === windowAddress)
        const worth = PeekLogic.worthPeeking(window, Workspaces.windows, Workspaces.shownIds)
        request(worth, 'window', windowAddress, 0, screen, 1)
    }

    // The pointer is on the button of the workspace.
    function hoverWorkspace(id: int, screen: string): void {
        if (Config.bar.peek === false || Config.bar.peekWorkspaces === false) {
            return
        }

        const worth = PeekLogic.worthPeekingWorkspace(id, Workspaces.windows, Workspaces.shownIds)
        request(worth, 'workspace', '', id, screen, workspaceDelayFactor)
    }

    function request(worth: bool, newKind: string, newAddress: string, newWorkspaceId: int, screen: string, factor: int): void {
        if (worth === false) {
            // Nothing new to show there; a peek that is up ends, a pending one is dropped.
            delayTimer.stop()
            pendingKind = ''
            if (active) {
                leaveTimer.restart()
            }

            return
        }

        leaveTimer.stop()
        if (active) {
            kind = newKind
            address = newAddress
            workspaceId = newWorkspaceId
            screenName = screen
            return
        }

        pendingKind = newKind
        pendingAddress = newAddress
        pendingWorkspaceId = newWorkspaceId
        pendingScreen = screen
        delayTimer.interval = factor * Math.max(minDelay, Math.min(Config.bar.peekDelay, maxDelay))
        delayTimer.restart()
    }

    // The pointer left a card of the window.
    function unhoverWindow(windowAddress: string): void {
        release('window', windowAddress, 0)
    }

    // The pointer left the workspace's button.
    function unhoverWorkspace(id: int): void {
        release('workspace', '', id)
    }

    function release(oldKind: string, oldAddress: string, oldWorkspaceId: int): void {
        if (pendingKind === oldKind && pendingAddress === oldAddress && pendingWorkspaceId === oldWorkspaceId) {
            delayTimer.stop()
            pendingKind = ''
        }

        if (kind === oldKind && address === oldAddress && workspaceId === oldWorkspaceId) {
            leaveTimer.restart()
        }
    }

    // Ends it at once: the cards went away, a drag or a menu started, a window was chosen.
    function cancel(): void {
        delayTimer.stop()
        leaveTimer.stop()
        pendingKind = ''
        kind = ''
        address = ''
        workspaceId = 0
        screenName = ''
    }

    Timer {
        id: delayTimer

        onTriggered: {
            root.kind = root.pendingKind
            root.address = root.pendingAddress
            root.workspaceId = root.pendingWorkspaceId
            root.screenName = root.pendingScreen
            root.pendingKind = ''
        }
    }

    Timer {
        id: leaveTimer

        interval: root.leaveGrace
        onTriggered: root.cancel()
    }
}
