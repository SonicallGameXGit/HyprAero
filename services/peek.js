.pragma library

// The decisions of the window peek (hovering a preview card long enough shows that window on its own,
// almost full screen). Plain JS, no Quickshell imports, so node can test it.

// Whether peeking at `window` shows anything new. A window that is the only one on a workspace that is on
// screen, and sits in the layout (so it already fills the screen), has nothing hidden to reveal.
// `windows` is the list of `Workspaces.windows`, `shownIds` the numbers of the workspaces on a monitor.
function worthPeeking(window, windows, shownIds) {
    if (window === undefined || window === null) {
        return false
    }

    if (window.floating || shownIds.includes(window.workspaceId) === false) {
        return true
    }

    return windows.some(other => other.workspaceId === window.workspaceId && other.address !== window.address)
}

// Where the peeked window goes inside an area of `area.width` x `area.height`: its picture keeps the
// window's proportions and grows as far as the area less `margin` on every side allows, less the frame's
// `chrome` (`border` on every side and `title` along the top). Returns the frame and the picture inside
// it, both relative to the area.
function peekLayout(aspect, area, margin, chrome) {
    const usableWidth = area.width - margin * 2 - chrome.border * 2
    const usableHeight = area.height - margin * 2 - chrome.border * 2 - chrome.title
    if (aspect <= 0 || usableWidth <= 0 || usableHeight <= 0) {
        return null
    }

    const width = Math.floor(Math.min(usableWidth, usableHeight * aspect))
    const height = Math.floor(width / aspect)
    const frameWidth = width + chrome.border * 2
    const frameHeight = height + chrome.border * 2 + chrome.title
    const frameX = Math.floor((area.width - frameWidth) / 2)
    const frameY = Math.floor((area.height - frameHeight) / 2)

    return {
        frame: { x: frameX, y: frameY, width: frameWidth, height: frameHeight },
        picture: { x: frameX + chrome.border, y: frameY + chrome.border + chrome.title, width: width, height: height },
    }
}

// How the peeked window is shown. 'fit': a window that fills the screen anyway (fullscreen, or the only
// tiled one of its workspace) is lifted out almost full screen in a glass frame. 'place': every other one
// (floating, or tiled beside others, so smaller than the screen) appears exactly where it is and at its
// real size, alone on the backdrop.
function peekMode(window, windows) {
    if (window.fullscreen) {
        return 'fit'
    }

    const alone = windows.every(other => other.workspaceId !== window.workspaceId || other.address === window.address)
    if (window.floating === false && alone) {
        return 'fit'
    }

    return window.at !== null && window.monitor !== null ? 'place' : 'fit'
}

// The window's own rectangle relative to its monitor's top-left corner (the layer starts there).
function peekPlace(window) {
    return {
        x: window.at.x - window.monitor.x,
        y: window.at.y - window.monitor.y,
        width: window.width,
        height: window.height,
    }
}

// Whether peeking at a whole workspace shows anything: it has windows and is not on a monitor already.
function worthPeekingWorkspace(workspaceId, windows, shownIds) {
    return shownIds.includes(workspaceId) === false && windows.some(window => window.workspaceId === workspaceId)
}

// The part of a window that lies on its monitor, relative to the monitor's top-left corner (in Hyprland's
// layout pixels), or null when none does or its place is unknown. A window hanging off the monitor is only
// drawn there.
function visibleRect(window) {
    if (window.at === null || window.monitor === null) {
        return null
    }

    const left = Math.max(window.at.x - window.monitor.x, 0)
    const top = Math.max(window.at.y - window.monitor.y, 0)
    const right = Math.min(window.at.x - window.monitor.x + window.width, window.monitor.width)
    const bottom = Math.min(window.at.y - window.monitor.y + window.height, window.monitor.height)
    if (right <= left || bottom <= top) {
        return null
    }

    return { x: left, y: top, width: right - left, height: bottom - top }
}

// The windows in the order Hyprland draws them, the one on top last: tiled ones under floating ones, and
// inside each group the longest unfocused first (`focusOrder` is Hyprland's focus history, 0 the latest).
function stackOrder(windows) {
    const rank = window => (window.floating ? 1 : 0)
    return windows.slice().sort((first, second) => {
        if (rank(first) !== rank(second)) {
            return rank(first) - rank(second)
        }

        if (first.focusOrder !== second.focusOrder) {
            return second.focusOrder - first.focusOrder
        }

        return first.address < second.address ? -1 : 1
    })
}

// What the peek draws for `target` (`{ kind: 'window', address }` or `{ kind: 'workspace', workspaceId }`),
// or null when there is nothing to show.
//   mode 'fit': the window alone, lifted out almost full screen in a glass frame.
//   mode 'compose': the windows of a workspace each where it is, `highlight` (one of them, or null) on top.
// `base` is 'backdrop' when the workspace is not on screen (the Aero backdrop stands in for what the real
// workspace would show), 'none' when it is (what is really there shows through). With `scrim` everything
// but the highlighted window is darkened. `windows` is what is drawn under the highlight; of a workspace
// already on screen it is empty, the real windows are there.
function peekScene(target, windows, shownIds) {
    if (target.kind === 'window') {
        const window = windows.find(item => item.address === target.address)
        if (window === undefined) {
            return null
        }

        const shown = shownIds.includes(window.workspaceId)
        const base = shown ? 'none' : 'backdrop'
        if (peekMode(window, windows) === 'fit') {
            return { mode: 'fit', base: base, scrim: true, windows: [], highlight: window }
        }

        const under = shown
            ? []
            : stackOrder(windows.filter(item => item.workspaceId === window.workspaceId && item.address !== window.address))
        return { mode: 'compose', base: base, scrim: true, windows: under, highlight: window }
    }

    if (target.kind === 'workspace' && worthPeekingWorkspace(target.workspaceId, windows, shownIds)) {
        const own = windows.filter(item => item.workspaceId === target.workspaceId)
        return { mode: 'compose', base: 'backdrop', scrim: false, windows: stackOrder(own), highlight: null }
    }

    return null
}

// A string that is the same while what is drawn is the same, so a refresh of the window list that changed
// nothing does not start a fade.
function sceneKey(scene) {
    if (scene === null) {
        return ''
    }

    const part = window => [
        window.address,
        window.at === null ? '' : window.at.x + ',' + window.at.y,
        window.width + 'x' + window.height,
        window.fullscreen ? 'f' : '',
    ].join(':')
    const own = scene.highlight === null ? '' : part(scene.highlight)
    return [scene.mode, scene.base, scene.scrim, own, scene.windows.map(part).join(';')].join('|')
}

// Whether the peek's layer is mapped. Hyprland moves the keyboard to the last window when a layer unmaps while
// what has the keyboard cannot take it, as a popup of the bar does: that ends the grab of the bar's menu and
// closes it. So a mapped layer that has nothing left to draw stays mapped, empty, while `keepMapped` (a menu
// is open over the bar); one that is not mapped is not mapped for it.
function staysMapped(mapped, drawing, keepMapped) {
    return drawing || (mapped && keepMapped)
}
