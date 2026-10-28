.pragma library

// The apps that sent notifications, and which of them the user chose not to see on the bar's "Notification
// Area Icons" page. Plain JS, no Quickshell imports, so node can test it.
//
// Two files in the shared state folder are the interface with the bar (AGENTS.md section 2.1), each written
// by one side only:
//     notification-apps.json      this module's: every app that sent a notification, first seen first
//     notification-filter.json    the bar's: which apps' notifications to hide, and its tray's app icons
// An app is told apart by the name it gives (`appName`), or its desktop entry when it gives no name. To put an
// app's notifications on the row of its tray icon, the app is matched with that icon here (`trayOf`), so the
// bar never has to guess which icon an app belongs to.

const version = 1

// A name as both sides spell it differently ('Telegram Desktop' and 'TelegramDesktop',
// 'discord_status_icon_1' and 'Discord', 'Telegram Desktop (1)' with its unread count): lower case, without
// Electron's '_status_icon_<n>', a count in brackets at the end, and anything but letters and digits.
function simplified(name) {
    return name
        .toLowerCase()
        .replace(/_status_icon_\d+$/, '')
        .replace(/\s*\(\d+\)$/, '')
        .replace(/[^a-z0-9]/g, '')
}

function appKey(appName, desktopEntry) {
    return appName !== '' ? appName : desktopEntry
}

// The icon name in a tray icon's picture (`image://icon/<name>`), '' for any other picture.
function themeName(source) {
    const prefix = 'image://icon/'
    if (source.startsWith(prefix) === false) {
        return ''
    }

    return source.slice(prefix.length).split('?')[0].toLowerCase()
}

// The key of the tray icon (`trayIcons`: `[{ key, name, icon }]`) that belongs to the app (`{ key, name,
// entry }`), '' when none does: one whose id or name is the app's name, desktop entry or entry's name, or whose
// theme icon is named after the desktop entry ('org.telegram.desktop-mute-symbolic'). The first one wins.
function trayOf(app, trayIcons) {
    const names = [app.key, app.name, app.entry].map(simplified).filter(name => name !== '')
    const entry = app.entry.toLowerCase()
    for (const icon of trayIcons) {
        const iconNames = [icon.key, icon.name].map(simplified)
        if (iconNames.some(name => name !== '' && names.includes(name))) {
            return icon.key
        }

        const theme = themeName(icon.icon)
        if (entry !== '' && theme !== '' && (theme === entry || ['-', '.', '_'].some(mark => theme.startsWith(entry + mark)))) {
            return icon.key
        }
    }

    return ''
}

// Whether a notification of the app with `key`, belonging to the tray icon `tray` ('' for none), is hidden.
function hidden(filter, key, tray) {
    if (filter.hideAll) {
        return true
    }

    if (key !== '' && filter.hiddenApps.includes(key)) {
        return true
    }

    return tray !== '' && filter.hiddenTrayIcons.includes(tray)
}

// The apps with `app` (`{ key, name, icon, entry }`) remembered: a new one after the others, a known one with
// its current name and icon (an icon of '' keeps the last one), each linked to its tray icon. The same list
// when nothing changed. An app without a key is not remembered.
function remember(apps, app, trayIcons) {
    if (app.key === '') {
        return apps
    }

    const tray = trayOf(app, trayIcons)
    const index = apps.findIndex(known => known.key === app.key)
    if (index < 0) {
        return apps.concat([{ key: app.key, name: app.name, icon: app.icon, entry: app.entry, tray: tray }])
    }

    const known = apps[index]
    const icon = app.icon !== '' ? app.icon : known.icon
    if (known.name === app.name && known.icon === icon && known.entry === app.entry && known.tray === tray) {
        return apps
    }

    const result = apps.slice()
    result[index] = { key: known.key, name: app.name, icon: icon, entry: app.entry, tray: tray }
    return result
}

// Every app linked again to the tray icons, which come and go on the bar. The same list when nothing changed.
function relink(apps, trayIcons) {
    let changed = false
    const result = apps.map(app => {
        const tray = trayOf(app, trayIcons)
        if (tray === app.tray) {
            return app
        }

        changed = true
        return { key: app.key, name: app.name, icon: app.icon, entry: app.entry, tray: tray }
    })

    return changed ? result : apps
}

function isObject(value) {
    return typeof value === 'object' && value !== null && Array.isArray(value) === false
}

function stringsOf(value) {
    return Array.isArray(value) ? value.filter(item => typeof item === 'string' && item !== '') : []
}

function emptyFilter() {
    return { hideAll: false, trayIcons: [], hiddenTrayIcons: [], hiddenApps: [] }
}

// Reads the bar's file: `{ "version": 1, "hideAll", "trayIcons": [{ "key", "name", "icon" }],
// "hiddenTrayIcons": [key], "hiddenApps": [key] }`. No file (no bar) hides nothing; whatever is wrong is left
// out and described in `problems`, and a file of another version hides nothing, as its meaning is unknown.
function parseFilter(text) {
    const result = { filter: emptyFilter(), problems: [] }
    if (text.trim() === '') {
        return result
    }

    let data = null
    try {
        data = JSON.parse(text)
    } catch (error) {
        result.problems.push('not valid JSON, hiding nothing')
        return result
    }

    if (isObject(data) === false) {
        result.problems.push('not a JSON object, hiding nothing')
        return result
    }

    if (data.version !== version) {
        result.problems.push(`version ${JSON.stringify(data.version)} is not ${version}, hiding nothing`)
        return result
    }

    const filter = result.filter
    filter.hideAll = data.hideAll === true
    filter.hiddenTrayIcons = stringsOf(data.hiddenTrayIcons)
    filter.hiddenApps = stringsOf(data.hiddenApps)
    if (Array.isArray(data.trayIcons)) {
        for (const icon of data.trayIcons) {
            if (isObject(icon) === false || typeof icon.key !== 'string' || icon.key === '') {
                result.problems.push('trayIcons: skipped ' + JSON.stringify(icon))
                continue
            }

            filter.trayIcons.push({
                key: icon.key,
                name: typeof icon.name === 'string' ? icon.name : '',
                icon: typeof icon.icon === 'string' ? icon.icon : '',
            })
        }
    }

    return result
}

// Reads this module's own file back: `{ "version": 1, "apps": [{ "key", "name", "icon", "entry", "tray" }] }`.
function parseApps(text) {
    const result = { apps: [], problems: [] }
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

    if (isObject(data) === false || Array.isArray(data.apps) === false) {
        result.problems.push('no list of apps, starting fresh')
        return result
    }

    for (const app of data.apps) {
        const valid = isObject(app)
            && typeof app.key === 'string'
            && app.key !== ''
            && result.apps.some(known => known.key === app.key) === false
        if (valid === false) {
            result.problems.push('apps: skipped ' + JSON.stringify(app))
            continue
        }

        result.apps.push({
            key: app.key,
            name: typeof app.name === 'string' && app.name !== '' ? app.name : app.key,
            icon: typeof app.icon === 'string' ? app.icon : '',
            entry: typeof app.entry === 'string' ? app.entry : '',
            tray: typeof app.tray === 'string' ? app.tray : '',
        })
    }

    return result
}

function serializeApps(apps) {
    return JSON.stringify({ version: version, apps: apps }, null, 4) + '\n'
}
