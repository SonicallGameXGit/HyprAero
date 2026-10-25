import Quickshell
import QtQuick
import qs.design

// The companion: what the frames need that QML draws better (the window menu, the buttons' tooltips) and the
// tokens it hands the plugin (AGENTS.md section 7). For now it only proves it runs with the design.
ShellRoot {
    Component.onCompleted: {
        console.info('Frames: companion started, theme ' + (Theme.slate ? 'Slate' : 'Aero'))
    }
}
