import Quickshell
import QtQuick
import qs.modules.bar
import qs.modules.icons
import qs.modules.system
import qs.modules.tray
import qs.services

ShellRoot {
    // Read so the notification choices exist from startup and keep the notifications module's list of tray
    // icons current, even while the page is never opened.
    readonly property bool choosing: NotificationChoices.loaded

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData

            screen: modelData
        }
    }

    // One of each for the whole shell, opened from any screen's tray.
    TrayCustomize {
    }

    VolumeMixer {
    }

    AddBluetoothDevice {
    }

    EjectProblem {
    }

    IconManager {
    }
}
