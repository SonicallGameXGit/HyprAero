pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import 'pins.js' as PinList

// The apps pinned to the bar (its Quick Launch, after Windows Vista), in the user's order, kept in
// `$XDG_STATE_HOME/hypraero/pins.json` next to the start menu's state.
Singleton {
    id: root

    // Every pinned desktop entry id, installed or not: an app that is gone may come back.
    property var ids: []
    // The pinned apps that are installed, in order, as `Apps.list` objects.
    readonly property var apps: {
        const byId = new Map(Apps.list.map(app => [app.id, app]))
        const result = []
        for (const id of ids) {
            const app = byId.get(id)
            if (app !== undefined) {
                result.push(app)
            }
        }

        return result
    }
    // Nothing is written before the file has been read, so a slow read never overwrites it.
    property bool loaded: false

    function isPinned(id: string): bool {
        return ids.includes(id)
    }

    // Pins the app before the shown pin at `gap` (0: first; past the last: at the end). An app already
    // pinned moves there.
    function placeAt(id: string, gap: int): void {
        const before = gap >= 0 && gap < apps.length ? apps[gap].id : ''
        const placed = PinList.placePin(ids, id, before)
        if (placed !== ids) {
            ids = placed
            save()
        }
    }

    function pin(id: string): void {
        if (isPinned(id) === false) {
            placeAt(id, apps.length)
        }
    }

    function unpin(id: string): void {
        if (isPinned(id)) {
            ids = PinList.removePin(ids, id)
            save()
        }
    }

    function save(): void {
        if (loaded) {
            saveTimer.restart()
        }
    }

    function apply(text: string): void {
        const parsed = PinList.parsePins(text)
        for (const problem of parsed.problems) {
            console.warn('Pins: pins.json: ' + problem)
        }

        ids = parsed.apps
        loaded = true
    }

    FileView {
        id: file

        path: Apps.stateFolder + '/pins.json'
        printErrors: false
        onLoaded: root.apply(text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound) {
                console.warn(`Pins: cannot read pins.json (${FileViewError.toString(error)}), starting fresh`)
            }

            root.apply('')
        }
    }

    Timer {
        id: saveTimer

        interval: 1000
        onTriggered: file.setText(PinList.serializePins(root.ids))
    }
}
