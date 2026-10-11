import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/appUsage.js', import.meta.url), 'utf8').replace('.pragma library', '')
const usage = new Function(source + '\nreturn { scoreAt, addUse, useDue, scoresAt, parseState, serializeState, halfLife, useGap, day }')()

const now = 1_800_000_000_000

test('an app never used scores 0', () => {
    assert.equal(usage.scoreAt(undefined, now), 0)
    assert.equal(usage.scoreAt(null, now), 0)
})

test('a score halves every half-life', () => {
    const record = { score: 8, time: now }
    assert.equal(usage.scoreAt(record, now), 8)
    assert.equal(usage.scoreAt(record, now + usage.halfLife), 4)
    assert.equal(usage.scoreAt(record, now + 3 * usage.halfLife), 1)
})

test('a clock gone back in time does not raise a score', () => {
    assert.equal(usage.scoreAt({ score: 3, time: now }, now - usage.day), 3)
})

test('a use adds 1 to the decayed score', () => {
    const record = usage.addUse({ score: 6, time: now - usage.halfLife }, now)
    assert.deepEqual(record, { score: 4, time: now })
    assert.deepEqual(usage.addUse(undefined, now), { score: 1, time: now })
})

test('daily use this week outranks heavy use months ago', () => {
    const old = { score: 300, time: now - 180 * usage.day }
    let recent = undefined
    for (let day = 7; day > 0; day--) {
        recent = usage.addUse(recent, now - day * usage.day)
    }

    assert.ok(usage.scoreAt(recent, now) > usage.scoreAt(old, now))
})

test('a use counts at most once per gap', () => {
    const record = { score: 1, time: now }
    assert.equal(usage.useDue(undefined, now), true)
    assert.equal(usage.useDue(record, now + 1000), false)
    assert.equal(usage.useDue(record, now + usage.useGap), true)
    // A clock that went back must not block counting forever.
    assert.equal(usage.useDue(record, now - 1000), true)
})

test('scores of every app at one moment', () => {
    const scores = usage.scoresAt({ a: { score: 2, time: now }, b: { score: 2, time: now - usage.halfLife } }, now)
    assert.deepEqual(scores, { a: 2, b: 1 })
})

test('an empty file is a fresh start without problems', () => {
    assert.deepEqual(usage.parseState('', now), { featured: [], usage: {}, problems: [] })
    assert.deepEqual(usage.parseState('  \n', now), { featured: [], usage: {}, problems: [] })
})

test('broken JSON is a fresh start, and says so', () => {
    const state = usage.parseState('{ "featured": [', now)
    assert.deepEqual(state.featured, [])
    assert.deepEqual(state.usage, {})
    assert.equal(state.problems.length, 1)
})

test('valid entries are kept, bad ones dropped and reported', () => {
    const text = JSON.stringify({
        version: 1,
        featured: ['kitty', 'kitty', 4, '', 'vivaldi'],
        usage: {
            kitty: { score: 2, time: now },
            nan: { score: 'x', time: now },
            negative: { score: -1, time: now },
            missing: { score: 1 },
        },
    })
    const state = usage.parseState(text, now)
    assert.deepEqual(state.featured, ['kitty', 'vivaldi'])
    assert.deepEqual(state.usage, { kitty: { score: 2, time: now } })
    assert.equal(state.problems.length, 6)
})

test('records faded to almost nothing are forgotten quietly', () => {
    const text = JSON.stringify({ usage: { old: { score: 1, time: now - 120 * usage.day }, fresh: { score: 1, time: now } } })
    const state = usage.parseState(text, now)
    assert.deepEqual(Object.keys(state.usage), ['fresh'])
    assert.deepEqual(state.problems, [])
})

test('wrong shapes are ignored with a problem each', () => {
    assert.equal(usage.parseState('[]', now).problems.length, 1)
    assert.equal(usage.parseState('{ "featured": "kitty", "usage": [] }', now).problems.length, 2)
})

test('what is written reads back the same', () => {
    const featured = ['kitty']
    const records = { kitty: { score: 1.5, time: now } }
    const state = usage.parseState(usage.serializeState(featured, records), now)
    assert.deepEqual(state, { featured: featured, usage: records, problems: [] })
})
