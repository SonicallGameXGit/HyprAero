pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import 'notificationApps.js' as AppList
import 'notificationIcon.js' as NotificationIcon

// This module's side of the interface with the bar (AGENTS.md section 2.1), in the shared state folder
// (`$XDG_STATE_HOME/hypraero/`, default `~/.local/state/hypraero/`): every app that sent a notification is
// written to `notification-apps.json`, so the bar's "Notification Area Icons" page can list it, and the bar's
// `notification-filter.json` says which apps' notifications to hide (`notificationApps.js`). Without the bar
// there is no filter and nothing is hidden. Only apps' names and icons are written, never what they sent.
Singleton {
    id: root

    // Read by shell.qml so the singleton exists from startup and the filter is read before the first
    // notification comes.
    readonly property bool running: true

    // Every app that sent a notification, first seen first: `[{ key, name, icon, entry, tray }]`.
    property var apps: []
    // Nothing is written before the file has been read, so a slow read never overwrites it; apps seen
    // meanwhile are remembered once it has been.
    property bool loaded: false
    property var early: []
    property var filter: AppList.parseFilter('').filter
    property bool filterLoaded: false

    readonly property string folder: {
        const xdg = Quickshell.env('XDG_STATE_HOME')
        if (typeof xdg === 'string' && xdg.startsWith('/')) {
            return xdg + '/hypraero'
        }

        return Quickshell.env('HOME') + '/.local/state/hypraero'
    }

    // `{ key, name, icon, entry }`: the app as the bar's page shows it, its name and icon from its desktop
    // entry when it has one. Never the notification's `image`, which can be a person's picture.
    function appOf(notification: Notification): var {
        const key = AppList.appKey(notification.appName, notification.desktopEntry)
        let name = key
        let icons = NotificationIcon.candidates(notification.appIcon)
        if (notification.desktopEntry !== '') {
            const entry = DesktopEntries.heuristicLookup(notification.desktopEntry)
            if (entry !== null) {
                name = entry.name
                icons = NotificationIcon.candidates(entry.icon).concat(icons)
            }
        }

        let icon = ''
        for (const candidate of icons) {
            if (candidate.kind === 'theme') {
                icon = 'image://icon/' + candidate.name
                break
            }

            if (candidate.kind === 'url') {
                icon = candidate.url
                break
            }
        }

        return { key: key, name: name, icon: icon, entry: notification.desktopEntry }
    }

    function hides(notification: Notification): bool {
        // A notification that comes while the file is still being read waits for it (`blockLoading`), so an
        // app hidden on the bar never shows at startup.
        if (filterLoaded === false) {
            applyFilter(filterFile.text())
        }

        const app = appOf(notification)
        return AppList.hidden(filter, app.key, AppList.trayOf(app, filter.trayIcons))
    }

    function seen(notification: Notification): void {
        const app = appOf(notification)
        if (loaded === false) {
            early = early.concat([app])
            return
        }

        update(AppList.remember(apps, app, filter.trayIcons))
    }

    function update(changed: var): void {
        if (changed === apps) {
            return
        }

        apps = changed
        saveTimer.restart()
    }

    function applyApps(text: string): void {
        const parsed = AppList.parseApps(text)
        for (const problem of parsed.problems) {
            console.warn('NotificationApps: notification-apps.json: ' + problem)
        }

        let list = AppList.relink(parsed.apps, filter.trayIcons)
        for (const app of early) {
            list = AppList.remember(list, app, filter.trayIcons)
        }

        apps = list
        early = []
        loaded = true
        // Written at least once, so the bar knows this module is there even before any notification.
        if (text.trim() === '' || AppList.serializeApps(apps) !== text) {
            saveTimer.restart()
        }
    }

    function applyFilter(text: string): void {
        const parsed = AppList.parseFilter(text)
        for (const problem of parsed.problems) {
            console.warn('NotificationApps: notification-filter.json: ' + problem)
        }

        filter = parsed.filter
        filterLoaded = true
        if (loaded) {
            update(AppList.relink(apps, filter.trayIcons))
        }
    }

    // A file is only noticed when it appears in a folder that already exists.
    Component.onCompleted: Quickshell.execDetached(['mkdir', '-p', folder])

    FileView {
        id: appsFile

        path: root.folder + '/notification-apps.json'
        printErrors: false
        onLoaded: root.applyApps(text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound) {
                console.warn(`NotificationApps: cannot read notification-apps.json (${FileViewError.toString(error)}), starting fresh`)
            }

            root.applyApps('')
        }
    }

    FileView {
        id: filterFile

        path: root.folder + '/notification-filter.json'
        printErrors: false
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.applyFilter(text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound) {
                console.warn(`NotificationApps: cannot read notification-filter.json (${FileViewError.toString(error)}), hiding nothing`)
            }

            root.applyFilter('')
        }
    }

    Timer {
        id: saveTimer

        interval: 1000
        onTriggered: appsFile.setText(AppList.serializeApps(root.apps))
    }
}
