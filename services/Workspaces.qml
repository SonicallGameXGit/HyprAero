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
    readonly property var windows: {
        const result = []
        for (const toplevel of Hyprland.toplevels.values) {
            const workspace = toplevel.workspace
            const info = toplevel.lastIpcObject
            if (workspace === null || info === null || info === undefined) {
                continue
            }

            const size = info.size
            if (typeof info.class !== 'string' || info.class === '' || size === undefined || size.length < 2) {
                continue
            }

            result.push({
                workspaceId: workspace.id,
                appId: info.class,
                area: size[0] * size[1],
            })
        }

        return result
    }
    readonly property var entries: WorkspaceList.buildEntries(
        Hyprland.workspaces.values.map(workspace => workspace.id),
        windows,
        focusedId,
        minimumCount,
    )

    // Hyprland only tells us about opened / closed / moved windows; resizes arrive as raw events.
    // Refreshing (debounced) keeps the window sizes behind the icon order current.
    Connections {
        target: Hyprland

        function onRawEvent(): void {
            refreshTimer.restart()
        }
    }

    Timer {
        id: refreshTimer

        interval: 200
        onTriggered: Hyprland.refreshToplevels()
    }

    // Hyprland 0.56 with a Lua config takes Lua dispatchers here; the old 'workspace N' text is rejected.
    function switchTo(id: int): void {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`)
    }
}
