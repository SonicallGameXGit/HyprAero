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
                // Outside the tiling layout, moved and sized freely.
                floating: info.floating === true,
                // Hyprland's focus history: 0 is the window focused last (it is drawn on top of its kind).
                focusOrder: typeof info.focusHistoryID === 'number' ? info.focusHistoryID : 0,
                fullscreen: typeof info.fullscreen === 'number' && info.fullscreen > 0,
                // Top-left corner and the monitor's rectangle, both in layout coordinates (null: unknown).
                at: info.at !== undefined && info.at !== null && info.at.length >= 2 ? { x: info.at[0], y: info.at[1] } : null,
                monitor: monitorRect(toplevel.monitor),
                // Hyprland leaves the part of a window outside its monitor blank in the capture.
                offScreen: WorkspaceList.hangsOffMonitor(info.at, size, monitorRect(toplevel.monitor)),
                // The Wayland handle the live preview captures; null when the compositor has none.
                preview: toplevel.wayland,
            })
        }

        return result
    }
    // The workspaces shown on a monitor right now.
    readonly property var shownIds: {
        const ids = []
        for (const workspace of Hyprland.workspaces.values) {
            if (workspace.active) {
                ids.push(WorkspaceList.workspaceNumber(workspace.id, workspace.name))
            }
        }

        return ids
    }
    // The workspaces that really exist in Hyprland: the ones with windows, the ones shown on a monitor and
    // the focused one (an empty workspace exists only while it is shown). Quickshell's own list can keep a
    // workspace that was renumbered away.
    readonly property var existingIds: {
        const ids = new Set(windows.map(window => window.workspaceId))
        for (const id of shownIds) {
            ids.add(id)
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
    // Windows the shell asked to close (addresses); their previews stop capturing before the request goes
    // out. Hyprland 0.56 ignores a request for a frame of a window it has just dropped without creating
    // the frame, and when Quickshell then destroys that frame Hyprland ends the shell's Wayland connection
    // ("invalid object", the whole shell is gone). A live preview asks for the next frame right after each
    // one arrives, so it is very likely to hit that moment when its window closes. Wayland requests are
    // handled in order, so with the capture stopped first no request can come after the window. Kept for
    // `closingHold` only: an app may ask to save or refuse, and its preview then goes live again. Long, as
    // some apps take seconds to go.
    property var closingAddresses: []
    property string cornerTitle: ''
    property string cornerAddress: ''
    property int cornerTries: 0
    readonly property int closingHold: 10000

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

            if (event.name === 'openwindow' && cornerTitle !== '') {
                const opened = WorkspaceList.parseOpenWindow(event.data)
                if (opened !== null && opened.title.startsWith(cornerTitle)) {
                    cornerTitle = ''
                    cornerAddress = opened.address
                    cornerTries = 0
                    cornerTimer.restart()
                }
            }

            refreshTimer.restart()
        }
    }

    Timer {
        id: refreshTimer

        interval: 200
        onTriggered: Hyprland.refreshToplevels()
    }

    // The window to put in the corner of the work area once it is known to Hyprland (`placeNextInCorner`).
    // Its record arrives a moment after the `openwindow` event, and a window that opens tiled is floated
    // first and placed on the next tick, once its own size is known.
    Timer {
        id: cornerTimer

        interval: 100
        repeat: true
        onTriggered: {
            root.cornerTries++
            Hyprland.refreshToplevels()
            if (root.cornerTries > 1 && (root.placeInCorner(root.cornerAddress) !== 'waiting' || root.cornerTries >= 12)) {
                stop()
            }
        }
    }

    Timer {
        id: closingTimer

        interval: root.closingHold
        onTriggered: root.closingAddresses = []
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

    // The rectangle of the monitor with this name (a Quickshell screen's name), in layout coordinates, or
    // null when it is unknown. Its width over a layer's own width is how many layout pixels one Qt unit is
    // (more than 1 when the shell runs with a QT_SCALE_FACTOR below 1, less above it).
    function monitorRectNamed(name: string): var {
        for (const monitor of Hyprland.monitors.values) {
            if (monitor.name === name) {
                return monitorRect(monitor)
            }
        }

        return null
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

    // Moves the workspace in slot `from` of the bar's `ids` to slot `to`, the ones between one slot over, by
    // renumbering them (`WorkspaceList.reorderPlan`), so each keeps its windows and layout and the view stays
    // on what it shows. The moved one waits on a number past every one in use.
    function reorder(ids: var, from: int, to: int): void {
        const spare = Math.max(...ids, ...existingIds) + 1
        const steps = WorkspaceList.reorderPlan(ids, from, to, existingIds, spare)
        for (const step of steps) {
            Hyprland.dispatch(`hl.dsp.workspace.change_id({ workspace = ${step.from}, id = ${step.to} })`)
        }
    }

    // The next window whose title starts with `titleStart` opens against the bottom right corner of the work
    // area (the screen without what the bars keep free) of its monitor, as Windows 7's Volume Mixer does.
    // Floating windows only: a tiled one is floated first.
    function placeNextInCorner(titleStart: string): void {
        cornerTitle = titleStart
    }

    // Moves the floating window there; 'waiting' when it has to be floated first (the caller tries again
    // once Hyprland has re-read it), 'failed' when it is not known or its numbers are not usable.
    function placeInCorner(address: string): string {
        const toplevel = toplevelAt(address)
        if (toplevel === null || WorkspaceList.isWindowAddress(address) === false) {
            return 'waiting'
        }

        const info = toplevel.lastIpcObject
        const rect = monitorRect(toplevel.monitor)
        if (info === null || info === undefined || rect === null || info.size === undefined || info.size === null || info.size.length < 2) {
            return 'failed'
        }

        if (info.floating !== true) {
            setFloating(address, true)
            return 'waiting'
        }

        const monitorInfo = toplevel.monitor.lastIpcObject
        const reserved = monitorInfo === null || monitorInfo === undefined ? undefined : monitorInfo.reserved
        const spot = WorkspaceList.cornerPosition(
            { x: rect.x, y: rect.y, width: rect.width, height: rect.height, reserved: reserved },
            { width: info.size[0], height: info.size[1] },
        )
        if (spot === null) {
            return 'failed'
        }

        Hyprland.dispatch(`hl.dsp.window.move({ x = ${spot.x}, y = ${spot.y}, window = 'address:${address}' })`)
        return 'done'
    }

    // Takes the window out of the tiling layout (`on`), free to move and resize, or puts it back in.
    function setFloating(address: string, on: bool): void {
        if (toplevelAt(address) === null || WorkspaceList.isWindowAddress(address) === false) {
            console.warn(`Workspaces: no window ${address} to float or tile`)
            return
        }

        Hyprland.dispatch(`hl.dsp.window.float({ action = '${on ? 'set' : 'unset'}', window = 'address:${address}' })`)
    }

    // Has Hyprland start `command` so the app's window opens on workspace `workspaceId` (created if needed)
    // and the view stays where it is. Only Hyprland can do that: it ties the first window to the process it
    // started. An app that hands the start to an instance already running (some browsers) opens its window
    // there instead, as with Hyprland's own exec rules.
    function startOn(command: list<string>, workingDirectory: string, workspaceId: int): void {
        const dispatch = WorkspaceList.startOnWorkspace(command, workingDirectory, workspaceId)
        if (dispatch === '') {
            console.warn(`Workspaces: cannot start ${command.join(' ')} on workspace ${workspaceId}`)
            return
        }

        Hyprland.dispatch(dispatch)
    }

    // Asks the window to close, as its own close button would: the app may ask to save, or refuse. Goes
    // through the window's own Wayland handle, so it can only ever reach that window.
    function closeWindow(address: string): void {
        const toplevel = toplevelAt(address)
        if (toplevel === null || toplevel.wayland === null) {
            console.warn(`Workspaces: no window ${address} to close`)
            return
        }

        // Stops its previews at once (the bindings follow synchronously), before the close is sent.
        if (closingAddresses.includes(address) === false) {
            closingAddresses = closingAddresses.concat([address])
        }
        closingTimer.restart()
        toplevel.wayland.close()
    }
}
