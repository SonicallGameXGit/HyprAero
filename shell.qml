import Quickshell
import QtQuick
import qs.modules.bar
import qs.modules.icons
import qs.modules.system
import qs.modules.tray

ShellRoot {
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
