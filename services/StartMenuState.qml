pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import 'startMenu.js' as StartMenuList

// Which screen's start menu is open ('' when none): at most one at a time. Also takes requests from
// outside, so a key binding can open it: `qs ipc --path <shell folder> call startMenu toggle`.
Singleton {
    id: root

    property string openScreen: ''
    // When the menu last closed. A click outside the menu closes it before the click arrives, so a click on
    // the orb itself would open it again at once; within `reopenGuard` of closing, it does not.
    property real closedAt: 0
    readonly property int reopenGuard: 300
    // Qt gives a popup that takes the keyboard (the menu) only to a program that has had pointer or key
    // input, and closes it at once otherwise ("Failed to create grabbing popup"); being given the keyboard
    // does not count. A key binding right after startup comes before any, so it first wakes the pointer
    // (`waking`): the bars' drop layers cover the screens for a moment, Hyprland moves the pointer onto the
    // one under it, and that enter is the input (`inputArrived`); the menu opens once the layers are gone,
    // or after `wakeTimer` anyway.
    property bool hadInput: false
    property bool waking: false
    property string wakingScreen: ''

    // Sent just before the menu opens, for the bars to close their own menus first (see `open`).
    signal opening()

    // Every other popup that takes the keyboard is closed first. Qt makes a new grabbing popup a child of
    // the topmost one still open (xdg-shell wants grabs nested), so with the calendar open the menu was
    // placed from the flyout's corner instead of the bar's. A key binding opens it with no click outside to
    // close them. A tray flyout opened by a drag does not grab, and closing it would end the drag.
    function open(screenName: string): void {
        Clock.closeFlyout()
        SystemIcons.closeFlyout()
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
        // A click is input.
        hadInput = true
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

    // A request from outside: 'toggle', 'open' or 'close'.
    function request(kind: string): void {
        const step = StartMenuList.requestStep(kind, openScreen !== '', hadInput, waking)
        if (step === 'close') {
            close()
            return
        }

        if (step === 'cancel') {
            waking = false
            return
        }

        if (step === 'wake') {
            wakingScreen = focusedScreen()
            waking = true
            return
        }

        if (step === 'open') {
            open(focusedScreen())
        }
    }

    // A drop layer has the pointer (`arrived`), or none got it in time.
    function endWake(arrived: bool): void {
        if (waking === false) {
            return
        }

        if (arrived) {
            hadInput = true
        }

        waking = false
        // Only once the layers are gone: a layer unmapping under an open grabbing popup ends its grab.
        const screenName = wakingScreen
        Qt.callLater(() => root.open(screenName))
    }

    function inputArrived(): void {
        endWake(true)
    }

    Timer {
        id: wakeTimer

        interval: 500
        running: root.waking
        onTriggered: root.endWake(false)
    }

    IpcHandler {
        target: 'startMenu'

        function toggle(): void {
            root.request('toggle')
        }

        function open(): void {
            root.request('open')
        }

        function close(): void {
            root.request('close')
        }
    }
}
