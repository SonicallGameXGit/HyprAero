.pragma library

// The icons the user chose for an app, a window or a workspace instead of their own (the Icon Manager, after
// Windows 7's "Change Icon"), and the list of icons to choose from. Plain JS, no Quickshell imports, so node
// can test it.
//
// An icon is always an absolute file path: a file of an icon theme, or a picture the user chose, copied into
// the shell's own icons folder. Qt finds theme icons by name only in the theme it uses (often hicolor alone,
// without a platform theme), so the list is made of the theme folders' files and a chosen one is kept by its
// path.

// The kinds of things an icon can be chosen for, as kept in the file: an app by its desktop entry id (every
// window of it, its pin, its start menu row), a window by its Hyprland address (only while it lives), a
// workspace by its number (whatever its windows are).
const kinds = [
    'apps',
    'windows',
    'workspaces',
]

// The pictures a chosen file may be: what Qt's image plugins read.
const pictureExtensions = [
    'png',
    'svg',
    'svgz',
    'jpg',
    'jpeg',
    'gif',
    'bmp',
    'webp',
    'ico',
    'xpm',
]

function emptyOverrides() {
    return { apps: {}, windows: {}, workspaces: {} }
}

// Whether `key` can name a thing of `kind`: a window's address goes into nothing but the file, still only
// `0x` and hex digits are kept; a workspace is a positive number.
function validKey(kind, key) {
    if (typeof key !== 'string' || key === '') {
        return false
    }

    if (kind === 'windows') {
        return /^0x[0-9a-fA-F]+$/.test(key)
    }

    if (kind === 'workspaces') {
        return /^[1-9][0-9]*$/.test(key)
    }

    return kind === 'apps'
}

// Reads the file: `{ "version": 1, "apps": { id: path }, "windows": { address: path }, "workspaces":
// { number: path } }`. Whatever is wrong is left out and described in `problems`; an empty or missing file
// means no icon was chosen.
function parseOverrides(text) {
    const result = { overrides: emptyOverrides(), problems: [] }
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

    for (const kind of kinds) {
        const section = data[kind]
        if (section === undefined) {
            continue
        }

        if (typeof section !== 'object' || section === null || Array.isArray(section)) {
            result.problems.push(kind + ': not an object, ignored')
            continue
        }

        for (const key of Object.keys(section)) {
            const path = section[key]
            if (validKey(kind, key) && typeof path === 'string' && path.startsWith('/')) {
                result.overrides[kind][key] = path
            } else {
                result.problems.push(`${kind}: skipped ${JSON.stringify(key)}`)
            }
        }
    }

    return result
}

function serializeOverrides(overrides) {
    return JSON.stringify({
        version: 1,
        apps: overrides.apps,
        windows: overrides.windows,
        workspaces: overrides.workspaces,
    }, null, 4) + '\n'
}

// The icon chosen for that thing, '' when none.
function iconFor(overrides, kind, key) {
    const section = overrides[kind]
    if (section === undefined || Object.prototype.hasOwnProperty.call(section, key) === false) {
        return ''
    }

    return section[key]
}

// The overrides with the icon of that thing set to `path` ('' takes it away). The same object when nothing
// changes, so the owner can tell there is nothing to save.
function withIcon(overrides, kind, key, path) {
    if (kinds.includes(kind) === false || validKey(kind, key) === false || iconFor(overrides, kind, key) === path) {
        return overrides
    }

    if (path !== '' && path.startsWith('/') === false) {
        return overrides
    }

    const section = Object.assign({}, overrides[kind])
    if (path === '') {
        delete section[key]
    } else {
        section[key] = path
    }

    const copy = Object.assign({}, overrides)
    copy[kind] = section
    return copy
}

// The overrides without the windows that are gone (`liveAddresses`): an address names a window only while it
// lives, and a new window may get it again later.
function withoutGoneWindows(overrides, liveAddresses) {
    const gone = Object.keys(overrides.windows).filter(address => liveAddresses.includes(address) === false)
    let result = overrides
    for (const address of gone) {
        result = withIcon(result, 'windows', address, '')
    }

    return result
}

// The workspace icons after the bar's button in slot `from` was moved to slot `to`, the ones between one slot
// over toward `from` (`reorderPlan` in `workspaceList.js` renumbers the workspaces the same way): every icon
// stays with its button. `ids` are the bar's workspace numbers in order; workspaces off the bar keep theirs.
function reorderedWorkspaces(workspaces, ids, from, to) {
    if (from === to || from < 0 || to < 0 || from >= ids.length || to >= ids.length) {
        return workspaces
    }

    const order = ids.slice()
    const moved = order.splice(from, 1)
    order.splice(to, 0, moved[0])
    const result = Object.assign({}, workspaces)
    for (const id of ids) {
        delete result[String(id)]
    }

    for (let slot = 0; slot < ids.length; slot++) {
        const path = workspaces[String(order[slot])]
        if (path !== undefined) {
            result[String(ids[slot])] = path
        }
    }

    return result
}

