import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/iconOverrides.js', import.meta.url), 'utf8').replace('.pragma library', '')
const names = [
    'emptyOverrides',
    'parseOverrides',
    'serializeOverrides',
    'iconFor',
    'withIcon',
    'withoutGoneWindows',
    'reorderedWorkspaces',
    'isManaged',
    'unusedFiles',
    'managedFileName',
    'chosenFile',
    'fileFilter',
    'copyCommand',
    'listCommand',
    'parseIconFiles',
    'startIconFiles',
    'readIconFiles',
    'finishIconFiles',
    'searchIcons',
    'fileUrl',
]
const icons = new Function(source + '\nreturn { ' + names.join(', ') + ' }')()

const folder = '/home/user/.local/state/hypraero/icons'

test('file: a missing or empty file chooses nothing', () => {
    assert.deepEqual(icons.parseOverrides(''), { overrides: icons.emptyOverrides(), problems: [] })
    assert.deepEqual(icons.parseOverrides(' \n').overrides, icons.emptyOverrides())
})

test('file: reads every kind', () => {
    const parsed = icons.parseOverrides(JSON.stringify({
        version: 1,
        apps: { 'firefox.desktop': '/usr/share/icons/a.png' },
        windows: { '0x55aa': folder + '/windows-0x55aa-1.png' },
        workspaces: { 3: '/usr/share/icons/b.svg' },
    }))
    assert.deepEqual(parsed.problems, [])
    assert.equal(icons.iconFor(parsed.overrides, 'apps', 'firefox.desktop'), '/usr/share/icons/a.png')
    assert.equal(icons.iconFor(parsed.overrides, 'windows', '0x55aa'), folder + '/windows-0x55aa-1.png')
    assert.equal(icons.iconFor(parsed.overrides, 'workspaces', '3'), '/usr/share/icons/b.svg')
})

test('file: wrong keys and paths are skipped and reported, the rest kept', () => {
    const parsed = icons.parseOverrides(JSON.stringify({
        apps: { 'a.desktop': 'relative.png', 'b.desktop': '/b.png', '': '/c.png' },
        windows: { 'not-an-address': '/d.png' },
        workspaces: { 0: '/e.png', '-2': '/f.png', 'x': '/g.png', 4: 5 },
    }))
    assert.deepEqual(parsed.overrides, { apps: { 'b.desktop': '/b.png' }, windows: {}, workspaces: {} })
    assert.equal(parsed.problems.length, 7)
})

test('file: broken JSON or the wrong shape starts fresh and says so', () => {
    assert.deepEqual(icons.parseOverrides('{ apps:').overrides, icons.emptyOverrides())
    assert.equal(icons.parseOverrides('{ apps:').problems.length, 1)
    assert.equal(icons.parseOverrides('[]').problems.length, 1)
    assert.equal(icons.parseOverrides('{ "apps": [] }').problems.length, 1)
})

test('file: what is written reads back the same', () => {
    let overrides = icons.withIcon(icons.emptyOverrides(), 'apps', 'kitty.desktop', '/k.png')
    overrides = icons.withIcon(overrides, 'workspaces', '2', '/w.png')
    assert.deepEqual(icons.parseOverrides(icons.serializeOverrides(overrides)).overrides, overrides)
})

test('set: an icon is set, replaced and taken away without touching the old object', () => {
    const empty = icons.emptyOverrides()
    const set = icons.withIcon(empty, 'windows', '0xab', '/a.png')
    assert.equal(icons.iconFor(set, 'windows', '0xab'), '/a.png')
    assert.equal(icons.iconFor(empty, 'windows', '0xab'), '')
    const replaced = icons.withIcon(set, 'windows', '0xab', '/b.png')
    assert.equal(icons.iconFor(replaced, 'windows', '0xab'), '/b.png')
    assert.equal(icons.iconFor(icons.withIcon(replaced, 'windows', '0xab', ''), 'windows', '0xab'), '')
})

test('set: nothing changes for the same icon, a bad key or a relative path', () => {
    const set = icons.withIcon(icons.emptyOverrides(), 'apps', 'a.desktop', '/a.png')
    assert.equal(icons.withIcon(set, 'apps', 'a.desktop', '/a.png'), set)
    assert.equal(icons.withIcon(set, 'apps', 'b.desktop', ''), set)
    assert.equal(icons.withIcon(set, 'windows', 'abc', '/a.png'), set)
    assert.equal(icons.withIcon(set, 'workspaces', '0', '/a.png'), set)
    assert.equal(icons.withIcon(set, 'apps', 'b.desktop', 'a.png'), set)
    assert.equal(icons.withIcon(set, 'things', 'x', '/a.png'), set)
})

