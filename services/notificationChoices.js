.pragma library

// Which apps' notifications the user wants to see, chosen on the "Notification Area Icons" page. Plain JS, no
// Quickshell imports, so node can test it.
//
// The notifications module (the `notifications` branch) shows them; this shell only says what to hide,
// through two files in the shared state folder, each written by one side only (AGENTS.md section 2.1):
//     notification-filter.json    this shell's: the choices, and the tray's app icons
//     notification-apps.json      the notifications module's: every app that sent a notification, each with
//                                 the key of its tray icon ('' for none), which that module matches up
// An app with a tray icon on the page goes by that icon's behavior (`tray.js`: "Hide icon and notifications"
// and "Only show icon" hide its notifications); an app without one has a row of its own, shown or hidden
// (`appChoices`). "Hide all notifications" hides every one.

const version = 1
// The choices of an app without a tray icon on the page.
const appChoices = ['shown', 'hidden']

function emptyChoices() {
    return { hideAll: false, hiddenApps: [] }
}

function isObject(value) {
    return typeof value === 'object' && value !== null && Array.isArray(value) === false
}

function stringsOf(value) {
    if (Array.isArray(value) === false) {
        return []
    }

    const result = []
    for (const item of value) {
        if (typeof item === 'string' && item !== '' && result.includes(item) === false) {
            result.push(item)
        }
    }

    return result
}

// Reads this shell's own file back (its `trayIcons` and `hiddenTrayIcons` are worked out from the tray's
// icons, for the other side, and not read here). Whatever is wrong is left out and described in `problems`;
// no file is nothing hidden.
function parseFilter(text) {
    const result = { choices: emptyChoices(), problems: [] }
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

    if (isObject(data) === false || data.version !== version) {
        result.problems.push(`not a version ${version} object, starting fresh`)
        return result
    }

    result.choices = {
        hideAll: data.hideAll === true,
        hiddenApps: stringsOf(data.hiddenApps),
    }
    return result
}

// The file for the notifications module. `trayIcons` are the app icons the page lists (`[{ key, name, icon,
// behavior }]` as `tray.js` remembers them; the shell's own system icons send no notifications), for it to
// match its apps with; `notificationsShown` tells from a behavior whether their notifications show, and with
// `showAll` ("Always show all icons and notifications on the bar") every icon's do. An app hidden on a row of
// its own whose tray icon has since been listed goes by that icon's behavior, as the page shows it.
function serializeFilter(choices, trayIcons, showAll, notificationsShown, apps) {
    const trayKeys = trayIcons.map(icon => icon.key)
    const withIcon = apps.filter(app => trayKeys.includes(app.tray)).map(app => app.key)
    return JSON.stringify({
        version: version,
        hideAll: choices.hideAll,
        trayIcons: trayIcons.map(icon => ({ key: icon.key, name: icon.name, icon: icon.icon })),
        hiddenTrayIcons: showAll ? [] : trayIcons.filter(icon => notificationsShown(icon.behavior) === false).map(icon => icon.key),
        hiddenApps: choices.hiddenApps.filter(key => withIcon.includes(key) === false),
    }, null, 4) + '\n'
}

// Reads the notifications module's file: `{ "version": 1, "apps": [{ "key", "name", "icon", "tray" }] }`.
// `known` is false when it is not there or not understood: that module has not run here, so the page has
// nothing to offer about notifications.
function parseApps(text) {
    const result = { apps: [], known: false, problems: [] }
    if (text.trim() === '') {
        return result
    }

    let data = null
    try {
        data = JSON.parse(text)
    } catch (error) {
        result.problems.push('not valid JSON')
        return result
    }

    if (isObject(data) === false || data.version !== version || Array.isArray(data.apps) === false) {
        result.problems.push(`not a version ${version} list of apps`)
        return result
    }

    result.known = true
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
            tray: typeof app.tray === 'string' ? app.tray : '',
        })
    }

    return result
}

// The apps with no row of their own tray icon among `trayKeys` (the icons the page lists), first seen first.
function appsWithoutTray(apps, trayKeys) {
    return apps.filter(app => app.tray === '' || trayKeys.includes(app.tray) === false)
}

// The choice ('shown' or 'hidden', `appChoices`) of an app without a tray icon.
function appChoiceOf(choices, key) {
    return choices.hiddenApps.includes(key) ? 'hidden' : 'shown'
}

function setAppChoice(choices, key, choice) {
    if (appChoices.includes(choice) === false) {
        return choices
    }

    const hiddenApps = choices.hiddenApps.filter(known => known !== key)
    if (choice === 'hidden') {
        hiddenApps.push(key)
    }

    return { hideAll: choices.hideAll, hiddenApps: hiddenApps }
}

function setHideAll(choices, on) {
    return { hideAll: on, hiddenApps: choices.hiddenApps }
}

// "Restore default icon behaviors": every app without a tray icon shown again (those with one go back to
// "Only show notifications" with their icon); "Hide all notifications" is a check box of its own and stays
// as it is, as "Always show all" does.
function restoreDefaults(choices) {
    return { hideAll: choices.hideAll, hiddenApps: [] }
}
