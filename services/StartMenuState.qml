pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// Which screen's start menu is open ('' when none): at most one at a time. Also takes requests from
// outside, so a key binding can open it: `qs ipc --path <shell folder> call startMenu toggle`.
Singleton {
    id: root

    property string openScreen: ''
    // When the menu last closed. A click outside the menu closes it before the click arrives, so a click on
    // the orb itself would open it again at once; within `reopenGuard` of closing, it does not.
    property real closedAt: 0
    readonly property int reopenGuard: 300

    function open(screenName: string): void {
        Apps.refreshScores()
        Session.findPicture()
        openScreen = screenName
    }

    function close(): void {
        if (openScreen === '') {
            return
        }

        openScreen = ''
        closedAt = Date.now()
    }

    // The orb was clicked on this screen.
    function toggle(screenName: string): void {
        if (openScreen !== '') {
            close()
            return
        }

        if (Date.now() - closedAt < reopenGuard) {
            return
        }

        open(screenName)
    }

    function focusedScreen(): string {
        const monitor = Hyprland.focusedMonitor
        return monitor === null ? '' : monitor.name
    }

    IpcHandler {
        target: 'startMenu'

        function toggle(): void {
            if (root.openScreen !== '') {
                root.close()
                return
            }

            root.open(root.focusedScreen())
        }

        function open(): void {
            root.open(root.focusedScreen())
        }

        function close(): void {
            root.close()
        }
    }
}
