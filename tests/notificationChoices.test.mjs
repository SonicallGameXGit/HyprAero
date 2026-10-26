import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The modules are QML library scripts; strip the pragma and evaluate them as plain JS.
const load = (file, names) => {
    const source = readFileSync(new URL('../services/' + file, import.meta.url), 'utf8').replace('.pragma library', '')
    return new Function(source + `\nreturn { ${names.join(', ')} }`)()
}
const choices = load('notificationChoices.js', [
    'appChoices',
    'emptyChoices',
    'parseFilter',
    'serializeFilter',
    'parseApps',
    'appsWithoutTray',
    'appChoiceOf',
    'setAppChoice',
    'setHideAll',
    'restoreDefaults',
])
const { notificationsShown } = load('tray.js', ['notificationsShown'])

// The notifications module's file as it writes it (its `notification-apps.json`).
const appsText = JSON.stringify({
    version: 1,
    apps: [
        { key: 'Telegram Desktop', name: 'Telegram', icon: 'image://icon/org.telegram.desktop', entry: 'org.telegram.desktop', tray: 'TelegramDesktop' },
        { key: 'notify-send', name: 'notify-send', icon: '', entry: '', tray: '' },
        { key: 'Firefox', name: 'Firefox', icon: 'image://icon/firefox', entry: 'firefox', tray: '' },
    ],
})
const { apps } = choices.parseApps(appsText)

// The page's app icons as `tray.js` remembers them.
const trayIcons = [
    { key: 'TelegramDesktop', behavior: 'icon', name: 'Telegram Desktop (1)', icon: 'image://icon/org.telegram.desktop-mute-symbolic' },
    { key: 'steam', behavior: 'notify', name: 'Steam', icon: '' },
    { key: 'discord_status_icon_1', behavior: 'hide', name: 'Discord', icon: '' },
]

test('no file of its own is nothing hidden', () => {
    assert.deepEqual(choices.parseFilter(''), { choices: choices.emptyChoices(), problems: [] })
})

test('the file holds the tray icons, those whose behavior hides notifications, and the apps hidden on their own', () => {
    const chosen = { hideAll: true, hiddenApps: ['notify-send'] }
    const data = JSON.parse(choices.serializeFilter(chosen, trayIcons, false, notificationsShown, apps))
    // The other side reads exactly these names (the notifications module's `parseFilter`).
    assert.deepEqual(Object.keys(data), ['version', 'hideAll', 'trayIcons', 'hiddenTrayIcons', 'hiddenApps'])
    assert.equal(data.version, 1)
    assert.deepEqual(data.trayIcons[0], { key: 'TelegramDesktop', name: 'Telegram Desktop (1)', icon: 'image://icon/org.telegram.desktop-mute-symbolic' })
    assert.deepEqual(data.hiddenTrayIcons, ['TelegramDesktop', 'discord_status_icon_1'])
    assert.deepEqual(data.hiddenApps, ['notify-send'])
    assert.equal(data.hideAll, true)
})

test('the choices are read back as written; the worked-out tray lists are not', () => {
    const chosen = { hideAll: true, hiddenApps: ['notify-send'] }
    const text = choices.serializeFilter(chosen, trayIcons, false, notificationsShown, apps)
    assert.deepEqual(choices.parseFilter(text), { choices: chosen, problems: [] })
})

test('an app hidden on its own row whose tray icon is now listed goes by that icon\'s behavior', () => {
    const chosen = { hideAll: false, hiddenApps: ['Telegram Desktop', 'notify-send'] }
    const shownIcon = [{ key: 'TelegramDesktop', behavior: 'show', name: 'Telegram', icon: '' }]
    const data = JSON.parse(choices.serializeFilter(chosen, shownIcon, false, notificationsShown, apps))
    assert.deepEqual(data.hiddenTrayIcons, [])
    assert.deepEqual(data.hiddenApps, ['notify-send'])
})

test('"Always show all icons and notifications" shows every tray app\'s notifications, not those hidden on their own row', () => {
    const chosen = { hideAll: false, hiddenApps: ['notify-send'] }
    const data = JSON.parse(choices.serializeFilter(chosen, trayIcons, true, notificationsShown, apps))
    assert.deepEqual(data.hiddenTrayIcons, [])
    assert.deepEqual(data.hiddenApps, ['notify-send'])
})

test('a broken file of its own starts fresh and says so', () => {
    for (const text of ['{', '[]', '{ "version": 2 }']) {
        const { choices: read, problems } = choices.parseFilter(text)
        assert.deepEqual(read, choices.emptyChoices())
        assert.equal(problems.length, 1)
    }
})

test('the notifications module\'s apps are read, and an absent or unknown file means it is not there', () => {
    const { known, problems } = choices.parseApps(appsText)
    assert.equal(known, true)
    assert.deepEqual(apps.map(app => [app.key, app.tray]), [['Telegram Desktop', 'TelegramDesktop'], ['notify-send', ''], ['Firefox', '']])
    assert.deepEqual(problems, [])
    assert.equal(choices.parseApps('').known, false)
    assert.equal(choices.parseApps('{ "version": 2, "apps": [] }').known, false)
    assert.equal(choices.parseApps('{ "version": 1, "apps": [] }').known, true)
})

test('an app has a row of its own only while its tray icon is not listed', () => {
    assert.deepEqual(choices.appsWithoutTray(apps, ['TelegramDesktop']).map(app => app.key), ['notify-send', 'Firefox'])
    assert.deepEqual(choices.appsWithoutTray(apps, []).map(app => app.key), ['Telegram Desktop', 'notify-send', 'Firefox'])
})

test('an app without a tray icon is shown or hidden by its own key', () => {
    assert.deepEqual(choices.appChoices, ['shown', 'hidden'])
    const hidden = choices.setAppChoice(choices.emptyChoices(), 'notify-send', 'hidden')
    assert.equal(choices.appChoiceOf(hidden, 'notify-send'), 'hidden')
    assert.equal(choices.appChoiceOf(hidden, 'Firefox'), 'shown')
    assert.deepEqual(choices.setAppChoice(hidden, 'notify-send', 'hidden'), hidden)
    assert.deepEqual(choices.setAppChoice(hidden, 'notify-send', 'shown'), choices.emptyChoices())
    assert.equal(choices.setAppChoice(hidden, 'notify-send', 'maybe'), hidden)
})

test('"Hide all" is its own switch; restoring the defaults shows every app again and leaves it', () => {
    const chosen = choices.setHideAll(choices.setAppChoice(choices.emptyChoices(), 'notify-send', 'hidden'), true)
    assert.equal(chosen.hideAll, true)
    assert.deepEqual(chosen.hiddenApps, ['notify-send'])
    assert.deepEqual(choices.restoreDefaults(chosen), { hideAll: true, hiddenApps: [] })
})
