import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../config/settings.js', import.meta.url), 'utf8').replace('.pragma library', '')
const parseConfig = new Function(source + '\nreturn parseConfig')()
const defaults = new Function(source + '\nreturn defaults')()

test('no file means every default and nothing to report', () => {
    const { values, problems } = parseConfig('')
    assert.deepEqual(values, defaults)
    assert.deepEqual(problems, [])
})

test('only what the user wrote changes; the rest keeps its default', () => {
    const { values, problems } = parseConfig('{ "startMenu": { "touchControls": true } }')
    assert.equal(values.startMenu.touchControls, true)
    assert.equal(values.startMenu.countFocus, defaults.startMenu.countFocus)
    assert.deepEqual(problems, [])
})

test('a value of the wrong kind falls back to its default and says so', () => {
    const { values, problems } = parseConfig('{ "startMenu": { "touchControls": "yes", "countFocus": false } }')
    assert.equal(values.startMenu.touchControls, false)
    assert.equal(values.startMenu.countFocus, false)
    assert.equal(problems.length, 1)
    assert.match(problems[0], /startMenu\.touchControls.*boolean.*string/)
})

test('unknown groups and settings are ignored and reported, so a typo is noticed', () => {
    const { values, problems } = parseConfig('{ "startmenu": {}, "startMenu": { "touchControl": true } }')
    assert.deepEqual(values, defaults)
    assert.equal(problems.length, 2)
    assert.match(problems[0], /"startmenu"/)
    assert.match(problems[1], /"startMenu\.touchControl"/)
})

test('a file that is not JSON, or not an object, gives every default', () => {
    for (const text of ['{ "startMenu": ', '[1, 2]', '42', 'null']) {
        const { values, problems } = parseConfig(text)
        assert.deepEqual(values, defaults)
        assert.equal(problems.length, 1)
    }
})

test('a group that is not an object keeps its defaults', () => {
    const { values, problems } = parseConfig('{ "startMenu": true }')
    assert.deepEqual(values, defaults)
    assert.equal(problems.length, 1)
})

test('reading never changes the defaults themselves', () => {
    parseConfig('{ "startMenu": { "touchControls": true } }')
    assert.equal(defaults.startMenu.touchControls, false)
})

const setSetting = new Function(source + '\nreturn setSetting')()

test('changing a setting keeps everything else in the file', () => {
    const text = setSetting('{ "startMenu": { "touchControls": true, "typo": 1 } }', 'tray', 'showAll', true)
    assert.deepEqual(JSON.parse(text), { startMenu: { touchControls: true, typo: 1 }, tray: { showAll: true } })
    assert.deepEqual(JSON.parse(setSetting('', 'tray', 'showAll', true)), { tray: { showAll: true } })
})

test('a setting set back to its default leaves the file, with its group when that is empty', () => {
    assert.deepEqual(JSON.parse(setSetting('{ "tray": { "showAll": true } }', 'tray', 'showAll', false)), {})
    const text = setSetting('{ "startMenu": { "touchControls": true, "countFocus": false } }', 'startMenu', 'countFocus', true)
    assert.deepEqual(JSON.parse(text), { startMenu: { touchControls: true } })
})

test('a file that cannot be changed safely, or an unknown setting, is refused', () => {
    assert.equal(setSetting('{ broken', 'tray', 'showAll', true), null)
    assert.equal(setSetting('[]', 'tray', 'showAll', true), null)
    assert.equal(setSetting('{ "tray": 3 }', 'tray', 'showAll', true), null)
    assert.equal(setSetting('', 'tray', 'nope', true), null)
})

test('the peek settings default to on after half a second, and wrong kinds fall back', () => {
    assert.equal(defaults.bar.peek, true)
    assert.equal(defaults.bar.peekDelay, 500)
    assert.equal(defaults.bar.peekWorkspaces, true)
    const { values, problems } = parseConfig('{ "bar": { "peek": false, "peekDelay": "fast" } }')
    assert.equal(values.bar.peek, false)
    assert.equal(values.bar.peekDelay, 500)
    assert.equal(problems.length, 1)
    assert.match(problems[0], /bar\.peekDelay.*number.*string/)
})
