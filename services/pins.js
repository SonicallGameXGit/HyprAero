.pragma library

// The apps pinned to the bar, like Windows Vista's Quick Launch: desktop entry ids in the user's order.
// Plain JS, no Quickshell imports, so node can test it.

// Reads the pins file: `{ "version": 1, "apps": [ids] }`. Whatever is wrong is left out and described in
// `problems`; an empty or missing file means nothing is pinned.
function parsePins(text) {
    const result = { apps: [], problems: [] }
    if (text.trim() === '') {
        return result
    }

    let data = null
    try {
        data = JSON.parse(text)
    } catch (error) {
        result.problems.push('not valid JSON, starting fresh')
        return result
    }

    if (typeof data !== 'object' || data === null || Array.isArray(data)) {
        result.problems.push('not a JSON object, starting fresh')
        return result
    }

    if (Array.isArray(data.apps)) {
        for (const id of data.apps) {
            if (typeof id === 'string' && id !== '' && result.apps.includes(id) === false) {
                result.apps.push(id)
            } else {
                result.problems.push('apps: skipped ' + JSON.stringify(id))
            }
        }
    } else if (data.apps !== undefined) {
        result.problems.push('apps: not a list, ignored')
    }

    return result
}

function serializePins(apps) {
    return JSON.stringify({ version: 1, apps: apps }, null, 4) + '\n'
}

// The pins with `id` put right before `beforeId` ('' or an id that is not pinned: at the end). One already
// pinned moves there, so dropping a pin next to itself leaves the order as it was.
function placePin(apps, id, beforeId) {
    if (id === '' || id === beforeId) {
        return apps
    }

    const rest = apps.filter(item => item !== id)
    const at = beforeId === '' ? -1 : rest.indexOf(beforeId)
    if (at < 0) {
        return rest.concat([id])
    }

    return rest.slice(0, at).concat([id], rest.slice(at))
}

function removePin(apps, id) {
    return apps.filter(item => item !== id)
}

// Which gap of the pin row the pointer at `x` is closest to: 0 before the first pin, `slots.length` after
// the last. `slots` are the pins in order as [{ left, right }], in the same coordinates as `x`.
function gapAt(x, slots) {
    for (let index = 0; index < slots.length; index++) {
        if (x < (slots[index].left + slots[index].right) / 2) {
            return index
        }
    }

    return slots.length
}
