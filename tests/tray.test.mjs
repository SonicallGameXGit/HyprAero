import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/tray.js', import.meta.url), 'utf8').replace('.pragma library', '')
const tray = new Function(source + `
return {
    itemKey,
    nameHasOwner,
    themeIconName,
    displayName,
    plainText,
    tooltipText,
    parseTray,
    serializeTray,
    remember,
    arrange,
    placeIcon,
    setBehavior,
    restoreDefaults,
    gridColumns,
    gridGapAt,
}`)()

const icon = (key, behavior) => ({ key: key, behavior: behavior, name: key, icon: '' })
const keys = icons => icons.map(item => item.key + ':' + item.behavior)

test('watcher check: gdbus says yes or no, anything else is not known', () => {
    assert.equal(tray.nameHasOwner('(true,)\n'), true)
    assert.equal(tray.nameHasOwner('(false,)'), false)
    assert.equal(tray.nameHasOwner(''), null)
    assert.equal(tray.nameHasOwner('Error: GDBus.Error:org.freedesktop.DBus.Error.ServiceUnknown'), null)
})

test('key: the id, or the title without one', () => {
    assert.equal(tray.itemKey('steam', 'Steam'), 'steam')
    assert.equal(tray.itemKey('', 'Some App'), 'Some App')
})

test('theme icon: a name only for an icon given by name alone', () => {
    assert.equal(tray.themeIconName('image://icon/nm-signal-50'), 'nm-signal-50')
    assert.equal(tray.themeIconName('image://icon/steam_tray_mono?path=/home/me/.steam'), '')
    assert.equal(tray.themeIconName('image://qspixmap/6/1'), '')
    assert.equal(tray.themeIconName(''), '')
})

test('name: tooltip title, then title, then id', () => {
    assert.equal(tray.displayName('discord_status_icon_1', '', 'Discord'), 'Discord')
    assert.equal(tray.displayName('nm-applet', 'Network', ''), 'Network')
    assert.equal(tray.displayName('steam', '', ''), 'steam')
})

test('tooltip: the name, and a description that says more under it, as plain text', () => {
    assert.equal(tray.tooltipText('Steam', ''), 'Steam')
    assert.equal(tray.tooltipText('Bridge', 'Bridge'), 'Bridge')
    assert.equal(tray.tooltipText('Bridge', 'Offers <b>streams</b> to X11 apps'), 'Bridge\nOffers streams to X11 apps')
    assert.equal(tray.tooltipText('Mail', '3 unread<br/>from &quot;Ann&quot; &amp; Bob'), 'Mail\n3 unread\nfrom "Ann" & Bob')
})

test('file: a missing or empty file knows no icon', () => {
    assert.deepEqual(tray.parseTray(''), { icons: [], problems: [] })
    assert.deepEqual(tray.parseTray('{ "version": 1 }'), { icons: [], problems: [] })
})

test('file: reads the icons in order and round-trips', () => {
    const icons = [
        { key: 'steam', behavior: 'show', name: 'Steam', icon: 'image://icon/steam' },
        { key: 'nm-applet', behavior: 'hide', name: 'Network', icon: '' },
    ]
    const parsed = tray.parseTray(tray.serializeTray(icons))
    assert.deepEqual(parsed.icons, icons)
    assert.deepEqual(parsed.problems, [])
})

test('file: wrong entries and repeats are skipped, an unknown behavior is the default, all reported', () => {
    const parsed = tray.parseTray(JSON.stringify({
        icons: [
            { key: 'a', behavior: 'show' },
            3,
            { key: '' },
            { key: 'a', behavior: 'hide' },
            { key: 'b', behavior: 'always' },
        ],
    }))
    assert.deepEqual(keys(parsed.icons), ['a:show', 'b:notify'])
    assert.equal(parsed.icons[0].name, 'a')
    assert.equal(parsed.problems.length, 4)
})

