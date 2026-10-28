import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/notificationApps.js', import.meta.url), 'utf8').replace('.pragma library', '')
const apps = new Function(source + '\nreturn { simplified, appKey, trayOf, hidden, remember, relink, parseFilter, parseApps, serializeApps }')()

// Tray icons as the owner's bar remembers them (its tray.json), the way the bar hands them over.
const trayIcons = [
    { key: 'nm-applet', name: 'Network', icon: 'image://icon/nm-signal-50' },
    { key: 'steam', name: 'Steam', icon: 'image://icon/steam_tray_mono?path=/home/user/.local/share/Steam/public' },
    { key: 'discord_status_icon_1', name: 'Discord', icon: '' },
    { key: 'TelegramDesktop', name: 'Telegram Desktop (1)', icon: 'image://icon/org.telegram.desktop-mute-symbolic' },
]

const app = (key, name, entry) => ({ key: key, name: name, icon: '', entry: entry })

test('an app is known by the name it gives, else by its desktop entry', () => {
    assert.equal(apps.appKey('Telegram Desktop', 'org.telegram.desktop'), 'Telegram Desktop')
    assert.equal(apps.appKey('', 'org.telegram.desktop'), 'org.telegram.desktop')
    assert.equal(apps.appKey('', ''), '')
})

test('names are compared without case, spaces, Electron\'s icon number or an unread count', () => {
    assert.equal(apps.simplified('Telegram Desktop (12)'), 'telegramdesktop')
    assert.equal(apps.simplified('discord_status_icon_1'), 'discord')
    assert.equal(apps.simplified('TelegramDesktop'), 'telegramdesktop')
})

test('an app finds its tray icon by name, desktop entry or the icon named after the entry', () => {
    assert.equal(apps.trayOf(app('Telegram Desktop', 'Telegram Desktop', ''), trayIcons), 'TelegramDesktop')
    assert.equal(apps.trayOf(app('discord', 'discord', ''), trayIcons), 'discord_status_icon_1')
    assert.equal(apps.trayOf(app('Steam', 'Steam', 'steam'), trayIcons), 'steam')
    // Only the desktop entry ties these together: the icon's name starts with it.
    assert.equal(apps.trayOf(app('Messages', 'Telegram', 'org.telegram.desktop'), trayIcons), 'TelegramDesktop')
})

test('an app without a tray icon, or with an icon only partly alike, finds none', () => {
    assert.equal(apps.trayOf(app('notify-send', 'notify-send', ''), trayIcons), '')
    assert.equal(apps.trayOf(app('Firefox', 'Firefox', 'firefox'), trayIcons), '')
    assert.equal(apps.trayOf(app('Steam Link', 'Steam Link', 'com.valvesoftware.SteamLink'), trayIcons), '')
    assert.equal(apps.trayOf(app('', '', ''), trayIcons), '')
})

test('hidden: everything with hideAll, else the app itself or its tray icon', () => {
    const filter = { hideAll: false, trayIcons: trayIcons, hiddenTrayIcons: ['TelegramDesktop'], hiddenApps: ['notify-send'] }
    assert.equal(apps.hidden(filter, 'Telegram Desktop', 'TelegramDesktop'), true)
    assert.equal(apps.hidden(filter, 'notify-send', ''), true)
    assert.equal(apps.hidden(filter, 'Steam', 'steam'), false)
    assert.equal(apps.hidden(filter, '', ''), false)
    assert.equal(apps.hidden(Object.assign({}, filter, { hideAll: true }), '', ''), true)
})

test('apps are remembered first seen first, linked to their tray icon, and updated in place', () => {
    let list = apps.remember([], { key: 'notify-send', name: 'notify-send', icon: '', entry: '' }, trayIcons)
    list = apps.remember(list, { key: 'Telegram Desktop', name: 'Telegram', icon: 'image://icon/org.telegram.desktop', entry: 'org.telegram.desktop' }, trayIcons)
    assert.deepEqual(list.map(item => [item.key, item.tray]), [['notify-send', ''], ['Telegram Desktop', 'TelegramDesktop']])
    // An icon of '' keeps the one seen before.
    const again = apps.remember(list, { key: 'Telegram Desktop', name: 'Telegram', icon: '', entry: 'org.telegram.desktop' }, trayIcons)
    assert.equal(again, list)
    const renamed = apps.remember(list, { key: 'notify-send', name: 'Notify', icon: '', entry: '' }, trayIcons)
    assert.equal(renamed[0].name, 'Notify')
    assert.equal(renamed.length, 2)
    assert.equal(apps.remember(list, app('', '', ''), trayIcons), list)
})

test('relink follows tray icons that come and go, and keeps the list when nothing changed', () => {
    const list = apps.remember([], app('Steam', 'Steam', 'steam'), [])
    assert.equal(list[0].tray, '')
    const linked = apps.relink(list, trayIcons)
    assert.equal(linked[0].tray, 'steam')
    assert.equal(apps.relink(linked, trayIcons), linked)
})

test('no filter file (no bar) hides nothing', () => {
    const { filter, problems } = apps.parseFilter('')
    assert.deepEqual(filter, { hideAll: false, trayIcons: [], hiddenTrayIcons: [], hiddenApps: [] })
    assert.deepEqual(problems, [])
})

test('the bar\'s filter file is read with what is wrong left out', () => {
    const text = JSON.stringify({
        version: 1,
        hideAll: true,
        trayIcons: [{ key: 'steam', name: 'Steam', icon: '' }, { name: 'no key' }, 'steam'],
        hiddenTrayIcons: ['steam', 3, ''],
        hiddenApps: 'notify-send',
    })
    const { filter, problems } = apps.parseFilter(text)
    assert.equal(filter.hideAll, true)
    assert.deepEqual(filter.trayIcons, [{ key: 'steam', name: 'Steam', icon: '' }])
    assert.deepEqual(filter.hiddenTrayIcons, ['steam'])
    assert.deepEqual(filter.hiddenApps, [])
    assert.equal(problems.length, 2)
})

test('a filter file that is broken or of another version hides nothing and says why', () => {
    for (const text of ['{', '[]', '{ "version": 2, "hideAll": true }']) {
        const { filter, problems } = apps.parseFilter(text)
        assert.equal(filter.hideAll, false)
        assert.equal(problems.length, 1)
    }
})

test('the apps file is read back as it was written', () => {
    const list = apps.remember([], { key: 'Telegram Desktop', name: 'Telegram', icon: 'image://icon/org.telegram.desktop', entry: 'org.telegram.desktop' }, trayIcons)
    const { apps: read, problems } = apps.parseApps(apps.serializeApps(list))
    assert.deepEqual(read, list)
    assert.deepEqual(problems, [])
    assert.equal(JSON.parse(apps.serializeApps(list)).version, 1)
})

test('a broken apps file starts fresh, and bad entries are skipped', () => {
    assert.deepEqual(apps.parseApps('nope').apps, [])
    const { apps: read, problems } = apps.parseApps('{ "version": 1, "apps": [{ "key": "a" }, { "key": "a" }, { "name": "b" }] }')
    assert.deepEqual(read, [{ key: 'a', name: 'a', icon: '', entry: '', tray: '' }])
    assert.equal(problems.length, 2)
})
