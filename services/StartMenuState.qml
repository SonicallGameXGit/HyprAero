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

    // Sent just before the menu opens, for the bars to close their own menus first (see `open`).
    signal opening()

    // Every other popup that takes the keyboard is closed first. Qt makes a new grabbing popup a child of
    // the topmost one still open (xdg-shell wants grabs nested), so with the calendar open the menu was
    // placed from the flyout's corner instead of the bar's. A key binding opens it with no click outside to
    // close them. A tray flyout opened by a drag does not grab, and closing it would end the drag.
    function open(screenName: string): void {
        Clock.closeFlyout()
        if (Tray.flyoutByDrag === false) {
            Tray.closeFlyout()
        }

        opening()
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
