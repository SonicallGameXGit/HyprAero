.pragma library

// The personal folders of the start menu, in its order, with the XDG name of each.
const folderKeys = [
    { key: 'documents', xdg: 'XDG_DOCUMENTS_DIR', fallback: 'Documents' },
    { key: 'pictures', xdg: 'XDG_PICTURES_DIR', fallback: 'Pictures' },
    { key: 'music', xdg: 'XDG_MUSIC_DIR', fallback: 'Music' },
    { key: 'videos', xdg: 'XDG_VIDEOS_DIR', fallback: 'Videos' },
    { key: 'downloads', xdg: 'XDG_DOWNLOAD_DIR', fallback: 'Downloads' },
]

// Reads `user-dirs.dirs` (lines like `XDG_DOCUMENTS_DIR="$HOME/Documents"`) into
// `[{ key, path }]`, in `folderKeys` order. A folder the file does not name gets its usual name in home;
// one set to home itself is turned off by the user (the XDG rule) and left out.
function userFolders(text, home) {
    const named = {}
    for (const line of text.split('\n')) {
        const match = /^\s*(XDG_[A-Z]+_DIR)\s*=\s*"(.*)"\s*$/.exec(line)
        if (match === null) {
            continue
        }

        let path = match[2]
        if (path.startsWith('$HOME')) {
            path = home + path.slice('$HOME'.length)
        }

        if (path.startsWith('/')) {
            named[match[1]] = path.replace(/\/+$/, '')
        }
    }

    const result = []
    for (const folder of folderKeys) {
        const path = named[folder.xdg] === undefined ? home + '/' + folder.fallback : named[folder.xdg]
        if (path === home || path === '') {
            continue
        }

        result.push({ key: folder.key, path: path })
    }

    return result
}

// The user's full name from `/etc/passwd` (the first part of the comment field), or '' without one.
function fullName(passwd, user) {
    for (const line of passwd.split('\n')) {
        const fields = line.split(':')
        if (fields.length >= 5 && fields[0] === user) {
            return fields[4].split(',')[0].trim()
        }
    }

    return ''
}

// The kinds of picture the chooser offers: what Qt shows without extra plugins, and WebP.
const pictureExtensions = [
    'png',
    'jpg',
    'jpeg',
    'gif',
    'bmp',
    'webp',
]

// zenity's `--file-filter` for pictures: `label | *.png *.PNG ...` (its patterns are case-sensitive).
function pictureFilter(label) {
    const patterns = []
    for (const extension of pictureExtensions) {
        patterns.push('*.' + extension, '*.' + extension.toUpperCase())
    }

    return label + ' | ' + patterns.join(' ')
}

// The picture the chooser printed (zenity: the path and a newline), '' when nothing was chosen or it is
// not a picture: not an absolute path, or not one of `pictureExtensions`. Only the last newline is cut,
// a name may start or end with spaces.
function chosenPicture(output) {
    const path = output.endsWith('\n') ? output.slice(0, -1) : output
    if (path.startsWith('/') === false || path.includes('\n')) {
        return ''
    }

    const name = path.slice(path.lastIndexOf('/') + 1)
    const dot = name.lastIndexOf('.')
    if (dot <= 0) {
        return ''
    }

    return pictureExtensions.includes(name.slice(dot + 1).toLowerCase()) ? path : ''
}

// Saves `source` as the profile picture `target` (`~/.face`): `tool` (`tools/shrinkPicture.qml`, run by
// Quickshell offscreen) cuts its middle to a square and shrinks it into `target.new.png`, which is then
// renamed over `target`; on a failure the old picture stays and nothing is left beside it. The paths are
// handed to `sh` as parameters, never put into its text.
function savePictureCommand(tool, source, target) {
    return [
        'sh',
        '-c',
        'HYPRAERO_PICTURE_SOURCE="$2" HYPRAERO_PICTURE_TARGET="$3.new.png" QT_QPA_PLATFORM=offscreen qs -p "$1" >/dev/null 2>&1'
            + ' && mv -f -- "$3.new.png" "$3" || { rm -f -- "$3.new.png"; exit 1; }',
        'sh',
        tool,
        source,
        target,
    ]
}
