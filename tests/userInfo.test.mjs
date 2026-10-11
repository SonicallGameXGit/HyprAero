import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/userInfo.js', import.meta.url), 'utf8').replace('.pragma library', '')
const user = new Function(source + '\nreturn { userFolders, fullName, initial, avatarIndex }')()

const home = '/home/me'

test('folders: without a file, the usual names in home', () => {
    assert.deepEqual(user.userFolders('', home), [
        { key: 'documents', path: '/home/me/Documents' },
        { key: 'pictures', path: '/home/me/Pictures' },
        { key: 'music', path: '/home/me/Music' },
        { key: 'videos', path: '/home/me/Videos' },
        { key: 'downloads', path: '/home/me/Downloads' },
    ])
})

test('folders: names from user-dirs.dirs, $HOME expanded, comments and junk skipped', () => {
    const text = [
        '# This file is written by xdg-user-dirs-update',
        'XDG_DOCUMENTS_DIR="$HOME/Документы"',
        'XDG_PICTURES_DIR="/data/pictures/"',
        'XDG_MUSIC_DIR=relative',
        'XDG_VIDEOS_DIR="videos/not/absolute"',
    ].join('\n')
    const folders = user.userFolders(text, home)
    assert.equal(folders[0].path, '/home/me/Документы')
    assert.equal(folders[1].path, '/data/pictures')
    assert.equal(folders[2].path, '/home/me/Music')
    assert.equal(folders[3].path, '/home/me/Videos')
})

test('folders: one set to home is turned off and left out', () => {
    const folders = user.userFolders('XDG_MUSIC_DIR="$HOME/"\nXDG_VIDEOS_DIR="$HOME"', home)
    assert.deepEqual(folders.map(folder => folder.key), ['documents', 'pictures', 'downloads'])
})

test('full name: the first part of the comment field, or nothing', () => {
    const passwd = [
        'root:x:0:0::/root:/bin/bash',
        'me:x:1000:1000:Mikhail K,Room 1,,:/home/me:/bin/bash',
        'other:x:1001:1001:Other:/home/other:/bin/bash',
    ].join('\n')
    assert.equal(user.fullName(passwd, 'me'), 'Mikhail K')
    assert.equal(user.fullName(passwd, 'root'), '')
    assert.equal(user.fullName(passwd, 'nobody'), '')
})

test('avatar: an upper-case initial, and a stable colour within range', () => {
    assert.equal(user.initial(' mike'), 'M')
    assert.equal(user.initial(''), '?')
    const index = user.avatarIndex('sonicall', 6)
    assert.equal(index, user.avatarIndex('sonicall', 6))
    assert.ok(index >= 0 && index < 6)
})
