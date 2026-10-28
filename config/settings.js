.pragma library

// The shell's settings: what they are, their defaults, and reading the user's file
// (`~/.config/hypraero/config.json`). Plain JS, no Quickshell imports, so node can test it.
//
// The file only needs what the user changes; everything left out keeps its default. A value of the wrong
// kind, an unknown name or a file that is not JSON never stops the shell: that part falls back to its
// default and a problem is reported for the log.

// Grouped by what they are about, one object per group.
const defaults = {
    bar: {
        // How long the pointer rests on a workspace button before its window previews open, in milliseconds
        // (clamped to 0-3000 where used), so crossing the bar opens nothing. Once open, they follow the
        // pointer along the buttons at once.
        previewDelay: 250,
        // Resting on a window's preview card for a moment shows that window on its own, almost full screen.
        peek: true,
        // How long the pointer rests on a card before that, in milliseconds (clamped to 100-3000 where used).
        peekDelay: 500,
        // The same for a workspace button: resting on it shows the whole workspace as if it was shown, after
        // twice the delay, counted from when its previews opened (`previewDelay`).
        peekWorkspaces: true,
        // How many times a workspace's button flashes when a window on it asks for attention, before it
        // stays orange until the window gets focus (Windows 7's ForegroundFlashCount, 7 by default there too;
        // clamped to 0-100 where used). 0 flashes for as long as the window asks.
        attentionFlashes: 7,
    },
    startMenu: {
        // Drag the app list to scroll it, and hold an app (a long press) to pick it up, as on a phone. Off:
        // dragging an app picks it up at once and the list scrolls with the wheel or the scrollbar.
        touchControls: false,
        // A window of an app keeping focus for a while counts as using it, for "Most used".
        countFocus: true,
        // What the start orb shows: Hyprland's mark ('hyprland') or Windows 7's flag ('windows').
        orbLogo: 'hyprland',
        // The colours of Hyprland's mark in the start orb: Windows 7's flag's ('windows') or Hyprland's own
        // ('hyprland').
        orbColors: 'windows',
        // Hyprland's mark split into four panes, as the flag is, by gaps as wide as the opening at its top.
        orbGaps: false,
    },
    tray: {
        // Windows 7's "Always show all icons and notifications on the taskbar": no icon waits behind the
        // arrow.
        showAll: false,
        // Windows 7's "Turn system icons on or off": the clock and each of the shell's own icons in the
        // notification area.
        clock: true,
        volumeIcon: true,
        networkIcon: true,
        powerIcon: true,
        bluetoothIcon: true,
        drivesIcon: true,
        // While one of those is on, the icon of an applet that only does the same thing (nm-applet,
        // blueman, pasystray, udiskie, ...) is left out of the notification area.
        hideSystemApps: true,
    },
}

// Settings that take only some words; anything else falls back to the default.
const choices = {
    'startMenu.orbLogo': [
        'hyprland',
        'windows',
    ],
    'startMenu.orbColors': [
        'windows',
        'hyprland',
    ],
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

            const allowed = choices[group + '.' + name]
            if (allowed !== undefined && allowed.includes(value) === false) {
                const listed = allowed.map(choice => JSON.stringify(choice)).join(', ')
                problems.push(`"${group}.${name}" must be one of ${listed}, not ${JSON.stringify(value)}; using the default (${JSON.stringify(fallback)})`)
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
