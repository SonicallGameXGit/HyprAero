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

// The windows as { address, appId, title, area, width, height, floating, offScreen, preview }, biggest
// first; ties are broken by app id, then title.
function rankWindows(windows) {
    return windows
        .map(window => ({
            address: window.address,
            appId: window.appId,
            title: window.title,
            area: window.area,
            width: window.width,
            height: window.height,
            floating: window.floating,
            offScreen: window.offScreen,
            preview: window.preview,
        }))
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

// Reordering the bar's workspace buttons by dragging one along the bar, as Windows 7 reorders its taskbar
// buttons. Slots are numbered from 0, left to right.
//
// Where button `index` stands while the one from slot `from` is held over slot `to`: the held one in `to`,
// the ones between one slot over toward where it came from, the rest in their own.
function reorderSlot(index, from, to) {
    if (index === from) {
        return to
    }

    if (from < to && index > from && index <= to) {
        return index - 1
    }

    if (from > to && index >= to && index < from) {
        return index + 1
    }

    return index
}

// The slot a dragged button goes to: the one whose middle is closest to the button's middle `centre`,
// slot k's middle being `firstCentre + k * pitch`; past either end, the first or the last.
function reorderTarget(centre, firstCentre, pitch, count) {
    if (count <= 0 || pitch <= 0) {
        return 0
    }

    return Math.max(0, Math.min(Math.round((centre - firstCentre) / pitch), count - 1))
}

// The button a held one could join (its windows go there), as a browser tab dropped onto another: the other
// button it covers most where they stand now (the held one from slot `from`, holding slot `to` free), if it
// covers at least `share` of its width; -1 for none. `left` is the held button's left edge, slot 0 starting
// at 0, slots `pitch` apart, buttons `width` wide. The bar joins it only once the pointer has rested there.
function joinCandidate(left, from, to, count, pitch, width, share) {
    let best = -1
    let bestCover = 0
    for (let index = 0; index < count; index++) {
        if (index === from) {
            continue
        }

        const otherLeft = reorderSlot(index, from, to) * pitch
        const cover = Math.min(left, otherLeft) + width - Math.max(left, otherLeft)
        if (cover > bestCover) {
            best = index
            bestCover = cover
        }
    }

    return best >= 0 && bestCover >= width * share ? best : -1
}

// The renumbers (Hyprland's `change_id`, each to a free number) that move the workspace in slot `from` to
// slot `to`, the ones between one slot over toward `from`, so every workspace keeps its windows and layout.
// `ids` are the bar's workspace numbers in order, `existingIds` the ones Hyprland has (one that does not
// exist has nothing to move), `spareId` a number nothing uses, where the moved workspace waits meanwhile.
// A list of { from, to }, to be done in order; empty when nothing moves.
function reorderPlan(ids, from, to, existingIds, spareId) {
    if (from === to || from < 0 || to < 0 || from >= ids.length || to >= ids.length) {
        return []
    }

    if (existingIds.includes(ids[from]) === false || ids.includes(spareId) || existingIds.includes(spareId)) {
        return []
    }

    const steps = [{ from: ids[from], to: spareId }]
    const step = from < to ? 1 : -1
    for (let slot = from + step; slot !== to + step; slot += step) {
        if (existingIds.includes(ids[slot])) {
            steps.push({ from: ids[slot], to: ids[slot - step] })
        }
    }

    steps.push({ from: spareId, to: ids[to] })
    return steps
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

// Where a small window of the shell (the Volume Mixer) opens, as Windows 7's does: against the bottom right corner of the work area, the
// screen without the bars and panels on its edges. `monitor` is `{ x, y, width, height, reserved }` in the
// layout's own units (`reserved` is `[left, top, right, bottom]`, what layer surfaces keep free) and `size`
// the window's `{ width, height }`. A window bigger than the work area keeps its top left corner in it.
// null when the numbers are not numbers.
function cornerPosition(monitor, size) {
    const numbers = [monitor.x, monitor.y, monitor.width, monitor.height, size.width, size.height]
    // Quickshell's lists are not real arrays (`Array.isArray` says no), so only their length is checked.
    const listed = monitor.reserved !== undefined && monitor.reserved !== null && typeof monitor.reserved.length === 'number'
    const reserved = listed ? [monitor.reserved[0], monitor.reserved[1], monitor.reserved[2], monitor.reserved[3]] : [0, 0, 0, 0]
    if (listed && monitor.reserved.length < 4) {
        return null
    }

    if (numbers.concat(reserved).some(value => typeof value !== 'number' || Number.isFinite(value) === false)) {
        return null
    }

    const left = monitor.x + reserved[0]
    const top = monitor.y + reserved[1]
    return {
        x: Math.round(Math.max(left, monitor.x + monitor.width - reserved[2] - size.width)),
        y: Math.round(Math.max(top, monitor.y + monitor.height - reserved[3] - size.height)),
    }
}

// The pieces of Hyprland's `openwindow` event data, "address,workspace,class,title" (the title may hold
// commas); null when it is not that.
function parseOpenWindow(data) {
    if (typeof data !== 'string') {
        return null
    }

    const parts = data.split(',')
    if (parts.length < 4 || /^[0-9a-fA-F]+$/.test(parts[0]) === false) {
        return null
    }

    return { address: '0x' + parts[0], workspace: parts[1], className: parts[2], title: parts.slice(3).join(',') }
}
