pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import QtQuick
import 'balloons.js' as Balloons
import 'notificationIcon.js' as NotificationIcon
import 'notificationLog.js' as NotificationLog
import 'notificationText.js' as NotificationText

// The notification server: owns `org.freedesktop.Notifications` on the session bus, so the notifications apps
// send come here. Each one is kept until it closes and writes a line to the log (`notificationLog.js`, never
// the words). Which of them show as balloons, where, for how long and with what words and icon is decided
// here (`balloons.js`, `notificationText.js`, `notificationIcon.js`); `modules/Balloons.qml` draws them.
Singleton {
    id: root

    // Read by shell.qml so the singleton, and with it the server, exists from startup: a singleton is only
    // made once something reads it.
    readonly property bool running: true

    readonly property var placement: Balloons.placement(Config.balloons.position, Config.balloons.stem)
    // Every notification kept, oldest first.
    readonly property var kept: Array.from(server.trackedNotifications.values)
    // The balloons on screen, top to bottom; the rest wait their turn.
    readonly property var shown: Balloons.shown(kept, Config.balloons.maxVisible, placement.newestFirst)
    readonly property int stemIndex: Balloons.stemIndex(shown.length, placement.newestFirst)
    // The screen named in the config, else the one with the focus, else the first.
    readonly property var screen: {
        const screens = Quickshell.screens
        const focused = Hyprland.focusedMonitor === null ? '' : Hyprland.focusedMonitor.name
        for (const wanted of [Config.balloons.monitor, focused]) {
            const found = screens.find(screen => wanted !== '' && screen.name === wanted)
            if (found !== undefined) {
                return found
            }
        }

        return screens.length > 0 ? screens[0] : null
    }

    // A failure is logged by its kind only: the engine's error message can quote the words themselves.
    // The balloon then shows the words uncleaned and cut plainly rather than staying empty.
    function words(notification: Notification): var {
        try {
            return NotificationText.words(notification.summary, notification.body)
        } catch (error) {
            console.warn(`Notifications: cannot prepare the words of #${notification.id} (${error.name}), showing them as they came`)
            return { title: notification.summary.substring(0, 63), text: notification.body.substring(0, 255) }
        }
    }

    // `{ picture, name, source }`: the address of the picture sent with it, and the app's icon as one of
    // Windows' own (`name`) or a picture's address (`source`); each '' when there is none. The app's desktop
    // entry gives the icon when the notification itself names none that exists. A balloon shows both.
    function icon(notification: Notification): var {
        const found = NotificationIcon.sources(notification.image, notification.appIcon)
        let candidates = found.icons
        if (notification.desktopEntry !== '') {
            const entry = DesktopEntries.heuristicLookup(notification.desktopEntry)
            if (entry !== null) {
                candidates = candidates.concat(NotificationIcon.candidates(entry.icon))
            }
        }

        for (const candidate of candidates) {
            if (candidate.kind === 'windows') {
                return { picture: found.picture, name: candidate.name, source: '' }
            }

            if (candidate.kind === 'url') {
                return { picture: found.picture, name: '', source: candidate.url }
            }

            const path = Quickshell.iconPath(candidate.name, true)
            if (path !== '') {
                return { picture: found.picture, name: '', source: path }
            }
        }

        return { picture: found.picture, name: '', source: '' }
    }

    // How long its balloon stays, in milliseconds; 0 is until it is closed.
    function timeout(notification: Notification): int {
        return Balloons.timeout(notification.expireTimeout, notification.urgency === NotificationUrgency.Critical, Config.balloons.timeout)
    }

    function actionsOf(notification: Notification): var {
        return Array.from(notification.actions).map(action => ({ identifier: action.identifier, text: action.text }))
    }

    // `[{ index, text }]`: the actions shown as buttons, every one of them, the first the main one.
    function buttons(notification: Notification): var {
        return Balloons.buttons(actionsOf(notification))
    }

    // A click on the balloon: the app's "default" action when it has one, else the balloon just closes.
    function activate(notification: Notification): void {
        const index = Balloons.defaultAction(actionsOf(notification))
        if (index === -1) {
            notification.dismiss()
            return
        }

        notification.actions[index].invoke()
    }

    // Closes it too, unless the app made it resident.
    function invoke(notification: Notification, index: int): void {
        notification.actions[index].invoke()
    }

    NotificationServer {
        id: server

        actionsSupported: true
        imageSupported: true
        // Windows 7's balloons show plain text; markup sent anyway is cleaned (`notificationText.js`).
        bodyMarkupSupported: false
        onNotification: notification => {
            console.info('Notifications: ' + NotificationLog.describe({
                id: notification.id,
                appName: notification.appName,
                urgency: notification.urgency,
                summaryLength: notification.summary.length,
                bodyLength: notification.body.length,
                actionCount: notification.actions.length,
                hasImage: notification.image !== '',
            }))
            notification.tracked = true
        }
    }
}
