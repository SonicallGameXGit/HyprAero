.pragma library

// Decides which workspace buttons the bar shows and which app icons each one gets. Plain JS, no
// Quickshell imports, so node can test it.
//
// Buttons: the first `minimumCount` ids are always shown, plus every other regular workspace that
// currently exists or has focus. Special workspaces (id <= 0) are never listed.
//
// Icons: windows are grouped by app; an app counts with its biggest window. The biggest app is the
// main icon and the second biggest is the small badge. No windows: both are null (the bar draws a dot).
// `windows` is [{ workspaceId, appId, title, area }]. Each entry also carries its own `windows`, biggest
// first, for the hover list.
function buildEntries(workspaceIds, windows, focusedId, minimumCount) {
    const occupied = new Set()
    for (const id of workspaceIds) {
        if (id > 0) {
            occupied.add(id)
        }
    }

    const ids = new Set()
    for (let id = 1; id <= minimumCount; id++) {
        ids.add(id)
    }
    for (const id of occupied) {
        ids.add(id)
    }
    if (focusedId > 0) {
        ids.add(focusedId)
    }

    const sorted = Array.from(ids).sort((a, b) => a - b)
    return sorted.map(id => {
        const own = windows.filter(window => window.workspaceId === id)
        const apps = rankApps(own)
        return {
            id: id,
            focused: id === focusedId,
            occupied: occupied.has(id) || apps.length > 0,
            mainApp: apps.length > 0 ? apps[0] : null,
            secondApp: apps.length > 1 ? apps[1] : null,
            windows: rankWindows(own),
        }
    })
}

// App ids of the given windows, biggest app first; ties are broken by name so the order is stable.
function rankApps(windows) {
    const biggest = new Map()
    for (const window of windows) {
        const known = biggest.get(window.appId)
        if (known === undefined || window.area > known) {
            biggest.set(window.appId, window.area)
        }
    }

    return Array.from(biggest.entries())
        .sort((a, b) => b[1] - a[1] || (a[0] < b[0] ? -1 : 1))
        .map(entry => entry[0])
}

// The windows as { address, appId, title, area, width, height, offScreen, preview }, biggest first; ties are broken by app id, then title.
function rankWindows(windows) {
    return windows
        .map(window => ({ address: window.address, appId: window.appId, title: window.title, area: window.area, width: window.width, height: window.height, offScreen: window.offScreen, preview: window.preview }))
        .sort((a, b) => b.area - a.area || compareText(a.appId, b.appId) || compareText(a.title, b.title))
}

function compareText(a, b) {
    if (a === b) {
        return 0
    }

    return a < b ? -1 : 1
}

// Whether any part of a window lies outside its monitor. `at` is [x, y] and `size` is [width, height] of
// the window, `monitor` is { x, y, width, height } in the same (logical) coordinates, or null when unknown.
// Unknown counts as on screen.
function hangsOffMonitor(at, size, monitor) {
    if (monitor === null || at === undefined || at.length < 2) {
        return false
    }

    return at[0] < monitor.x
        || at[1] < monitor.y
        || at[0] + size[0] > monitor.x + monitor.width
        || at[1] + size[1] > monitor.y + monitor.height
}

// The workspace the "empty workspace" button goes to: the lowest listed one without windows, or the one
// after the highest when every listed workspace has windows. `entries` is what `buildEntries` returns.
function firstEmptyWorkspace(entries) {
    let highest = 0
    for (const entry of entries) {
        if (entry.windows.length === 0) {
            return entry.id
        }

        highest = Math.max(highest, entry.id)
    }

    return highest + 1
}
