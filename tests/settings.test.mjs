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
