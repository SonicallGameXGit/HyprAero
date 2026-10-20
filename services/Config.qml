pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import '../config/settings.js' as Settings

// The user's settings from `$XDG_CONFIG_HOME/hypraero/config.json` (default `~/.config/hypraero/`), read
// again whenever the file changes, so a change applies at once. The file is optional and only needs what
// differs from the defaults (`config/settings.js`); a bad value falls back to its default and is logged.
Singleton {
    id: root

    // One object per group, every setting filled in.
    property var bar: Settings.parseConfig('').values.bar
    property var startMenu: Settings.parseConfig('').values.startMenu
    property var tray: Settings.parseConfig('').values.tray

    readonly property string folder: {
        const xdg = Quickshell.env('XDG_CONFIG_HOME')
        if (typeof xdg === 'string' && xdg.startsWith('/')) {
            return xdg + '/hypraero'
        }

        return Quickshell.env('HOME') + '/.config/hypraero'
    }

    function apply(text: string): void {
        const config = Settings.parseConfig(text)
        for (const problem of config.problems) {
            console.warn('Config: config.json: ' + problem)
        }

        bar = config.values.bar
        startMenu = config.values.startMenu
        tray = config.values.tray
    }

    // Changes one setting from the shell itself (the tray's "Customize" page) and writes the file, keeping
    // whatever else the user wrote in it. A file that is not valid JSON is left alone and the change only
    // lasts until the next start; the log says so.
    function set(group: string, name: string, value: var): void {
        const text = Settings.setSetting(file.text(), group, name, value)
        if (text === null) {
            console.warn(`Config: config.json cannot be changed safely (fix it first), ${group}.${name} applies until the shell restarts`)
            const values = Object.assign({}, root[group])
            values[name] = value
            root[group] = values
            return
        }

        file.setText(text)
        apply(text)
    }

    // The file is only noticed when it appears in a folder that already exists.
    Component.onCompleted: Quickshell.execDetached(['mkdir', '-p', folder])

    FileView {
        id: file

        path: root.folder + '/config.json'
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.apply(text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound) {
                console.warn(`Config: cannot read config.json (${FileViewError.toString(error)}), using the defaults`)
            }

            root.apply('')
        }
    }
}
