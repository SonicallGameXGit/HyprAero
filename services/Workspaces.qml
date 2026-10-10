pragma Singleton

import Quickshell
import Quickshell.Hyprland
import QtQuick
import 'workspaceList.js' as WorkspaceList

// What the bar shows and how it switches. All Hyprland access for workspaces stays in here.
Singleton {
    id: root

    readonly property int minimumCount: 10
    readonly property int focusedId: {
        const focused = Hyprland.focusedWorkspace
        if (focused === null) {
            return 1
        }

        return focused.id
    }
    readonly property var entries: WorkspaceList.buildEntries(
        Hyprland.workspaces.values.map(workspace => ({ id: workspace.id })),
        focusedId,
        minimumCount,
    )

    // Hyprland 0.56 with a Lua config takes Lua dispatchers here; the old 'workspace N' text is rejected.
    function switchTo(id: int): void {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`)
    }
}
