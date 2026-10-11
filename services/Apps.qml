pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import 'appUsage.js' as AppUsage
import 'launchPlacement.js' as LaunchPlacement
import 'startMenu.js' as StartMenuList

// The installed apps for the start menu: which are featured, how much each is used, and starting them.
// Featured apps and usage are kept in `$XDG_STATE_HOME/hypraero/start-menu.json`.
//
// A use is a launch from the menu, or (`countFocus`) a window of the app keeping focus for
// `focusDwell`, so apps started by a key binding or a terminal rank too. Either counts at most once per
// `AppUsage.useGap` per app (`appUsage.js`). Nothing counts while the user is away (`awayAfter`), so a
// window left focused overnight is not "used" all night.
Singleton {
    id: root

    // Whether focus counts as use (`startMenu.countFocus` in the config file).
    readonly property bool countFocus: Config.startMenu.countFocus
    readonly property int focusDwell: 10000
    // Seconds without input after which the user counts as away.
    readonly property int awayAfter: 300
    // The format of an app dragged out of the start menu: its desktop entry id. Private to the shell, so
    // dropping it on an app does nothing there.
    readonly property string appDragFormat: 'application/x-hypraero-app'

    property var featured: []
    property var usage: ({})
    // Every app's score, taken when the menu opens (`refreshScores`) and not on every use: an open menu
    // must not reorder itself under the pointer.
    property var scores: ({})

    // Every app the menu can show (not the hidden ones), as plain objects for `startMenu.js`.
    readonly property var list: {
        const result = []
        for (const entry of DesktopEntries.applications.values) {
            if (entry.noDisplay) {
                continue
            }

            result.push({
                id: entry.id,
                name: entry.name,
                genericName: entry.genericName,
                comment: entry.comment,
                keywords: Array.from(entry.keywords),
                command: Array.from(entry.command),
                icon: entry.icon,
                actions: Array.from(entry.actions).map(action => action.name),
            })
        }

        return result
    }

    readonly property string stateFolder: {
        const xdg = Quickshell.env('XDG_STATE_HOME')
        if (typeof xdg === 'string' && xdg.startsWith('/')) {
            return xdg + '/hypraero'
        }

        return Quickshell.env('HOME') + '/.local/state/hypraero'
    }
    // Nothing is written before the file has been read, so a slow read never overwrites it.
    property bool stateLoaded: false
    // The focused window's app id ('' when no window has focus); it can change after the window gets
    // focus, as some apps set it late.
    readonly property string activeAppId: {
        const toplevel = ToplevelManager.activeToplevel
        if (toplevel === null || toplevel === undefined) {
            return ''
        }

        return toplevel.appId
    }
    // The app (desktop entry id) whose window has focus, '' when none or unknown.
    property string focusedApp: ''
    // Apps dropped on a workspace that may still open windows (`launchPlacement.js`), and the addresses of
    // the windows already looked at, so only new ones are placed. Nothing is watched while it is empty.
    property var launches: []
    property var seenWindows: []

    onActiveAppIdChanged: updateFocus()

    function refreshScores(): void {
        scores = AppUsage.scoresAt(usage, Date.now())
    }

    function isFeatured(id: string): bool {
        return featured.includes(id)
    }

    function setFeatured(id: string, on: bool): void {
        if (on === isFeatured(id)) {
            return
        }

        featured = on ? featured.concat([id]) : featured.filter(item => item !== id)
        save()
    }

    // Forgets every use of the app, so it goes back to its A to Z place.
    function forget(id: string): void {
        if (usage[id] === undefined) {
            return
        }

        const copy = Object.assign({}, usage)
        delete copy[id]
        usage = copy
        refreshScores()
        save()
    }

    function countUse(id: string): void {
        const time = Date.now()
        if (AppUsage.useDue(usage[id], time) === false) {
            return
        }

        const copy = Object.assign({}, usage)
        copy[id] = AppUsage.addUse(usage[id], time)
        usage = copy
        save()
    }

    // What starts the app (or one of its desktop actions, `actionIndex` >= 0): `{ command, workingDirectory }`
    // with the terminal already added for terminal apps, or null when it cannot be started.
    function startCommand(id: string, actionIndex: int): var {
        const entry = DesktopEntries.byId(id)
        if (entry === null || entry === undefined) {
            console.warn(`Apps: no app ${id} to start`)
            return null
        }

        let command = Array.from(entry.command)
        if (actionIndex >= 0) {
            const actions = Array.from(entry.actions)
            if (actionIndex >= actions.length) {
                console.warn(`Apps: ${id} has no action ${actionIndex}`)
                return null
            }

            command = Array.from(actions[actionIndex].command)
        }

        if (command.length === 0) {
            console.warn(`Apps: ${id} has no command to run`)
            return null
        }

        return {
            command: StartMenuList.launchCommand(command, entry.runInTerminal),
            workingDirectory: entry.workingDirectory,
        }
    }

    // Starts the app (or one of its desktop actions, `actionIndex` >= 0) as its own process, not a child
    // of the shell, and counts it as a use.
    function launch(id: string, actionIndex: int): void {
        const start = startCommand(id, actionIndex)
        if (start === null) {
            return
        }

        const context = { command: start.command }
        if (start.workingDirectory !== '') {
            context.workingDirectory = start.workingDirectory
        }

        Quickshell.execDetached(context)
        countUse(id)
    }

    // Starts the app so its window opens on workspace `workspaceId` while the view stays where it is (an
    // app dropped on a workspace), and counts it as a use. Hyprland is asked to open it there; a window it
    // cannot recognise as the app's (`launchPlacement.js`) is moved there once it appears.
    function launchOn(id: string, workspaceId: int): void {
        const start = startCommand(id, -1)
        if (start === null) {
            return
        }

        if (launches.length === 0) {
            seenWindows = Workspaces.windows.map(window => window.address)
        }

        launches = LaunchPlacement.addLaunch(launches, id, workspaceId, Date.now())
        Workspaces.startOn(start.command, start.workingDirectory, workspaceId)
        countUse(id)
    }

    // Sends each window that appeared since the last look to the workspace its app was dropped on.
    function placeNewWindows(): void {
        const now = Date.now()
        let pending = LaunchPlacement.liveLaunches(launches, now)
        const seen = seenWindows.slice()
        for (const window of Workspaces.windows) {
            if (window.address === '' || seen.includes(window.address)) {
                continue
            }

            seen.push(window.address)
            const placed = LaunchPlacement.placeWindow(pending, appFor(window.appId), now)
            pending = placed.launches
            if (placed.workspaceId > 0 && placed.workspaceId !== window.workspaceId) {
                Workspaces.moveWindow(window.address, placed.workspaceId)
            }
        }

        seenWindows = seen
        launches = pending
    }

    // The desktop entry id of a window's app id, '' when there is none (or entries are still loading).
    function appFor(appId: string): string {
        if (appId === '' || DesktopEntries.applications.values.length === 0) {
            return ''
        }

        const entry = DesktopEntries.heuristicLookup(appId)
        return entry === null || entry === undefined ? '' : entry.id
    }

    function countFocusedApp(): void {
        if (countFocus && focusedApp !== '' && idleMonitor.isIdle === false) {
            countUse(focusedApp)
        }
    }

    function updateFocus(): void {
        focusedApp = appFor(activeAppId)
        dwellTimer.restart()
    }

    function save(): void {
        if (stateLoaded) {
            saveTimer.restart()
        }
    }

    function applyState(text: string): void {
        const state = AppUsage.parseState(text, Date.now())
        for (const problem of state.problems) {
            console.warn('Apps: start-menu.json: ' + problem)
        }

        featured = state.featured
        usage = state.usage
        stateLoaded = true
        refreshScores()
    }

    Component.onCompleted: Quickshell.execDetached(['mkdir', '-p', stateFolder])

    FileView {
        id: stateFile

        path: root.stateFolder + '/start-menu.json'
        printErrors: false
        onLoaded: root.applyState(text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound) {
                console.warn(`Apps: cannot read start-menu.json (${FileViewError.toString(error)}), starting fresh`)
            }

            root.applyState('')
        }
    }

    Timer {
        id: saveTimer

        interval: 1000
        onTriggered: stateFile.setText(AppUsage.serializeState(root.featured, root.usage))
    }

    Connections {
        target: Workspaces
        enabled: root.launches.length > 0

        function onWindowsChanged(): void {
            root.placeNewWindows()
        }
    }

    // Desktop entries load after startup; until then no window can be matched to its app.
    Connections {
        target: DesktopEntries.applications

        function onValuesChanged(): void {
            root.updateFocus()
        }
    }

    Timer {
        id: dwellTimer

        interval: root.focusDwell
        onTriggered: root.countFocusedApp()
    }

    // Staying in one app keeps counting it, once per gap.
    Timer {
        interval: AppUsage.useGap
        repeat: true
        running: root.countFocus && root.focusedApp !== ''
        onTriggered: root.countFocusedApp()
    }

    IdleMonitor {
        id: idleMonitor

        timeout: root.awayAfter
    }
}
