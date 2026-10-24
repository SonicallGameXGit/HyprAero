.pragma library

// The module's settings: what they are, their defaults, and reading the user's file
// (`~/.config/hypraero/notifications.json`). Plain JS, no Quickshell imports, so node can test it.
//
// The file only needs what the user changes; everything left out keeps its default. A value of the wrong
// kind or out of its range, an unknown name or a file that is not JSON never stops the module: that part
// falls back to its default and a problem is reported for the log.

// Grouped by what they are about, one object per group.
const defaults = {
    balloons: {
        // Where on the screen the balloons appear: a corner, the middle of an edge, or the centre. Windows 7
        // shows them over the notification area, at the bottom right.
        position: 'bottom-right',
        // The space between the balloons and the screen's edge (or a bar that keeps its own room), in pixels.
        margin: 8,
        // How many balloons show at once. Windows 7 shows one and the next waits until it closes.
        maxVisible: 1,
        // How long a balloon stays when the app leaves it to the server, in milliseconds. Windows 7 keeps
        // one for 5 seconds by default; the pointer resting on it keeps it longer.
        timeout: 5000,
        // The balloon's pointed tail, aimed at the corner it sits in (none in the middle of a side or the
        // centre, which have nothing to point at).
        stem: true,
        // The screen to show them on, by its name (`hyprctl monitors`); empty: the one with the focus.
        monitor: '',
    },
}

// Settings whose value must be one of a few words.
const choices = {
    'balloons.position': [
        'top-left',
        'top',
        'top-right',
        'left',
        'center',
        'right',
        'bottom-left',
        'bottom',
        'bottom-right',
    ],
}

// Settings whose value must be a whole number in a range, both ends included.
const ranges = {
    'balloons.margin': [0, 500],
    'balloons.maxVisible': [1, 10],
    'balloons.timeout': [1000, 600000],
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

// Why `value` cannot be setting `key`, or '' when it can. Its kind was already checked.
function invalidReason(key, value) {
    const allowed = choices[key]
    if (allowed !== undefined && allowed.includes(value) === false) {
        return 'must be one of ' + allowed.map(word => `"${word}"`).join(', ')
    }

    const range = ranges[key]
    if (range !== undefined && (Number.isInteger(value) === false || value < range[0] || value > range[1])) {
        return `must be a whole number from ${range[0]} to ${range[1]}`
    }

    return ''
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

            const reason = invalidReason(`${group}.${name}`, value)
            if (reason !== '') {
                problems.push(`"${group}.${name}" ${reason}, not ${JSON.stringify(value)}; using the default (${JSON.stringify(fallback)})`)
                continue
            }

            values[group][name] = value
        }
    }

    return { values: values, problems: problems }
}