test('file: broken JSON or the wrong shape starts fresh and says so', () => {
    assert.deepEqual(tray.parseTray('{ icons: [').icons, [])
    assert.equal(tray.parseTray('{ icons: [').problems.length, 1)
    assert.deepEqual(tray.parseTray('[]').icons, [])
    assert.equal(tray.parseTray('{ "icons": {} }').problems.length, 1)
})

test('remember: a new icon is added at the end as "only show notifications"', () => {
    const icons = [icon('steam', 'show')]
    const result = tray.remember(icons, [
        { key: 'steam', name: 'steam', icon: '' },
        { key: 'nm-applet', name: 'Network', icon: 'image://icon/nm-signal-50' },
    ])
    assert.deepEqual(result, [icons[0], { key: 'nm-applet', behavior: 'notify', name: 'Network', icon: 'image://icon/nm-signal-50' }])
})

test('remember: nothing new gives the same list, so nothing is written', () => {
    const icons = [icon('steam', 'show')]
    assert.equal(tray.remember(icons, [{ key: 'steam', name: 'steam', icon: '' }]), icons)
})

test('remember: a known icon takes its new name, and keeps its last icon when it has none now', () => {
    const icons = [{ key: 'steam', behavior: 'hide', name: 'Steam', icon: 'image://icon/steam' }]
    const result = tray.remember(icons, [{ key: 'steam', name: 'Steam Client', icon: '' }])
    assert.deepEqual(result, [{ key: 'steam', behavior: 'hide', name: 'Steam Client', icon: 'image://icon/steam' }])
})

test('arrange: shown, hidden and only-notify icons, in the user order, absent ones left out', () => {
    const icons = [
        icon('a', 'notify'),
        icon('gone', 'show'),
        icon('b', 'show'),
        icon('c', 'hide'),
        icon('d', 'show'),
    ]
    const present = [{ key: 'd' }, { key: 'c' }, { key: 'b' }, { key: 'a' }]
    assert.deepEqual(tray.arrange(icons, present, false), { shown: ['b', 'd'], hidden: ['a', 'c'] })
})

test('arrange: an only-notify icon asking for attention comes onto the bar, a hidden one does not', () => {
    const icons = [icon('a', 'notify'), icon('b', 'hide'), icon('c', 'show')]
    const present = [{ key: 'a', attention: true }, { key: 'b', attention: true }, { key: 'c' }]
    assert.deepEqual(tray.arrange(icons, present, false), { shown: ['a', 'c'], hidden: ['b'] })
})

test('arrange: an icon not remembered yet goes to the flyout, after the others', () => {
    const present = [{ key: 'new' }, { key: 'a' }]
    assert.deepEqual(tray.arrange([icon('a', 'hide')], present, false), { shown: [], hidden: ['a', 'new'] })
})

test('arrange: "always show all" puts every icon on the bar, in order', () => {
    const icons = [icon('a', 'hide'), icon('b', 'notify'), icon('c', 'show')]
    const present = [{ key: 'a' }, { key: 'b' }, { key: 'c' }]
    assert.deepEqual(tray.arrange(icons, present, true), { shown: ['a', 'b', 'c'], hidden: [] })
})

test('place: dragged from the flyout onto the bar, it is always shown, in the gap it was dropped in', () => {
    const icons = [icon('a', 'show'), icon('h', 'notify'), icon('b', 'show')]
    const result = tray.placeIcon(icons, 'h', true, ['a', 'b'], 1)
    assert.deepEqual(keys(result), ['a:show', 'h:show', 'b:show'])
})

test('place: after the last icon on the bar goes right after it, not after the flyout icons', () => {
    const icons = [icon('a', 'show'), icon('b', 'show'), icon('x', 'hide'), icon('h', 'notify')]
    const result = tray.placeIcon(icons, 'h', true, ['a', 'b'], 2)
    assert.deepEqual(keys(result), ['a:show', 'b:show', 'h:show', 'x:hide'])
})