// Every path the overrides use.
function usedPaths(overrides) {
    const paths = []
    for (const kind of kinds) {
        for (const key of Object.keys(overrides[kind])) {
            paths.push(overrides[kind][key])
        }
    }

    return paths
}

// Whether `path` is one of the copies kept in the shell's icons folder `folder`: right inside it, no
// `..`, so removing it can never reach anything else.
function isManaged(path, folder) {
    if (typeof path !== 'string' || path.startsWith(folder + '/') === false) {
        return false
    }

    const name = path.slice(folder.length + 1)
    return name !== '' && name.includes('/') === false && name !== '.' && name !== '..'
}

// The copies that `before` used and `after` does not any more, to be removed.
function unusedFiles(before, after, folder) {
    const kept = usedPaths(after)
    const result = []
    for (const path of usedPaths(before)) {
        if (isManaged(path, folder) && kept.includes(path) === false && result.includes(path) === false) {
            result.push(path)
        }
    }

    return result
}

// The extension of a picture file, lower case, '' when it is none `pictureExtensions` has.
function pictureExtension(path) {
    const name = path.slice(path.lastIndexOf('/') + 1)
    const dot = name.lastIndexOf('.')
    if (dot <= 0) {
        return ''
    }

    const extension = name.slice(dot + 1).toLowerCase()
    return pictureExtensions.includes(extension) ? extension : ''
}

// The name a chosen picture is copied under: what it is for, then a time stamp, so a new picture never has
// an old one's address (Qt would show the old one from its cache). '' when the source is not a picture.
function managedFileName(kind, key, sourcePath, stamp) {
    const extension = pictureExtension(sourcePath)
    if (extension === '') {
        return ''
    }

    const safeKey = key.replace(/[^A-Za-z0-9._-]/g, '_')
    return `${kind}-${safeKey}-${stamp}.${extension}`
}

// The file the chooser printed (zenity: the path and a newline), '' when nothing was chosen or it is not a
// picture. Only the last newline is cut, a name may start or end with spaces.
function chosenFile(output) {
    const path = output.endsWith('\n') ? output.slice(0, -1) : output
    if (path.startsWith('/') === false || path.includes('\n')) {
        return ''
    }

    return pictureExtension(path) === '' ? '' : path
}

// zenity's `--file-filter` for pictures: `label | *.png *.PNG ...` (its patterns are case-sensitive).
function fileFilter(label) {
    const patterns = []
    for (const extension of pictureExtensions) {
        patterns.push('*.' + extension, '*.' + extension.toUpperCase())
    }

    return label + ' | ' + patterns.join(' ')
}

// Copies `source` into the icons folder as `target`, the folder made first. The paths are handed to `sh` as
// parameters, never put into its text.
function copyCommand(source, folder, target) {
    return [
        'sh',
        '-c',
        'mkdir -p -- "$1" && cp -f -- "$2" "$3"',
        'sh',
        folder,
        source,
        target,
    ]
}

// Lists every picture file under the icon folders (`roots`, missing ones are skipped by `find` itself).
// Files of 100 bytes or less are left out: a theme copied without its links keeps each link as a small
// text file named like the picture, which would win over the real one and draw nothing. Symbolic icons are
// left out here already (`parseIconFiles` leaves them out too): they are a third of a big theme's files,
// and every line is read on the shell's thread.
function listCommand(roots) {
    return ['find', '-L'].concat(roots.map(root => root.path), [
        '-type',
        'f',
        '-size',
        '+100c',
        '-not',
        '-path',
        '*/symbolic/*',
        '-not',
        '-name',
        '*-symbolic.*',
        '(',
        '-name',
        '*.png',
        '-o',
        '-name',
        '*.svg',
        '-o',
        '-name',
        '*.svgz',
        '-o',
        '-name',
        '*.xpm',
        ')',
    ])
}

// The size the icons of a theme's folder were drawn for, from the folder's names (`48x48`, `48`,
// `48x48@2`; `scalable` counts as 512), 0 when they do not say.
function folderSize(parts) {
    let size = 0
    for (const part of parts) {
        if (part === 'scalable') {
            size = Math.max(size, 512)
            continue
        }

        const match = /^([0-9]+)(x[0-9]+)?(@([0-9]+)x?)?$/.exec(part)
        if (match !== null) {
            const scale = match[4] === undefined ? 1 : Number(match[4])
            size = Math.max(size, Number(match[1]) * scale)
        }
    }

    return size
}

// The icons in `find`'s output, one per theme and name, its best file, sorted by name, then theme:
// `{ themes, icons: [{ name, theme, path }] }`. The best file is the one best to show big: a drawing scales
// to any size, so it wins (the bigger it was drawn for, the better), then a picture by the size it was
// drawn at (`folderSize`). `roots` are `[{ path, theme }]` in the order they win: an empty `theme` means
// the first folder under the root is the theme (an icon folder); otherwise every file under it belongs to
// that theme (the pixmaps). Monochrome symbolic icons are left out: they are meant to be tinted by a
// toolkit and draw as black shapes.
function parseIconFiles(output, roots) {
    const reading = startIconFiles(output, roots)
    readIconFiles(reading, reading.lines.length)
    return finishIconFiles(reading)
}

