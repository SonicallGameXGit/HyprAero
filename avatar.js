.pragma library

// What a drawn avatar shows (`Avatar.qml`). Plain JS, no Quickshell imports, so node can test it.

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