test('windows: only the windows still there keep their icons', () => {
    let overrides = icons.withIcon(icons.emptyOverrides(), 'windows', '0x1', '/a.png')
    overrides = icons.withIcon(overrides, 'windows', '0x2', '/b.png')
    overrides = icons.withIcon(overrides, 'apps', 'a.desktop', '/c.png')
    const kept = icons.withoutGoneWindows(overrides, ['0x2', '0x3'])
    assert.deepEqual(kept.windows, { '0x2': '/b.png' })
    assert.deepEqual(kept.apps, { 'a.desktop': '/c.png' })
    assert.equal(icons.withoutGoneWindows(kept, ['0x2']), kept)
})

test('workspaces: icons follow their buttons when one is moved right', () => {
    const before = { 1: '/a.png', 2: '/b.png', 4: '/d.png', 12: '/x.png' }
    const after = icons.reorderedWorkspaces(before, [1, 2, 3, 4], 0, 2)
    assert.deepEqual(after, { 1: '/b.png', 3: '/a.png', 4: '/d.png', 12: '/x.png' })
})

test('workspaces: icons follow their buttons when one is moved left', () => {
    const before = { 1: '/a.png', 3: '/c.png', 4: '/d.png' }
    const after = icons.reorderedWorkspaces(before, [1, 2, 3, 4], 3, 1)
    assert.deepEqual(after, { 1: '/a.png', 2: '/d.png', 4: '/c.png' })
})

test('workspaces: no move changes nothing', () => {
    const before = { 1: '/a.png' }
    assert.equal(icons.reorderedWorkspaces(before, [1, 2], 1, 1), before)
    assert.equal(icons.reorderedWorkspaces(before, [1, 2], 0, 5), before)
})

test('files: only copies inside the icons folder are managed', () => {
    assert.equal(icons.isManaged(folder + '/apps-a-1.png', folder), true)
    assert.equal(icons.isManaged(folder + '/../pins.json', folder), false)
    assert.equal(icons.isManaged(folder + '/sub/a.png', folder), false)
    assert.equal(icons.isManaged(folder + '/', folder), false)
    assert.equal(icons.isManaged('/usr/share/icons/a.png', folder), false)
    assert.equal(icons.isManaged(folder + 'evil/a.png', folder), false)
})

test('files: a copy nothing uses any more is removed, theme files and shared copies never', () => {
    const copy = folder + '/apps-a-1.png'
    let before = icons.withIcon(icons.emptyOverrides(), 'apps', 'a.desktop', copy)
    before = icons.withIcon(before, 'workspaces', '2', '/usr/share/icons/t.png')
    const after = icons.withIcon(icons.withIcon(before, 'apps', 'a.desktop', ''), 'workspaces', '2', '')
    assert.deepEqual(icons.unusedFiles(before, after, folder), [copy])
    const shared = icons.withIcon(before, 'windows', '0x1', copy)
    assert.deepEqual(icons.unusedFiles(shared, icons.withIcon(shared, 'apps', 'a.desktop', ''), folder), [])
})

test('files: a copy is named by what it is for and when, pictures only', () => {
    assert.equal(icons.managedFileName('apps', 'org.kde.dolphin.desktop', '/home/u/Pics/My Icon.PNG', 17), 'apps-org.kde.dolphin.desktop-17.png')
    assert.equal(icons.managedFileName('apps', 'a b/c', '/x/i.svg', 1), 'apps-a_b_c-1.svg')
    assert.equal(icons.managedFileName('apps', 'a', '/x/notes.txt', 1), '')
    assert.equal(icons.managedFileName('apps', 'a', '/x/noextension', 1), '')
})

test('chooser: a printed picture path is taken, anything else is not', () => {
    assert.equal(icons.chosenFile('/home/u/icon.svg\n'), '/home/u/icon.svg')
    assert.equal(icons.chosenFile(' /x.png\n'), '')
    assert.equal(icons.chosenFile(''), '')
    assert.equal(icons.chosenFile('/home/u/doc.pdf\n'), '')
    assert.equal(icons.chosenFile('/a.png\n/b.png\n'), '')
    assert.ok(icons.fileFilter('Pictures').startsWith('Pictures | *.png *.PNG *.svg'))
})

test('commands: paths are parameters of sh, never its text', () => {
    const command = icons.copyCommand('/x/a "b".png', folder, folder + '/t.png')
    assert.equal(command[0], 'sh')
    assert.equal(command[2].includes('a "b"'), false)
    assert.deepEqual(command.slice(4), [folder, '/x/a "b".png', folder + '/t.png'])
    const list = icons.listCommand([{ path: '/usr/share/icons', theme: '' }, { path: '/usr/share/pixmaps', theme: 'Pixmaps' }])
    assert.deepEqual(list.slice(0, 4), ['find', '-L', '/usr/share/icons', '/usr/share/pixmaps'])
    // Links a copied theme turned into small text files are left out.
    assert.deepEqual(list.slice(6, 8), ['-size', '+100c'])
    // Symbolic icons are a third of a big theme's files; every line left out is one less to read.
    assert.deepEqual(list.slice(8, 14), ['-not', '-path', '*/symbolic/*', '-not', '-name', '*-symbolic.*'])
})

