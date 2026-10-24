import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/settings.js', import.meta.url), 'utf8').replace('.pragma library', '')
const { parseConfig, defaults } = new Function(source + '\nreturn { parseConfig, defaults }')()

test('no file means every default and nothing to report', () => {
    const { values, problems } = parseConfig('')
    assert.deepEqual(values, defaults)
    assert.deepEqual(problems, [])
})

test('the defaults are Windows 7\'s: one balloon at a time, bottom right, 5 seconds, with a stem', () => {
    assert.equal(defaults.balloons.position, 'bottom-right')
    assert.equal(defaults.balloons.maxVisible, 1)
    assert.equal(defaults.balloons.timeout, 5000)
    assert.equal(defaults.balloons.stem, true)
})

test('only what the user wrote changes; the rest keeps its default', () => {
    const { values, problems } = parseConfig('{ "balloons": { "position": "top-left", "maxVisible": 3 } }')
    assert.equal(values.balloons.position, 'top-left')
    assert.equal(values.balloons.maxVisible, 3)
    assert.equal(values.balloons.margin, defaults.balloons.margin)
    assert.deepEqual(problems, [])
})

test('every position is accepted', () => {
    for (const position of ['top-left', 'top', 'top-right', 'left', 'center', 'right', 'bottom-left', 'bottom', 'bottom-right']) {
        const { values, problems } = parseConfig(`{ "balloons": { "position": "${position}" } }`)
        assert.equal(values.balloons.position, position)
        assert.deepEqual(problems, [])
    }
})

test('a word that is not a position falls back and lists the ones there are', () => {
    const { values, problems } = parseConfig('{ "balloons": { "position": "bottom_right" } }')
    assert.equal(values.balloons.position, 'bottom-right')
    assert.equal(problems.length, 1)
    assert.match(problems[0], /balloons\.position.*"top-left".*"bottom_right"/)
})

test('numbers out of range or not whole fall back to their default and say so', () => {
    const { values, problems } = parseConfig('{ "balloons": { "maxVisible": 0, "timeout": 2.5, "margin": -1 } }')
    assert.equal(values.balloons.maxVisible, defaults.balloons.maxVisible)
    assert.equal(values.balloons.timeout, defaults.balloons.timeout)
    assert.equal(values.balloons.margin, defaults.balloons.margin)
    assert.equal(problems.length, 3)
    assert.match(problems[0], /maxVisible.*1 to 10/)
})

test('a value of the wrong kind falls back to its default and says so', () => {
    const { values, problems } = parseConfig('{ "balloons": { "stem": "no", "monitor": "DP-1" } }')
    assert.equal(values.balloons.stem, true)
    assert.equal(values.balloons.monitor, 'DP-1')
    assert.equal(problems.length, 1)
    assert.match(problems[0], /balloons\.stem.*boolean.*string/)
})

test('unknown groups and settings are ignored and reported, so a typo is noticed', () => {
    const { values, problems } = parseConfig('{ "balloon": {}, "balloons": { "postion": "top" } }')
    assert.deepEqual(values, defaults)
    assert.equal(problems.length, 2)
    assert.match(problems[0], /"balloon"/)
    assert.match(problems[1], /"balloons\.postion"/)
})

test('a file that is not JSON, or not an object, gives every default', () => {
    for (const text of ['{ "balloons": ', '[1, 2]', '42', 'null']) {
        const { values, problems } = parseConfig(text)
        assert.deepEqual(values, defaults)
        assert.equal(problems.length, 1)
    }
})

test('reading never changes the defaults themselves', () => {
    parseConfig('{ "balloons": { "position": "top" } }')
    assert.equal(defaults.balloons.position, 'bottom-right')
})
