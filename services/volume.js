.pragma library

// The notification area's volume icon, its flyout and the Volume Mixer, after Windows 7's. Plain JS, no
// Quickshell imports, so node can test it. Volumes are 0 to 1, as PipeWire gives them.

// How much one wheel notch (120 in Qt's units) changes the volume: Windows' 2 points.
const wheelStep = 0.02

function percent(volume) {
    if (typeof volume !== 'number' || Number.isNaN(volume)) {
        return 0
    }

    return Math.round(Math.min(1, Math.max(0, volume)) * 100)
}

// The speaker of the bar icon, as Windows 7 draws it: 'none' (no output device, a red cross), 'muted' (a
// red no-entry sign), 'silent' (no waves), then 'low', 'medium' and 'high' (one, two, three waves).
function iconLevel(volume, muted, present) {
    if (present === false) {
        return 'none'
    }

    if (muted) {
        return 'muted'
    }

    const value = percent(volume)
    if (value === 0) {
        return 'silent'
    }

    if (value < 33) {
        return 'low'
    }

    return value < 66 ? 'medium' : 'high'
}

// The picture of the bar icon in `resources/icons/`: Windows 7's own speaker for each level (`sndvolsso.dll`).
function iconName(level) {
    const known = ['none', 'muted', 'silent', 'low', 'medium', 'high']
    return 'volume-' + (known.includes(level) ? level : 'high')
}

// The volume after the wheel turned by `delta` (Qt's angle units), kept between 0 and 1 and on whole
// points, so steps never drift.
function wheeled(volume, delta) {
    const steps = delta / 120
    const next = Math.round((volume + steps * wheelStep) * 100) / 100
    return Math.min(1, Math.max(0, next))
}

// The apps playing sound now, for the Volume Mixer: PipeWire's playback streams (`media.class`
// "Stream/Output/Audio") as `{ id, name, icon }`, named by their app, by name. `nodes` are
// `{ id, mediaClass, appName, appIcon, appBinary, description, name }`, any of the words possibly ''.
function playbackStreams(nodes) {
    return nodes
        .filter(node => node.mediaClass === 'Stream/Output/Audio')
        .map(node => ({
            id: node.id,
            name: firstWord([node.appName, node.description, node.name]),
            icon: firstWord([node.appIcon, node.appBinary]),
        }))
        .sort((first, second) => first.name.localeCompare(second.name) || first.id - second.id)
}

// The sound devices to choose from (`media.class` "Audio/Sink"), named as people know them.
function outputDevices(nodes) {
    return nodes
        .filter(node => node.mediaClass === 'Audio/Sink')
        .map(node => ({ id: node.id, name: firstWord([node.description, node.nickname, node.name]) }))
        .sort((first, second) => first.name.localeCompare(second.name) || first.id - second.id)
}

function firstWord(words) {
    for (const word of words) {
        if (typeof word === 'string' && word !== '') {
            return word
        }
    }

    return ''
}
