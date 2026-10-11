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
