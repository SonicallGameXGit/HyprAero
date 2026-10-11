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

// Whether `address` looks like a Hyprland window address (`0x` and hex digits). Addresses go into
// dispatchers, which are Lua code, so nothing else may get through.
function isWindowAddress(address) {
    return typeof address === 'string' && /^0x[0-9a-fA-F]+$/.test(address)
}

// The text as one word for `sh`: in single quotes, where nothing is special, and each `'` closed, escaped
// and reopened.
function shellQuote(text) {
    return '\'' + text.split('\'').join('\'\\\'\'') + '\''
}

// The text as a Lua string literal. Every character that could end the literal or change what follows
// (the quote, the backslash, line breaks and other control characters) is escaped, so the text can never
// be read as Lua code. Control characters use three-digit escapes, so a digit after one cannot join it.
function luaString(text) {
    let result = '\''
    for (const character of text) {
        const code = character.codePointAt(0)
        if (character === '\\' || character === '\'') {
            result += '\\' + character
        } else if (code < 32 || code === 127) {
            result += '\\' + String(code).padStart(3, '0')
        } else {
            result += character
        }
    }

    return result + '\''
}

// The dispatcher that has Hyprland start `command` (a list of arguments, no field codes) so its first
// window opens on workspace `workspaceId` while the view stays where it is. Hyprland runs it with `sh`
// and ties the window to the process it started. '' when there is nothing valid to start.
function startOnWorkspace(command, workingDirectory, workspaceId) {
    if (command.length === 0 || Number.isInteger(workspaceId) === false || workspaceId <= 0) {
        return ''
    }

    // `exec` keeps the app in the process Hyprland started, so the window still belongs to it.
    const run = 'exec ' + command.map(shellQuote).join(' ')
    const shellText = workingDirectory === '' ? run : `cd ${shellQuote(workingDirectory)} && ${run}`
    return `hl.dsp.exec_cmd(${luaString(shellText)}, { workspace = '${workspaceId} silent' })`
}

// The workspace a window dragged out of the bar goes to when dropped, or 0 for none (nothing happens).
// `x` is the pointer's position along the bar, `away` how far it is from the bar toward the middle of the
// screen (0 or less: on the bar). `slots` are the workspace buttons in bar order, as
// [{ id, left, right, empty }] with `left` / `right` in the same coordinates as `x`.
//
// Near the bar the pointer counts as on it, so it need not be aimed exactly: within `near.buttons` over
// the buttons it picks the closest one; within `near.sides` before the first button the leftmost
// workspace without windows, past the last one the rightmost. The sides reach further, so a drop toward a
// corner is easy, while the middle stays short so "up" is quick to reach. Anywhere else it picks the
// lowest workspace without windows. No such workspace: 0.
function dropWorkspace(x, away, slots, near) {
    if (slots.length === 0) {
        return 0
    }

    const free = slots.filter(slot => slot.empty)
    const lowestFree = free.length > 0 ? free[0].id : 0
    const beforeButtons = x < slots[0].left
    const pastButtons = x > slots[slots.length - 1].right
    const reach = beforeButtons || pastButtons ? near.sides : near.buttons
    if (away > reach || beforeButtons) {
        return lowestFree
    }

    if (pastButtons) {
        return free.length > 0 ? free[free.length - 1].id : 0
    }

    let closest = slots[0]
    let closestDistance = Infinity
    for (const slot of slots) {
        const distance = Math.max(slot.left - x, x - slot.right, 0)
        if (distance < closestDistance) {
            closest = slot
            closestDistance = distance
        }
    }

    return closest.id
}

// How every window of workspace `fromId` goes to workspace `toId`. `existingIds` are the workspaces
// Hyprland has right now (an empty one exists only while it is shown somewhere).
//
// - 'renumber': the target does not exist, so the source workspace just takes its id; layout, positions,
//   sizes and order stay exactly as they are.
// - 'renumberAndStay': the same, but the source is the one on screen; the view then goes back to the old
//   id, so it stays on the number it was on, as when a single window is moved away.
// - 'showThenRenumber': the target is the empty workspace on screen. Showing the source first lets
//   Hyprland drop the empty one, then the source takes its id; the view ends on the number it was on.
// - 'moveWindows': the target exists with windows (or empty on another monitor): the windows are moved
//   one by one and Hyprland places them among the ones already there.
// - 'none': nothing to move, or the same workspace.
function workspaceMovePlan(fromId, toId, fromHasWindows, toHasWindows, existingIds, focusedId) {
    if (fromId <= 0 || toId <= 0 || fromId === toId || fromHasWindows === false) {
        return 'none'
    }

    if (existingIds.includes(toId) === false) {
        return fromId === focusedId ? 'renumberAndStay' : 'renumber'
    }

    if (toHasWindows === false && toId === focusedId) {
        return 'showThenRenumber'
    }

    return 'moveWindows'
}

// The number of a workspace as Quickshell reports it. Quickshell 0.3.2 gives a workspace it has only
// heard of by name (as after a renumber) the id -1 until its next full refresh, which may never come;
// its name is then the number Hyprland gave it. A renamed workspace has a real id, so this only matters
// for those placeholders. Still unknown: -1.
function workspaceNumber(id, name) {
    if (id > 0) {
        return id
    }

    if (typeof name === 'string' && /^[0-9]+$/.test(name)) {
        return Number(name)
    }

    return -1
}
