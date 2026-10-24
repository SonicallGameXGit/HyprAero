import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/notificationIcon.js', import.meta.url), 'utf8').replace('.pragma library', '')
const notificationIcon = new Function(source + '\nreturn { candidates, sources }')()

test('nothing given, nothing to try', () => {
    assert.deepEqual(notificationIcon.candidates(''), [])
    assert.deepEqual(notificationIcon.candidates(' , '), [])
})

test('a file path or address is a picture to load', () => {
    assert.deepEqual(notificationIcon.candidates('/tmp/a b.png'), [{ kind: 'url', url: 'file:///tmp/a b.png' }])
    assert.deepEqual(notificationIcon.candidates('file:///tmp/a.png'), [{ kind: 'url', url: 'file:///tmp/a.png' }])
})

test('the standard message icons are Windows 7\'s own', () => {
    assert.deepEqual(notificationIcon.candidates('dialog-warning'), [{ kind: 'windows', name: 'warning' }])
    assert.deepEqual(notificationIcon.candidates('dialog-error-symbolic'), [{ kind: 'windows', name: 'error' }])
    assert.deepEqual(notificationIcon.candidates('dialog-information'), [{ kind: 'windows', name: 'information' }])
    assert.deepEqual(notificationIcon.candidates('gtk-dialog-question'), [{ kind: 'windows', name: 'question' }])
})

test('any other name is a theme icon, a file extension left out', () => {
    assert.deepEqual(notificationIcon.candidates('firefox.png'), [{ kind: 'theme', name: 'firefox' }])
})

test('several icons are tried in the order given', () => {
    assert.deepEqual(notificationIcon.candidates('telegram, /usr/share/pixmaps/telegram.png'), [
        { kind: 'theme', name: 'telegram' },
        { kind: 'url', url: 'file:///usr/share/pixmaps/telegram.png' },
    ])
})

test('a picture is shown large; an image that is only an icon\'s name is the small icon', () => {
    assert.deepEqual(notificationIcon.sources('image://qsimage/1', 'chat'), {
        picture: 'image://qsimage/1',
        icons: [{ kind: 'theme', name: 'chat' }],
    })
    assert.deepEqual(notificationIcon.sources('image://icon/dialog-warning', 'chat'), {
        picture: '',
        icons: [{ kind: 'windows', name: 'warning' }, { kind: 'theme', name: 'chat' }],
    })
    assert.deepEqual(notificationIcon.sources('', ''), { picture: '', icons: [] })
})
