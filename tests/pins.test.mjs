import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/pins.js', import.meta.url), 'utf8').replace('.pragma library', '')
const pins = new Function(source + '\nreturn { parsePins, serializePins, placePin, removePin, gapAt }')()

test('file: a missing or empty file pins nothing', () => {
    assert.deepEqual(pins.parsePins(''), { apps: [], problems: [] })
    assert.deepEqual(pins.parsePins('  \n'), { apps: [], problems: [] })
})

test('file: reads the apps in order', () => {
    const parsed = pins.parsePins('{ "version": 1, "apps": ["firefox.desktop", "kitty.desktop"] }')
    assert.deepEqual(parsed.apps, ['firefox.desktop', 'kitty.desktop'])
    assert.deepEqual(parsed.problems, [])
})

test('file: wrong entries and repeats are skipped and reported, the rest kept', () => {
    const parsed = pins.parsePins('{ "apps": ["a.desktop", 3, "", "a.desktop", "b.desktop"] }')
    assert.deepEqual(parsed.apps, ['a.desktop', 'b.desktop'])
    assert.equal(parsed.problems.length, 3)
})

test('file: broken JSON or the wrong shape starts fresh and says so', () => {
    assert.deepEqual(pins.parsePins('{ apps: [').apps, [])
    assert.equal(pins.parsePins('{ apps: [').problems.length, 1)
    assert.deepEqual(pins.parsePins('["a.desktop"]').apps, [])
    assert.deepEqual(pins.parsePins('{ "apps": "a.desktop" }').apps, [])
    assert.equal(pins.parsePins('{ "apps": "a.desktop" }').problems.length, 1)
})

test('file: what is written reads back the same', () => {
    const apps = ['a.desktop', 'b.desktop']
    assert.deepEqual(pins.parsePins(pins.serializePins(apps)).apps, apps)
})

test('place: a new pin goes before the given one, or at the end', () => {
    assert.deepEqual(pins.placePin(['a', 'b'], 'c', 'b'), ['a', 'c', 'b'])
    assert.deepEqual(pins.placePin(['a', 'b'], 'c', 'a'), ['c', 'a', 'b'])
    assert.deepEqual(pins.placePin(['a', 'b'], 'c', ''), ['a', 'b', 'c'])
    assert.deepEqual(pins.placePin([], 'c', ''), ['c'])
})

test('place: a pinned app moves instead of being pinned twice', () => {
    assert.deepEqual(pins.placePin(['a', 'b', 'c'], 'c', 'a'), ['c', 'a', 'b'])
    assert.deepEqual(pins.placePin(['a', 'b', 'c'], 'a', ''), ['b', 'c', 'a'])
    assert.deepEqual(pins.placePin(['a', 'b', 'c'], 'a', 'c'), ['b', 'a', 'c'])
})

test('place: dropping a pin next to itself changes nothing', () => {
    assert.deepEqual(pins.placePin(['a', 'b', 'c'], 'b', 'b'), ['a', 'b', 'c'])
    assert.deepEqual(pins.placePin(['a', 'b', 'c'], 'b', 'c'), ['a', 'b', 'c'])
    assert.deepEqual(pins.placePin(['a', 'b', 'c'], 'c', ''), ['a', 'b', 'c'])
})

test('place: an unknown neighbour (an app not installed any more) puts it at the end', () => {
    assert.deepEqual(pins.placePin(['a', 'b'], 'c', 'gone'), ['a', 'b', 'c'])
})

test('remove: takes the app out, the others keep their order', () => {
    assert.deepEqual(pins.removePin(['a', 'b', 'c'], 'b'), ['a', 'c'])
    assert.deepEqual(pins.removePin(['a'], 'x'), ['a'])
})

test('gap: the pointer picks the closest gap between pins', () => {
    const slots = [{ left: 0, right: 30 }, { left: 34, right: 64 }]
    assert.equal(pins.gapAt(-10, slots), 0)
    assert.equal(pins.gapAt(14, slots), 0)
    assert.equal(pins.gapAt(16, slots), 1)
    assert.equal(pins.gapAt(48, slots), 1)
    assert.equal(pins.gapAt(50, slots), 2)
    assert.equal(pins.gapAt(200, slots), 2)
    assert.equal(pins.gapAt(5, []), 0)
})
