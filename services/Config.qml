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
    property var startMenu: Settings.parseConfig('').values.startMenu

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

        startMenu = config.values.startMenu
    }

    // The file is only noticed when it appears in a folder that already exists.
    Component.onCompleted: Quickshell.execDetached(['mkdir', '-p', folder])

    FileView {
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
