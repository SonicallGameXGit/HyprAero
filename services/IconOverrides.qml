pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import 'iconOverrides.js' as IconList

// The icons the user chose instead of an app's, a window's or a workspace's own, through the Icon Manager
// (`modules/icons/IconManager.qml`, Windows 7's "Change Icon"), kept in `$XDG_STATE_HOME/hypraero/icons.json`.
// A picture file the user picks is copied into `icons/` beside it, so moving or deleting the original changes
// nothing; a copy nothing uses any more is removed. Also the list of icons to choose from (every icon theme's
// files, read once when the manager first opens), the file chooser, and whether the manager is open and for
// what.
//
// What is drawn: a window takes its own icon, else its app's, else the theme's; a workspace with an icon of its
// own always shows it, whatever its windows are (`services/iconOverrides.js`).
Singleton {
    id: root

    readonly property string folder: Apps.stateFolder + '/icons'
    // `{ apps, windows, workspaces }`, each `{ key: path }`.
    property var overrides: IconList.emptyOverrides()
    // Nothing is written before the file has been read, so a slow read never overwrites it.
    property bool loaded: false

    // The manager is open for `target`: `{ kind, key, name, app, appName }` (`app` and `appName`: a window's
    // app, '' when it has no desktop entry, for "every window of it").
    property bool managerOpen: false
    property var target: null
    // The icon folders, in the order they win (`IconList.parseIconFiles`).
    readonly property var roots: {
        const home = Quickshell.env('HOME')
        const dataHome = Quickshell.env('XDG_DATA_HOME')
        const dataDirs = Quickshell.env('XDG_DATA_DIRS')
        const dataFolder = typeof dataHome === 'string' && dataHome.startsWith('/') ? dataHome : home + '/.local/share'
        const dirs = typeof dataDirs === 'string' && dataDirs !== '' ? dataDirs.split(':') : ['/usr/local/share', '/usr/share']
        const result = [{ path: home + '/.icons', theme: '' }]
        for (const dir of [dataFolder].concat(dirs)) {
            if (dir.startsWith('/') && result.every(known => known.path !== dir + '/icons')) {
                result.push({ path: dir + '/icons', theme: '' })
            }
        }

        result.push({ path: '/usr/share/pixmaps', theme: qsTr('Pixmaps') })
        return result
    }
    // Every icon to choose from, `[{ name, theme, path }]`, and the themes they come from.
    property var icons: []
    property var themes: []
    property bool listing: false
    property bool listed: false
    // Whether a picture file can be chosen: zenity (GTK's file chooser) is installed.
    readonly property bool canBrowse: Session.canChoosePicture

    // A file was chosen in the chooser (not yet used for anything: the manager shows it until OK).
    signal fileChosen(string path)

    // The icon chosen for that thing, as a path ('' when none).
    function iconOf(kind: string, key: string): string {
        return IconList.iconFor(overrides, kind, key)
    }

    // Whether the path is a picture the user chose, copied into the icons folder (not a theme's file).
    function isCopy(path: string): bool {
        return IconList.isManaged(path, folder)
    }

    // The icons of `theme` ('' for all) whose names have the words of `text`, best first.
    function search(text: string, theme: string): var {
        return IconList.searchIcons(icons, text, theme)
    }

    // The address an Image shows the path at.
    function sourceOf(path: string): string {
        return IconList.fileUrl(path)
    }

    // A workspace's own icon, '' when it has none (it shows its windows' icons then).
    function workspaceIcon(id: int): string {
        return sourceOf(iconOf('workspaces', String(id)))
    }

    // An app's icon (a pin, a start menu row): the chosen one, else its desktop entry's `iconName`.
    function appIcon(id: string, iconName: string): string {
        const chosen = iconOf('apps', id)
        return chosen !== '' ? sourceOf(chosen) : AppIcons.forName(iconName)
    }

    // A window's icon: its own, else its app's, else the theme's for its app id.
    function windowIcon(address: string, appId: string): string {
        const own = iconOf('windows', address)
        if (own !== '') {
            return sourceOf(own)
        }

        const app = Apps.appFor(appId)
        const chosen = app === '' ? '' : iconOf('apps', app)
        return chosen !== '' ? sourceOf(chosen) : AppIcons.pathFor(appId)
    }

    // Sets the icon of that thing to an icon file (a theme's, or a copy already in the icons folder); ''
    // takes it away.
    function setIcon(kind: string, key: string, path: string): void {
        update(IconList.withIcon(overrides, kind, key, path))
    }

    // Copies a picture file into the icons folder and makes it the icon of that thing once it is there.
    function useFile(kind: string, key: string, source: string): void {
        const name = IconList.managedFileName(kind, key, source, Date.now())
        if (name === '' || copier.running) {
            console.warn(`IconOverrides: cannot use ${source} as an icon`)
            return
        }

        copier.kind = kind
        copier.key = key
        copier.target = folder + '/' + name
        copier.command = IconList.copyCommand(source, folder, copier.target)
        copier.running = true
    }

    // The bar's workspace buttons were reordered (slot `from` to slot `to`): the icons go with them.
    function reorderWorkspaces(ids: var, from: int, to: int): void {
        const workspaces = IconList.reorderedWorkspaces(overrides.workspaces, ids, from, to)
        if (workspaces !== overrides.workspaces) {
            const copy = Object.assign({}, overrides)
            copy.workspaces = workspaces
            update(copy)
        }
    }

    function openManager(kind: string, key: string, name: string, app: string): void {
        const entry = app === '' ? undefined : Apps.list.find(item => item.id === app)
        target = {
            kind: kind,
            key: key,
            name: name,
            app: app,
            appName: entry === undefined ? app : entry.name,
        }
        // Opened again while open: shown again for the new target.
        managerOpen = false
        managerOpen = true
        listIcons()
    }

    function closeManager(): void {
        managerOpen = false
    }

    // Reads the icon themes once; the list is kept for the rest of the session.
    function listIcons(): void {
        if (listed || listing) {
            return
        }

        listing = true
        lister.command = IconList.listCommand(roots)
        lister.running = true
    }

    function browse(): void {
        if (canBrowse && chooser.running === false) {
            chooser.running = true
        }
    }

    function update(next: var): void {
        if (next === overrides) {
            return
        }

        const unused = IconList.unusedFiles(overrides, next, folder)
        overrides = next
        if (unused.length > 0) {
            Quickshell.execDetached(['rm', '-f', '--'].concat(unused))
        }

        if (loaded) {
            saveTimer.restart()
        }
    }

    function apply(text: string): void {
        const parsed = IconList.parseOverrides(text)
        for (const problem of parsed.problems) {
            console.warn('IconOverrides: icons.json: ' + problem)
        }

        overrides = parsed.overrides
        loaded = true
        pruneTimer.restart()
    }

    // The windows that closed while the shell was not running.
    function pruneWindows(): void {
        const live = Object.keys(overrides.windows).filter(address => Workspaces.toplevelAt(address) !== null)
        update(IconList.withoutGoneWindows(overrides, live))
    }

    FileView {
        id: file

        path: Apps.stateFolder + '/icons.json'
        printErrors: false
        onLoaded: root.apply(text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound) {
                console.warn(`IconOverrides: cannot read icons.json (${FileViewError.toString(error)}), starting fresh`)
            }

            root.apply('')
        }
    }

    Timer {
        id: saveTimer

        interval: 1000
        onTriggered: file.setText(IconList.serializeOverrides(root.overrides))
    }

    // Hyprland's windows are read a moment after the shell starts.
    Timer {
        id: pruneTimer

        interval: 5000
        onTriggered: root.pruneWindows()
    }

    Connections {
        target: Workspaces

        function onWindowClosed(address: string): void {
            root.setIcon('windows', address, '')
        }
    }

    Process {
        id: lister

        stdout: StdioCollector {
            onStreamFinished: {
                reader.reading = IconList.startIconFiles(text, root.roots)
                reader.start()
            }
        }
    }

    // `find`'s output is read a part at a time, the shell drawing between the parts: read at once, a big
    // icon theme kept everything frozen.
    Timer {
        id: reader

        property var reading: null

        // Not 0: a repeating Timer of 0 never fires.
        interval: 1
        repeat: true
        onTriggered: {
            if (reading === null) {
                stop()
                return
            }

            // About a frame's worth of lines.
            if (IconList.readIconFiles(reading, 3000) === false) {
                return
            }

            stop()
            const parsed = IconList.finishIconFiles(reading)
            reading = null
            root.icons = parsed.icons
            root.themes = parsed.themes
            root.listing = false
            root.listed = true
        }
    }

    // Opens in the pictures folder. zenity prints the chosen path, and nothing when cancelled.
    Process {
        id: chooser

        command: {
            const pictures = Session.folders.find(item => item.key === 'pictures')
            return [
                'zenity',
                '--file-selection',
                '--title=' + qsTr('Choose an icon'),
                '--filename=' + (pictures === undefined ? Session.home : pictures.path) + '/',
                '--file-filter=' + IconList.fileFilter(qsTr('Pictures')),
            ]
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const path = IconList.chosenFile(text)
                if (path !== '') {
                    root.fileChosen(path)
                } else if (text.trim() !== '') {
                    console.warn('IconOverrides: not a picture: ' + text.trim())
                }
            }
        }
    }

    Process {
        id: copier

        property string kind: ''
        property string key: ''
        property string target: ''

        onExited: code => {
            if (code !== 0) {
                console.warn(`IconOverrides: cannot copy the icon to ${copier.target} (exit code ${code})`)
                return
            }

            root.setIcon(copier.kind, copier.key, copier.target)
        }
    }
}
