import Quickshell
import QtQuick
import qs.modules
import qs.services

ShellRoot {
    readonly property bool serving: Notifications.running

    BalloonWindow {}
}
