pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import 'settings.js' as Settings

// The user's settings from `$XDG_CONFIG_HOME/hypraero/notifications.json` (default `~/.config/hypraero/`),
// read again whenever the file changes, so a change applies at once. The file is optional and only needs
// what differs from the defaults (`settings.js`); a bad value falls back to its default and is logged.
Singleton {
    id: root

    // One object per group, every setting filled in.
    property var balloons: Settings.parseConfig('').values.balloons

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
            console.warn('Config: notifications.json: ' + problem)
        }

        balloons = config.values.balloons
    }

    // The file is only noticed when it appears in a folder that already exists.
    Component.onCompleted: Quickshell.execDetached(['mkdir', '-p', folder])

    FileView {
        path: root.folder + '/notifications.json'
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.apply(text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound) {
                console.warn(`Config: cannot read notifications.json (${FileViewError.toString(error)}), using the defaults`)
            }

            root.apply('')
        }
    }
}
