import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../clockHands.js', import.meta.url), 'utf8').replace('.pragma library', '')
const clock = new Function(source + '\nreturn { handAngles }')()

test('hands: noon, a quarter past three, and the creeping of the slower hands', () => {
    assert.deepEqual(clock.handAngles(new Date(2026, 9, 15, 12, 0, 0)), { second: 0, minute: 0, hour: 0 })
    assert.deepEqual(clock.handAngles(new Date(2026, 9, 15, 15, 15, 0)), { second: 0, minute: 90, hour: 97.5 })
    const half = clock.handAngles(new Date(2026, 9, 15, 6, 30, 30))
    assert.equal(half.second, 180)
    assert.equal(half.minute, 183)
    assert.equal(half.hour, 195)
})
