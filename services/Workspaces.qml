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
                // Names the window when focusing or closing it; '' when Hyprland gave none.
                address: typeof info.address === 'string' ? info.address : '',
                appId: info.class,
                title: typeof info.title === 'string' ? info.title : '',
                area: size[0] * size[1],
                width: size[0],
                height: size[1],
                // Hyprland leaves the part of a window outside its monitor blank in the capture.
                offScreen: WorkspaceList.hangsOffMonitor(info.at, size, monitorRect(toplevel.monitor)),
                // The Wayland handle the live preview captures; null when the compositor has none.
                preview: toplevel.wayland,
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

    // The monitor's rectangle in layout (logical) coordinates, or null when it is unknown.
    function monitorRect(monitor: var): var {
        if (monitor === null || monitor === undefined || monitor.scale <= 0) {
            return null
        }

        return {
            x: monitor.x,
            y: monitor.y,
            width: monitor.width / monitor.scale,
            height: monitor.height / monitor.scale,
        }
    }

    // Hyprland 0.56 with a Lua config takes Lua dispatchers here; the old 'workspace N' text is rejected.
    function switchTo(id: int): void {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`)
    }

    function switchToFirstEmpty(): void {
        switchTo(WorkspaceList.firstEmptyWorkspace(entries))
    }

    // The window with this address, or null when it is gone.
    function toplevelAt(address: string): var {
        for (const toplevel of Hyprland.toplevels.values) {
            const info = toplevel.lastIpcObject
            if (info !== null && info !== undefined && info.address === address) {
                return toplevel
            }
        }

        return null
    }

    // Goes to the window's workspace and focuses it; the pointer stays where it is. The address is checked
    // before it goes into the dispatcher, which is Lua code.
    function focusWindow(address: string): void {
        if (toplevelAt(address) === null || /^0x[0-9a-fA-F]+$/.test(address) === false) {
            console.warn(`Workspaces: no window ${address} to focus`)
            return
        }

        Hyprland.dispatch(`hl.dsp.focus({ window = 'address:${address}' })`)
    }

    // Asks the window to close, as its own close button would: the app may ask to save, or refuse. Goes
    // through the window's own Wayland handle, so it can only ever reach that window.
    function closeWindow(address: string): void {
        const toplevel = toplevelAt(address)
        if (toplevel === null || toplevel.wayland === null) {
            console.warn(`Workspaces: no window ${address} to close`)
            return
        }

        toplevel.wayland.close()
    }
}
