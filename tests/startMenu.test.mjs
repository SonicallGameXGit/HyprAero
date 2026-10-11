import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/startMenu.js', import.meta.url), 'utf8').replace('.pragma library', '')
const menu = new Function(source + '\nreturn { buildSections, searchApps, launchCommand, terminalCommand, menuRows, searchRows, nextAppRow, appDetail }')()

const app = (id, name, extra = {}) => ({
    id: id,
    name: name,
    genericName: '',
    comment: '',
    keywords: [],
    command: [id],
    ...extra,
})
const ids = apps => apps.map(item => item.id)

const apps = [
    app('zathura', 'Zathura', { genericName: 'Document Viewer' }),
    app('firefox', 'Firefox', { genericName: 'Web Browser', comment: 'Browse the World Wide Web' }),
    app('code', 'Visual Studio Code', { keywords: ['editor'] }),
    app('kitty', 'kitty', { genericName: 'Terminal emulator' }),
    app('audacity', 'Audacity', { comment: 'Record and edit audio files' }),
    app('org.gnome.Nautilus', 'Files', { command: ['/usr/bin/nautilus', '--new-window'] }),
]

test('sections: featured apart by use, then the used ones by use, then the rest A to Z', () => {
    const scores = { zathura: 1, firefox: 5, kitty: 2, code: 2 }
    const sections = menu.buildSections(apps, scores, ['kitty', 'audacity', 'gone'])
    assert.deepEqual(ids(sections.featured), ['kitty', 'audacity'])
    assert.deepEqual(ids(sections.used), ['firefox', 'code', 'zathura'])
    assert.deepEqual(ids(sections.rest), ['org.gnome.Nautilus'])
})

test('sections: with no use at all, every app is left over, plain A to Z ignoring case', () => {
    const sections = menu.buildSections(apps, {}, [])
    assert.deepEqual(ids(sections.used), [])
    assert.deepEqual(ids(sections.rest), ['audacity', 'org.gnome.Nautilus', 'firefox', 'kitty', 'code', 'zathura'])
})

test('search: empty finds nothing (the sections show instead)', () => {
    assert.deepEqual(menu.searchApps(apps, '   ', {}), [])
})

test('search: a name start beats a word start beats the middle of a name', () => {
    const list = [app('a', 'Notepad'), app('b', 'Gnome Notes'), app('c', 'Kanotes')]
    assert.deepEqual(ids(menu.searchApps(list, 'not', {})), ['a', 'b', 'c'])
})

test('search: ignores case and surrounding spaces', () => {
    assert.deepEqual(ids(menu.searchApps(apps, '  FIRE ', {})), ['firefox'])
})

test('search: finds what an app is about, then its description, then its program', () => {
    assert.deepEqual(ids(menu.searchApps(apps, 'browser', {})), ['firefox'])
    assert.deepEqual(ids(menu.searchApps(apps, 'editor', {})), ['code'])
    assert.deepEqual(ids(menu.searchApps(apps, 'audio', {})), ['audacity'])
    assert.deepEqual(ids(menu.searchApps(apps, 'nautilus', {})), ['org.gnome.Nautilus'])
})

test('search: within a tier the more used app comes first', () => {
    const list = [app('a', 'Terminal One'), app('b', 'Terminal Two')]
    assert.deepEqual(ids(menu.searchApps(list, 'term', { b: 3 })), ['b', 'a'])
    assert.deepEqual(ids(menu.searchApps(list, 'term', {})), ['a', 'b'])
})

test('launch: a normal app runs its own command', () => {
    assert.deepEqual(menu.launchCommand(['firefox', '--new-window'], false), ['firefox', '--new-window'])
})

test('launch: a terminal app goes through sh with its arguments as parameters, never as code', () => {
    const command = menu.launchCommand(['btop', '; rm -rf ~'], true)
    assert.equal(command[0], 'sh')
    assert.equal(command[1], '-c')
    assert.equal(command[3], 'sh')
    assert.deepEqual(command.slice(4), ['btop', '; rm -rf ~'])
    assert.equal(command[2].includes('rm -rf'), false)
})

test('launch: no arguments opens a plain terminal', () => {
    assert.deepEqual(menu.terminalCommand([]).slice(3), ['sh'])
})

const kinds = rows => rows.map(row => row.kind === 'app' ? row.app.id : row.kind + ':' + row.section)

test('rows: top to bottom, featured, the line, most used, the line, the rest', () => {
    const rows = menu.menuRows({ featured: [app('kitty', 'kitty')], used: [app('firefox', 'Firefox')], rest: [app('a', 'A')] })
    assert.deepEqual(kinds(rows), ['header:featured', 'kitty', 'separator:', 'header:used', 'firefox', 'separator:', 'a'])
})

test('rows: no featured app yet shows a hint in its place', () => {
    const rows = menu.menuRows({ featured: [], used: [], rest: [app('a', 'A')] })
    assert.deepEqual(kinds(rows), ['header:featured', 'hint:featured', 'separator:', 'a'])
})

test('rows: an empty section leaves out its header and its line', () => {
    const rows = menu.menuRows({ featured: [app('kitty', 'kitty')], used: [app('firefox', 'Firefox')], rest: [] })
    assert.deepEqual(kinds(rows), ['header:featured', 'kitty', 'separator:', 'header:used', 'firefox'])
})

test('rows: a search shows its header over its results, or a hint when nothing matched', () => {
    assert.deepEqual(kinds(menu.searchRows([app('a', 'A'), app('b', 'B')])), ['header:search', 'a', 'b'])
    assert.deepEqual(kinds(menu.searchRows([])), ['hint:search'])
})

test('keyboard: steps skip headers and separators and stop at the ends', () => {
    const rows = menu.menuRows({ featured: [app('kitty', 'kitty')], used: [app('a', 'A')], rest: [app('b', 'B')] })
    // header, kitty, separator, header, a, separator, b
    assert.equal(menu.nextAppRow(rows, -1, 1), 1)
    assert.equal(menu.nextAppRow(rows, 1, 1), 4)
    assert.equal(menu.nextAppRow(rows, 4, 1), 6)
    assert.equal(menu.nextAppRow(rows, 6, 1), 6)
    assert.equal(menu.nextAppRow(rows, rows.length, -1), 6)
    assert.equal(menu.nextAppRow(rows, 1, -1), 1)
})

test('detail: the description, else the program, else nothing', () => {
    assert.equal(menu.appDetail(app('firefox', 'Firefox', { comment: ' Browse the Web ' })), 'Browse the Web')
    assert.equal(menu.appDetail(app('kitty', 'kitty', { command: ['/usr/bin/kitty', '--single'] })), '/usr/bin/kitty')
    assert.equal(menu.appDetail(app('x', 'X', { command: [] })), '')
})
