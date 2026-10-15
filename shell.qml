import Quickshell
import QtQuick
import qs.modules.bar
import qs.modules.tray

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData

            screen: modelData
        }
    }

    // One for the whole shell, opened from any screen's tray.
    TrayCustomize {
    }
}