// `parseIconFiles` a part at a time, so the shell draws between the parts: `startIconFiles`, then
// `readIconFiles` until it says it is done, then `finishIconFiles` for the result. Qt's JS engine runs it
// on the shell's thread and takes about 5 microseconds a line, and a big theme (Breeze) has tens of
// thousands. Plain objects, not Map: the engine looks a Map's keys up one by one, which took seconds with
// everything frozen; an object's keys are hashed.
function startIconFiles(output, roots) {
    return {
        lines: output.split('\n'),
        next: 0,
        roots: roots,
        prefixes: roots.map(root => root.path + '/'),
        best: Object.create(null),
        // A folder's size, and whether it is a symbolic one, worked out once for all its files.
        folders: Object.create(null),
        themes: Object.create(null),
    }
}

// Reads up to `count` more lines; true once every line is read.
function readIconFiles(reading, count) {
    const last = Math.min(reading.next + count, reading.lines.length)
    for (; reading.next < last; reading.next++) {
        readIconLine(reading, reading.lines[reading.next])
    }

    return reading.next >= reading.lines.length
}

function readIconLine(reading, line) {
    if (line === '') {
        return
    }

    let rootIndex = -1
    for (let index = 0; index < reading.prefixes.length; index++) {
        if (line.startsWith(reading.prefixes[index])) {
            rootIndex = index
            break
        }
    }

    if (rootIndex < 0) {
        return
    }

    let relative = line.slice(reading.prefixes[rootIndex].length)
    let theme = reading.roots[rootIndex].theme
    if (theme === '') {
        const slash = relative.indexOf('/')
        if (slash <= 0) {
            return
        }

        theme = relative.slice(0, slash)
        relative = relative.slice(slash + 1)
    }

    const slash = relative.lastIndexOf('/')
    const fileName = relative.slice(slash + 1)
    const extension = pictureExtension(fileName)
    if (extension === '') {
        return
    }

    const name = fileName.slice(0, fileName.lastIndexOf('.'))
    if (name === '' || name.endsWith('-symbolic')) {
        return
    }

    const folderPath = slash < 0 ? '' : relative.slice(0, slash)
    let folder = reading.folders[folderPath]
    if (folder === undefined) {
        const parts = folderPath === '' ? [] : folderPath.split('/')
        folder = { size: folderSize(parts), symbolic: parts.includes('symbolic') }
        reading.folders[folderPath] = folder
    }

    if (folder.symbolic) {
        return
    }

    const score = extension === 'svg' || extension === 'svgz' ? 10000 + folder.size : folder.size
    const key = theme + '\n' + name
    const known = reading.best[key]
    if (known === undefined || rootIndex < known.rootIndex || (rootIndex === known.rootIndex && score > known.score)) {
        reading.best[key] = {
            name: name,
            lowerName: name.toLowerCase(),
            theme: theme,
            path: line,
            score: score,
            rootIndex: rootIndex,
        }
        reading.themes[theme] = true
    }
}

function finishIconFiles(reading) {
    const icons = Object.keys(reading.best)
        .map(key => reading.best[key])
        .sort((a, b) => compareText(a.lowerName, b.lowerName) || compareText(a.theme, b.theme))
        .map(icon => ({ name: icon.name, theme: icon.theme, path: icon.path }))
    const themes = Object.keys(reading.themes)
        .sort((a, b) => compareText(a.toLowerCase(), b.toLowerCase()))
    return { themes: themes, icons: icons }
}

function compareText(a, b) {
    if (a === b) {
        return 0
    }

    return a < b ? -1 : 1
}

// The icons of `theme` ('' for every theme) whose name has every word of `query` in it, any case: the name
// itself first, then names starting with the text, then the rest, each in the list's order.
function searchIcons(icons, query, theme) {
    const inTheme = theme === '' ? icons : icons.filter(icon => icon.theme === theme)
    const text = query.trim().toLowerCase()
    if (text === '') {
        return inTheme
    }

    const words = text.split(/\s+/)
    const exact = []
    const starting = []
    const rest = []
    for (const icon of inTheme) {
        const name = icon.name.toLowerCase()
        if (words.every(word => name.includes(word)) === false) {
            continue
        }

        if (name === text) {
            exact.push(icon)
        } else if (name.startsWith(text)) {
            starting.push(icon)
        } else {
            rest.push(icon)
        }
    }

    return exact.concat(starting, rest)
}

// A file path as a `file://` address for an Image: every part escaped, so a name with `#`, `?` or `%` still
// names the file.
function fileUrl(path) {
    if (path === '') {
        return ''
    }

    return 'file://' + path.split('/').map(part => encodeURIComponent(part)).join('/')
}
