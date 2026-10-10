.pragma library

// Decides which workspace buttons the bar shows. Plain JS, no Quickshell imports, so node can test it.
// The first `minimumCount` ids are always shown (so there is something to click on a fresh desktop),
// plus every other regular workspace that currently exists or has focus. Special workspaces (id <= 0)
// are never listed.
function buildEntries(existing, focusedId, minimumCount) {
    const occupied = new Set()
    for (const workspace of existing) {
        if (workspace.id > 0) {
            occupied.add(workspace.id)
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
    return sorted.map(id => ({
        id: id,
        focused: id === focusedId,
        occupied: occupied.has(id),
    }))
}
