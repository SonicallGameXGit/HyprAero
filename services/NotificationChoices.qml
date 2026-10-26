pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import 'notificationChoices.js' as Choices
import 'tray.js' as TrayList

// Which apps' notifications show, as chosen on the "Notification Area Icons" page: this shell's side of the
// interface with the notifications module (AGENTS.md section 2.1, `notificationChoices.js`). The choices,
// with the page's app icons and which of them hide their notifications (their behavior), are written to `notification-filter.json` in the state folder, which that
// module reads; the apps it has had notifications from are read from its `notification-apps.json`. Without
// that module (no such file) the page offers nothing about notifications and nothing is written.
Singleton {
    id: root

    property var choices: Choices.emptyChoices()
    // Nothing is written before the file has been read, so a slow read never overwrites it.
    property bool loaded: false
    // Every app the notifications module has had a notification from: `[{ key, name, icon, tray }]`.
    property var apps: []
    // The notifications module has run here (its file is there): the page shows the notification choices.
    property bool available: false
    // The file as last read or written, so an unchanged one is not written again.
    property string written: ''

    // The choices of an app without a tray icon on the page.
    readonly property var appChoices: Choices.appChoices
    // The app icons the page lists (not the shell's own, which send no notifications).
    readonly property var trayIcons: Tray.icons.filter(icon => TrayList.isSystemKey(icon.key) === false && Tray.listed(icon.key))
    // What the file should hold; '' until both it and the tray's file were read.
    readonly property string text: loaded && Tray.loaded && available
        ? Choices.serializeFilter(choices, trayIcons, Config.tray.showAll, TrayList.notificationsShown, apps)
        : ''

    onTextChanged: {
        if (text !== '') {
            saveTimer.restart()
        }
    }

    // An app without a tray icon on the page: 'shown' or 'hidden' (`Choices.appChoices`).
    function appChoiceOf(key: string): string {
        return Choices.appChoiceOf(choices, key)
    }

    function setAppChoice(key: string, choice: string): void {
        choices = Choices.setAppChoice(choices, key, choice)
    }

    function setHideAll(on: bool): void {
        choices = Choices.setHideAll(choices, on)
    }

    function restoreDefaults(): void {
        choices = Choices.restoreDefaults(choices)
    }

    // The apps that have no row of their tray icon on the page, first seen first.
    function appsWithoutTray(): var {
        return Choices.appsWithoutTray(apps, trayIcons.map(icon => icon.key))
    }

    function applyChoices(text: string): void {
        const parsed = Choices.parseFilter(text)
        for (const problem of parsed.problems) {
            console.warn('NotificationChoices: notification-filter.json: ' + problem)
        }

        choices = parsed.choices
        written = text
        loaded = true
    }

    function applyApps(text: string): void {
        const parsed = Choices.parseApps(text)
        for (const problem of parsed.problems) {
            console.warn('NotificationChoices: notification-apps.json: ' + problem)
        }

        apps = parsed.apps
        available = parsed.known
    }

    FileView {
        id: filterFile

        path: Apps.stateFolder + '/notification-filter.json'
        printErrors: false
        onLoaded: root.applyChoices(text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound) {
                console.warn(`NotificationChoices: cannot read notification-filter.json (${FileViewError.toString(error)}), starting fresh`)
            }

            root.applyChoices('')
        }
    }

    // The notifications module writes it whenever an app sends its first notification.
    FileView {
        path: Apps.stateFolder + '/notification-apps.json'
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.applyApps(text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound) {
                console.warn(`NotificationChoices: cannot read notification-apps.json (${FileViewError.toString(error)})`)
            }

            root.applyApps('')
        }
    }

    Timer {
        id: saveTimer

        interval: 1000
        onTriggered: {
            if (root.text !== '' && root.text !== root.written) {
                root.written = root.text
                filterFile.setText(root.text)
            }
        }
    }
}
