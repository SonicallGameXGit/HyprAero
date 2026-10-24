import Quickshell
import QtQuick
import qs.services

ShellRoot {
    readonly property bool serving: Notifications.running
}
