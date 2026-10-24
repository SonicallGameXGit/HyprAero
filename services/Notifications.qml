pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import 'notificationLog.js' as NotificationLog

// The notification server: owns `org.freedesktop.Notifications` on the session bus, so the notifications apps
// send come here. For now it only writes a line about each one to the log (`notificationLog.js`, never the
// words); nothing is shown and nothing is kept. The balloons come next.
Singleton {
    id: root

    // Read by shell.qml so the singleton, and with it the server, exists from startup: a singleton is only
    // made once something reads it.
    readonly property bool running: true

    NotificationServer {
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
        }
    }
}
