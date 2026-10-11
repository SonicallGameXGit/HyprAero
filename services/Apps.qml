pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import 'appUsage.js' as AppUsage
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

    // Whether focus counts as use. A setting once the config file exists.
    property bool countFocus: true
    readonly property int focusDwell: 10000
    // Seconds without input after which the user counts as away.
    readonly property int awayAfter: 300

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

    // Starts the app (or one of its desktop actions, `actionIndex` >= 0) as its own process, not a child
    // of the shell, and counts it as a use.
    function launch(id: string, actionIndex: int): void {
        const entry = DesktopEntries.byId(id)
        if (entry === null || entry === undefined) {
            console.warn(`Apps: no app ${id} to start`)
            return
        }

        let command = Array.from(entry.command)
        if (actionIndex >= 0) {
            const actions = Array.from(entry.actions)
            if (actionIndex >= actions.length) {
                console.warn(`Apps: ${id} has no action ${actionIndex}`)
                return
            }

            command = Array.from(actions[actionIndex].command)
        }

        if (command.length === 0) {
            console.warn(`Apps: ${id} has no command to run`)
            return
        }

        const context = { command: StartMenuList.launchCommand(command, entry.runInTerminal) }
        if (entry.workingDirectory !== '') {
            context.workingDirectory = entry.workingDirectory
        }

        Quickshell.execDetached(context)
        countUse(id)
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
