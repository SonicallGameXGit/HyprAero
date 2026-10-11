pragma Singleton

import Quickshell
import Quickshell.Hyprland
import QtQuick
import 'workspaceList.js' as WorkspaceList

// What the bar shows and how it switches. All Hyprland access for workspaces stays in here.
Singleton {
    id: root

    readonly property int minimumCount: 10
    // The format of a window dragged out of the bar: its address. Private to the shell, so dropping it on
    // an app (a text field, a browser) does nothing there.
    readonly property string windowDragFormat: 'application/x-hypraero-window'
    // The same for a whole workspace dragged out of the bar: its id.
    readonly property string workspaceDragFormat: 'application/x-hypraero-workspace'
    // Workspace numbers never come straight from Quickshell's objects: after a renumber they can be
    // placeholders with the id -1, or old objects that are gone in Hyprland (see `onRawEvent` below).
    readonly property int focusedId: {
        const focused = Hyprland.focusedWorkspace
        if (focused === null) {
            return 1
        }

        const number = WorkspaceList.workspaceNumber(focused.id, focused.name)
        return number > 0 ? number : 1
    }
    readonly property var windows: {
        const result = []
        for (const toplevel of Hyprland.toplevels.values) {
            const info = toplevel.lastIpcObject
            if (info === null || info === undefined) {
                continue
            }

            const size = info.size
            if (typeof info.class !== 'string' || info.class === '' || size === undefined || size.length < 2) {
                continue
            }

            const workspaceId = windowWorkspaceId(toplevel.workspace, info)
            if (workspaceId === 0) {
                continue
            }

            result.push({
                workspaceId: workspaceId,
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
    // The workspaces that really exist in Hyprland: the ones with windows, the ones shown on a monitor and
    // the focused one (an empty workspace exists only while it is shown). Quickshell's own list can keep a
    // workspace that was renumbered away.
    readonly property var existingIds: {
        const ids = new Set(windows.map(window => window.workspaceId))
        for (const workspace of Hyprland.workspaces.values) {
            if (workspace.active) {
                ids.add(WorkspaceList.workspaceNumber(workspace.id, workspace.name))
            }
        }
        ids.add(focusedId)

        return Array.from(ids).filter(id => id > 0)
    }
    readonly property var entries: WorkspaceList.buildEntries(
        existingIds,
        windows,
        focusedId,
        minimumCount,
    )

    // Hyprland only tells us about opened / closed / moved windows; resizes arrive as raw events.
    // Refreshing (debounced) keeps the window sizes behind the icon order current.
    //
    // Quickshell 0.3.2 does not follow a workspace getting a new id (`changeworkspaceid`): it matches
    // workspaces by id, so the renumbered workspace is unknown to it and the old object stays. Re-reading
    // the windows and monitors at once links them to the new number (both look the workspace up by name
    // and create a placeholder if needed, numbered by `workspaceNumber`). Its own workspace refresh is not
    // used: from QML it can neither create nor drop a workspace, and it may answer before the placeholder
    // exists, so it would fix nothing.
    Connections {
        target: Hyprland

        function onRawEvent(event: var): void {
            if (event.name === 'changeworkspaceid') {
                Hyprland.refreshMonitors()
                Hyprland.refreshToplevels()
            }

            refreshTimer.restart()
        }
    }

    Timer {
        id: refreshTimer

        interval: 200
        onTriggered: Hyprland.refreshToplevels()
    }

    // The number of a window's workspace (0: unknown). Quickshell's workspace first, as it follows window
    // moves at once; when that is a placeholder without a usable number (or gone), Hyprland's own record of
    // the window, which the last window refresh brought.
    function windowWorkspaceId(workspace: var, info: var): int {
        if (workspace !== null && workspace !== undefined) {
            const number = WorkspaceList.workspaceNumber(workspace.id, workspace.name)
            if (number > 0) {
                return number
            }
        }

        const own = info.workspace
        if (own !== undefined && own !== null && typeof own.id === 'number' && own.id > 0) {
            return own.id
        }

        return 0
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
        if (toplevelAt(address) === null || WorkspaceList.isWindowAddress(address) === false) {
            console.warn(`Workspaces: no window ${address} to focus`)
            return
        }

        Hyprland.dispatch(`hl.dsp.focus({ window = 'address:${address}' })`)
    }

    // Moves the window to another workspace (created if needed) and leaves the view where it is.
    // `follow = false` is what keeps the view: the old `silent = true` is ignored and the view followed.
    function moveWindow(address: string, workspaceId: int): void {
        const toplevel = toplevelAt(address)
        if (toplevel === null || WorkspaceList.isWindowAddress(address) === false || workspaceId <= 0) {
            console.warn(`Workspaces: cannot move window ${address} to workspace ${workspaceId}`)
            return
        }

        const info = toplevel.lastIpcObject
        if (info !== null && info !== undefined && windowWorkspaceId(toplevel.workspace, info) === workspaceId) {
            return
        }

        Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${workspaceId}, window = 'address:${address}', follow = false })`)
    }

    // Moves every window of one workspace to another (`WorkspaceList.workspaceMovePlan` decides how).
    // Renumbering keeps the workspace itself, so its layout stays exactly as it was; it needs the target
    // number to be free, which Hyprland checks again (`change_id` refuses a taken id).
    function moveWorkspace(fromId: int, toId: int): void {
        const own = windows.filter(window => window.workspaceId === fromId)
        const plan = WorkspaceList.workspaceMovePlan(
            fromId,
            toId,
            own.length > 0,
            windows.some(window => window.workspaceId === toId),
            existingIds,
            focusedId,
        )
        const renumber = `hl.dsp.workspace.change_id({ workspace = ${fromId}, id = ${toId} })`
        if (plan === 'renumber') {
            Hyprland.dispatch(renumber)
            return
        }

        if (plan === 'renumberAndStay') {
            Hyprland.dispatch(renumber)
            switchTo(fromId)
            return
        }

        if (plan === 'showThenRenumber') {
            switchTo(fromId)
            Hyprland.dispatch(renumber)
            return
        }

        if (plan === 'moveWindows') {
            // Biggest first, the order of the hover list.
            for (const window of WorkspaceList.rankWindows(own)) {
                moveWindow(window.address, toId)
            }
        }
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
