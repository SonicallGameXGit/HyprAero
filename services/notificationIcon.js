.pragma library

// Where a notification's icon may come from, in the order to try. Plain JS, no Quickshell imports, so node
// can test it; `Notifications.qml` checks each candidate (a theme icon must exist) and takes the first.
//
// An app gives its icon as a file path, a `file://` address or an icon name, sometimes several separated by
// commas, sometimes a file name with its extension. The standard message icons (information, warning,
// error, question) are drawn with Windows 7's own (`resources/icons/`), as Windows' balloons had them.

// Icon names, without a "-symbolic" ending, that are one of Windows' message icons.
const windowsIcons = {
    'dialog-information': 'information',
    'dialog-info': 'information',
    'gtk-dialog-info': 'information',
    'dialog-warning': 'warning',
    'gtk-dialog-warning': 'warning',
    'dialog-error': 'error',
    'gtk-dialog-error': 'error',
    'dialog-question': 'question',
    'gtk-dialog-question': 'question',
}

// `[{ kind: 'windows', name } | { kind: 'url', url } | { kind: 'theme', name }]` for each icon given in `value`.
function candidates(value) {
    const found = []
    for (const part of value.split(',')) {
        const given = part.trim()
        if (given === '') {
            continue
        }

        if (given.startsWith('/')) {
            found.push({ kind: 'url', url: 'file://' + given })
            continue
        }

        if (given.startsWith('file://')) {
            found.push({ kind: 'url', url: given })
            continue
        }

        const name = given.replace(/\.(png|svg|svgz|xpm|jpg|jpeg|webp)$/i, '')
        const windows = windowsIcons[name.replace(/-symbolic$/, '')]
        if (windows !== undefined) {
            found.push({ kind: 'windows', name: windows })
            continue
        }

        found.push({ kind: 'theme', name: name })
    }

    return found
}

// What a balloon shows for a notification's `image` and `appIcon`: `{ picture, icons }`, the address of its
// large picture ('' for none) and the candidates for its small icon. An image that is only an icon's name
// (`notify-send -i` arrives as `image://icon/<name>`) is an icon, tried before the app's.
function sources(image, appIcon) {
    const iconPrefix = 'image://icon/'
    if (image.startsWith(iconPrefix)) {
        return { picture: '', icons: candidates(decodeURIComponent(image.slice(iconPrefix.length))).concat(candidates(appIcon)) }
    }

    return { picture: image, icons: candidates(appIcon) }
}
