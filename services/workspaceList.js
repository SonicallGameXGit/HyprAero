.pragma library

// Decides which workspace buttons the bar shows and which app icons each one gets. Plain JS, no
// Quickshell imports, so node can test it.
//
// Buttons: the first `minimumCount` ids are always shown, plus every other regular workspace that
// currently exists or has focus. Special workspaces (id <= 0) are never listed.
//
// Icons: windows are grouped by app; an app counts with its biggest window. The biggest app is the
// main icon and the second biggest is the small badge. No windows: both are null (the bar draws a dot).
// `windows` is [{ workspaceId, appId, area }].
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
        const apps = rankApps(windows.filter(window => window.workspaceId === id))
        return {
            id: id,
            focused: id === focusedId,
            occupied: occupied.has(id) || apps.length > 0,
            mainApp: apps.length > 0 ? apps[0] : null,
            secondApp: apps.length > 1 ? apps[1] : null,
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
