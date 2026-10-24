.pragma library

// Where the balloons go, which of them show, how long each stays and which of its actions become buttons.
// Plain JS, no Quickshell imports, so node can test it.

// How the balloons sit for a `position` setting (`settings.js`): which screen edges the window is fastened
// to (none on an axis centres it there), where the stem goes, and which end of the stack the newest balloon
// takes (the one nearest the edge, so it is the one the stem is on). `stem` false leaves the stem out.
function placement(position, stem) {
    const top = position.startsWith('top')
    const bottom = position.startsWith('bottom')
    const left = position.endsWith('left')
    const right = position.endsWith('right')
    let stemEdge = 'none'
    if (stem && top) {
        stemEdge = 'top'
    } else if (stem && bottom) {
        stemEdge = 'bottom'
    }

    let stemSide = 'center'
    if (left) {
        stemSide = 'left'
    } else if (right) {
        stemSide = 'right'
    }

    return {
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        stemEdge: stemEdge,
        stemSide: stemSide,
        // In the middle row there is no edge to be near; the newest goes on top, as it is read first.
        newestFirst: bottom === false,
    }
}

// The balloons on screen, top to bottom, from every notification kept (oldest first): the oldest
// `maxVisible` (Windows 7's queue: one waits until another closes), the newest of them nearest the edge.
function shown(kept, maxVisible, newestFirst) {
    const first = kept.slice(0, Math.max(1, maxVisible))
    return newestFirst ? first.reverse() : first
}

// Which of `count` balloons on screen (top to bottom) has the stem: the one nearest the edge.
function stemIndex(count, newestFirst) {
    return newestFirst ? 0 : count - 1
}

// How long a balloon stays, in milliseconds; 0 is until it is closed. `expireTimeout` is what the app asked
// for, in milliseconds as the notification standard has it: -1 leaves it to the server (`fallback`), 0 is
// never. A critical notification the app left to the server stays, as the standard asks.
function timeout(expireTimeout, critical, fallback) {
    if (expireTimeout > 0) {
        return expireTimeout
    }

    if (expireTimeout === 0 || critical) {
        return 0
    }

    return fallback
}

// The buttons for a notification's `actions` ([{ identifier, text }]): every action, in the app's order, the
// first the main one, as in the old AGS shell; "default" too, which a click on the balloon also does. Each
// keeps its place among the actions. An action without words shows its identifier; "default" without words
// gets '' and the balloon words it.
function buttons(actions) {
    return actions.map((action, index) => {
        if (action.text !== '') {
            return { index: index, text: action.text }
        }

        return { index: index, text: action.identifier === 'default' ? '' : action.identifier }
    })
}

// The place of the "default" action, what a click on the balloon does; -1 when there is none.
function defaultAction(actions) {
    return actions.findIndex(action => action.identifier === 'default')
}