test('list: one icon per theme and name, its best file, sorted', () => {
    const roots = [
        { path: '/home/u/.local/share/icons', theme: '' },
        { path: '/usr/share/icons', theme: '' },
        { path: '/usr/share/pixmaps', theme: 'Pixmaps' },
    ]
    const output = [
        '/usr/share/icons/hicolor/16x16/apps/firefox.png',
        '/usr/share/icons/hicolor/256x256/apps/firefox.png',
        '/usr/share/icons/hicolor/48x48/apps/firefox.png',
        '/usr/share/icons/breeze/apps/48/Firefox.svg',
        '/usr/share/icons/breeze/places/16/folder.svg',
        '/usr/share/icons/breeze/places/64/folder.svg',
        '/usr/share/icons/Adwaita/symbolic/places/folder-symbolic.svg',
        '/usr/share/icons/Adwaita/scalable/places/user-home-symbolic.svg',
        '/usr/share/icons/Adwaita/48x48@2/places/folder.png',
        '/usr/share/icons/Adwaita/64x64/places/folder.png',
        '/usr/share/icons/hicolor/index.theme',
        '/usr/share/pixmaps/htop.png',
        '/home/u/.local/share/icons/hicolor/16x16/apps/firefox.png',
        '/elsewhere/icon.png',
        '',
    ].join('\n')
    const parsed = icons.parseIconFiles(output, roots)
    assert.deepEqual(parsed.themes, ['Adwaita', 'breeze', 'hicolor', 'Pixmaps'])
    assert.deepEqual(parsed.icons, [
        { name: 'Firefox', theme: 'breeze', path: '/usr/share/icons/breeze/apps/48/Firefox.svg' },
        { name: 'firefox', theme: 'hicolor', path: '/home/u/.local/share/icons/hicolor/16x16/apps/firefox.png' },
        { name: 'folder', theme: 'Adwaita', path: '/usr/share/icons/Adwaita/48x48@2/places/folder.png' },
        { name: 'folder', theme: 'breeze', path: '/usr/share/icons/breeze/places/64/folder.svg' },
        { name: 'htop', theme: 'Pixmaps', path: '/usr/share/pixmaps/htop.png' },
    ])
})

test('list: read a part at a time, the same icons as all at once', () => {
    const roots = [
        { path: '/usr/share/icons', theme: '' },
        { path: '/usr/share/pixmaps', theme: 'Pixmaps' },
    ]
    const output = [
        '/usr/share/icons/hicolor/16x16/apps/firefox.png',
        '/usr/share/icons/breeze/apps/48/firefox.svg',
        '/usr/share/icons/hicolor/256x256/apps/firefox.png',
        '/usr/share/icons/breeze/places/64/folder.svg',
        '/usr/share/icons/Adwaita/symbolic/places/folder-symbolic.svg',
        '/usr/share/pixmaps/htop.png',
        '',
    ].join('\n')
    const reading = icons.startIconFiles(output, roots)
    const done = []
    for (let part = 0; part < 4; part++) {
        done.push(icons.readIconFiles(reading, 2))
    }

    assert.deepEqual(done, [false, false, false, true])
    assert.deepEqual(icons.finishIconFiles(reading), icons.parseIconFiles(output, roots))
    assert.equal(icons.finishIconFiles(reading).icons.length, 4)
})

test('search: every word must be in the name; the name itself, then its start, first', () => {
    const list = [
        { name: 'firefox-developer', theme: 'a', path: '/1' },
        { name: 'folder-firefox', theme: 'a', path: '/2' },
        { name: 'firefox', theme: 'a', path: '/3' },
        { name: 'firefox', theme: 'b', path: '/4' },
        { name: 'kitty', theme: 'b', path: '/5' },
    ]
    assert.deepEqual(icons.searchIcons(list, 'Firefox', '').map(icon => icon.path), ['/3', '/4', '/1', '/2'])
    assert.deepEqual(icons.searchIcons(list, 'fox dev', '').map(icon => icon.path), ['/1'])
    assert.deepEqual(icons.searchIcons(list, '  ', 'b').map(icon => icon.path), ['/4', '/5'])
    assert.deepEqual(icons.searchIcons(list, 'firefox', 'b').map(icon => icon.path), ['/4'])
    assert.deepEqual(icons.searchIcons(list, 'zzz', ''), [])
})

test('address: every part of the path is escaped', () => {
    assert.equal(icons.fileUrl('/home/u/Windows 7 Aero/a#1.png'), 'file:///home/u/Windows%207%20Aero/a%231.png')
    assert.equal(icons.fileUrl(''), '')
})