test('place: moving an icon along the bar counts its own empty place', () => {
    const icons = [icon('a', 'show'), icon('b', 'show'), icon('c', 'show')]
    // a dropped in the gap between b and c.
    assert.deepEqual(keys(tray.placeIcon(icons, 'a', true, ['a', 'b', 'c'], 2)), ['b:show', 'a:show', 'c:show'])
    // Dropped next to itself, nothing moves.
    assert.deepEqual(keys(tray.placeIcon(icons, 'b', true, ['a', 'b', 'c'], 1)), ['a:show', 'b:show', 'c:show'])
    assert.deepEqual(keys(tray.placeIcon(icons, 'b', true, ['a', 'b', 'c'], 2)), ['a:show', 'b:show', 'c:show'])
    assert.deepEqual(keys(tray.placeIcon(icons, 'c', true, ['a', 'b', 'c'], 0)), ['c:show', 'a:show', 'b:show'])
})

test('place: into the flyout, a shown icon becomes only-notify, a hidden one stays hidden', () => {
    const icons = [icon('a', 'show'), icon('x', 'hide'), icon('y', 'notify')]
    assert.deepEqual(keys(tray.placeIcon(icons, 'a', false, ['x', 'y'], 1)), ['x:hide', 'a:notify', 'y:notify'])
    assert.deepEqual(keys(tray.placeIcon(icons, 'x', false, ['x', 'y'], 2)), ['a:show', 'y:notify', 'x:hide'])
})

test('place: into an empty place, or an icon never remembered, still lands somewhere', () => {
    assert.deepEqual(keys(tray.placeIcon([icon('a', 'show')], 'a', false, [], 0)), ['a:notify'])
    assert.deepEqual(keys(tray.placeIcon([icon('a', 'show')], 'new', true, ['a'], 0)), ['new:show', 'a:show'])
})

test('behavior: set one, ignore a word that is not a behavior, restore every default', () => {
    const icons = [icon('a', 'show'), icon('b', 'hide')]
    assert.deepEqual(keys(tray.setBehavior(icons, 'b', 'show')), ['a:show', 'b:show'])
    assert.equal(tray.setBehavior(icons, 'b', 'always'), icons)
    assert.deepEqual(keys(tray.restoreDefaults(icons)), ['a:notify', 'b:notify'])
})

test('grid: as square as it can be', () => {
    assert.equal(tray.gridColumns(0), 1)
    assert.equal(tray.gridColumns(1), 1)
    assert.equal(tray.gridColumns(2), 2)
    assert.equal(tray.gridColumns(4), 2)
    assert.equal(tray.gridColumns(5), 3)
    assert.equal(tray.gridColumns(9), 3)
    assert.equal(tray.gridColumns(10), 4)
})

test('grid gap: the row under the pointer, the gap before the first icon right of it', () => {
    // Two rows of two 30px icons, then one in the third row.
    const slot = (column, row) => ({ left: column * 30, top: row * 30, right: column * 30 + 30, bottom: row * 30 + 30 })
    const slots = [slot(0, 0), slot(1, 0), slot(0, 1), slot(1, 1), slot(0, 2)]
    assert.deepEqual(tray.gridGapAt(5, 5, slots), { gap: 0, x: 0, top: 0, bottom: 30 })
    assert.deepEqual(tray.gridGapAt(20, 5, slots), { gap: 1, x: 30, top: 0, bottom: 30 })
    assert.deepEqual(tray.gridGapAt(50, 40, slots), { gap: 4, x: 60, top: 30, bottom: 60 })
    // Right of the short last row: after its only icon.
    assert.deepEqual(tray.gridGapAt(55, 70, slots), { gap: 5, x: 30, top: 60, bottom: 90 })
    // Above and below the grid: the closest row.
    assert.deepEqual(tray.gridGapAt(35, -20, slots).gap, 1)
    assert.deepEqual(tray.gridGapAt(5, 200, slots).gap, 4)
    assert.equal(tray.gridGapAt(0, 0, []), null)
})
