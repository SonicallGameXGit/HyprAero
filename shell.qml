import Quickshell
import QtQuick
import qs.modules
import qs.services

ShellRoot {
    readonly property bool serving: Notifications.running
    readonly property bool filtering: NotificationApps.running

    BalloonWindow {}
}
