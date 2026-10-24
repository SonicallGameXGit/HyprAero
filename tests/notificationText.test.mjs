import test, { before, after } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// Run as in Quickshell's JavaScript engine (measured on Quickshell 0.3.2): strings have no `trimEnd` or
// `trimStart`, and `Array.from` splits a string into UTF-16 units, an emoji into two halves. Node has them
// all, so without this a script that needs them passes here and fails in the module.
const original = { trimEnd: String.prototype.trimEnd, trimStart: String.prototype.trimStart, from: Array.from }
before(() => {
    delete String.prototype.trimEnd
    delete String.prototype.trimStart
    Array.from = (value, ...rest) => typeof value === 'string' ? value.split('') : original.from(value, ...rest)
})
after(() => {
    String.prototype.trimEnd = original.trimEnd
    String.prototype.trimStart = original.trimStart
    Array.from = original.from
})

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/notificationText.js', import.meta.url), 'utf8').replace('.pragma library', '')
const notificationText = new Function(source + '\nreturn { plainText, cut, words }')()

test('markup an app sent anyway loses its tags; a line break stays', () => {
    assert.equal(notificationText.plainText('<b>Alice</b> said:<br/>Hi <a href="x">there</a>'), 'Alice said:\nHi there')
})

test('entities become characters, unknown ones stay as written', () => {
    assert.equal(notificationText.plainText('Tom &amp; Jerry &lt;3 &#39;hi&#39; &#x1F600; &bogus;'), 'Tom & Jerry <3 \'hi\' 😀 &bogus;')
})

test('a less-than sign that starts no tag is not a tag', () => {
    assert.equal(notificationText.plainText('2 < 3'), '2 < 3')
})

test('text within its room stays whole; longer text ends in an ellipsis', () => {
    assert.equal(notificationText.cut('short', 5), 'short')
    assert.equal(notificationText.cut('a long title ', 8), 'a long…')
    assert.equal(notificationText.cut('x'.repeat(300), 255).length, 255)
})

test('a cut never splits an emoji, and counts it as one character', () => {
    assert.equal(notificationText.cut('😀😀😀', 2), '😀…')
    assert.equal(notificationText.cut('😀😀', 2), '😀😀')
})

test('a long message is cut, whatever the engine lacks', () => {
    // The kind of text that showed the bug: a long chat message with emoji and spaces at the cut.
    const message = '🖼️ word '.repeat(60)
    const shown = notificationText.words('Title', message)
    assert.ok(shown.text.endsWith('…'))
    assert.equal(/\s…$/.test(shown.text), false)
})

test('Windows 7\'s room: 63 characters of title, 255 of words', () => {
    const shown = notificationText.words('t'.repeat(100), 'b'.repeat(400))
    assert.equal(shown.title.length, 63)
    assert.equal(shown.text.length, 255)
    assert.deepEqual(notificationText.words('  Hello ', ''), { title: 'Hello', text: '' })
})
