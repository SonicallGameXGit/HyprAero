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

// The letter on a drawn avatar.
function initial(name) {
    const trimmed = name.trim()
    return trimmed === '' ? '?' : trimmed[0].toUpperCase()
}

// Which of `count` avatar colours a name gets: always the same one for the same name.
function avatarIndex(name, count) {
    let hash = 0
    for (let index = 0; index < name.length; index++) {
        hash = (hash * 31 + name.charCodeAt(index)) % 2147483647
    }

    return hash % count
}
