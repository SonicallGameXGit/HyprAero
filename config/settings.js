.pragma library

// The shell's settings: what they are, their defaults, and reading the user's file
// (`~/.config/hypraero/config.json`). Plain JS, no Quickshell imports, so node can test it.
//
// The file only needs what the user changes; everything left out keeps its default. A value of the wrong
// kind, an unknown name or a file that is not JSON never stops the shell: that part falls back to its
// default and a problem is reported for the log.

// Grouped by what they are about, one object per group.
const defaults = {
    startMenu: {
        // Drag the app list to scroll it, and hold an app (a long press) to pick it up, as on a phone. Off:
        // dragging an app picks it up at once and the list scrolls with the wheel or the scrollbar.
        touchControls: false,
        // A window of an app keeping focus for a while counts as using it, for "Most used".
        countFocus: true,
    },
    tray: {
        // Windows 7's "Always show all icons and notifications on the taskbar": no icon waits behind the
        // arrow.
        showAll: false,
    },
}

function kindOf(value) {
    if (value === null) {
        return 'null'
    }

    if (Array.isArray(value)) {
        return 'list'
    }

    return typeof value
}

// `{ values, problems }`: every setting with the user's value where it is valid, else its default, and one
// line of text per thing that was wrong. Empty text (no file) is all defaults without problems.
function parseConfig(text) {
    const problems = []
    const values = {}
    for (const group of Object.keys(defaults)) {
        values[group] = Object.assign({}, defaults[group])
    }

    if (text.trim() === '') {
        return { values: values, problems: problems }
    }

    let data = null
    try {
        data = JSON.parse(text)
    } catch (error) {
        problems.push('not valid JSON (' + error.message + '), using every default')
        return { values: values, problems: problems }
    }

    if (kindOf(data) !== 'object') {
        problems.push('the file must hold an object ({ ... }), using every default')
        return { values: values, problems: problems }
    }

    for (const group of Object.keys(data)) {
        if (defaults[group] === undefined) {
            problems.push(`unknown group "${group}", ignored`)
            continue
        }

        const given = data[group]
        if (kindOf(given) !== 'object') {
            problems.push(`"${group}" must be an object ({ ... }), using its defaults`)
            continue
        }

        for (const name of Object.keys(given)) {
            const fallback = defaults[group][name]
            if (fallback === undefined) {
                problems.push(`unknown setting "${group}.${name}", ignored`)
                continue
            }

            const value = given[name]
            if (kindOf(value) !== kindOf(fallback)) {
                problems.push(`"${group}.${name}" must be a ${kindOf(fallback)}, not a ${kindOf(value)}; using the default (${JSON.stringify(fallback)})`)
                continue
            }

            values[group][name] = value
        }
    }

    return { values: values, problems: problems }
}

// The file's text with one setting changed, for a setting changed from the shell itself (the tray's
// "Customize" page). Everything else in the file stays, unknown names too; a setting back at its default
// is taken out (and its group when that leaves it empty), so the file keeps holding only what differs.
// null when the file cannot be changed safely (not JSON, not an object, the group not an object): the
// user's file is never overwritten with something they did not write.
function setSetting(text, group, name, value) {
    if (defaults[group] === undefined || defaults[group][name] === undefined) {
        return null
    }

    let data = {}
    if (text.trim() !== '') {
        try {
            data = JSON.parse(text)
        } catch (error) {
            return null
        }
    }

    if (kindOf(data) !== 'object' || (data[group] !== undefined && kindOf(data[group]) !== 'object')) {
        return null
    }

    const values = Object.assign({}, data[group])
    if (value === defaults[group][name]) {
        delete values[name]
    } else {
        values[name] = value
    }

    if (Object.keys(values).length === 0) {
        delete data[group]
    } else {
        data[group] = values
    }

    return JSON.stringify(data, null, 4) + '\n'
}
