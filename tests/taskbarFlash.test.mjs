import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../taskbarFlash.js', import.meta.url), 'utf8').replace('.pragma library', '')
const { flashLit, flashDone } = new Function(source + '\nreturn { flashLit, flashDone }')()

const litSteps = (flashes, count) => Array.from({ length: count }, (_, step) => flashLit(step, flashes))

test('orange the moment the app asks', () => {
    assert.equal(flashLit(0, 7), true)
    assert.equal(flashLit(0, 0), true)
})

test('seven flashes, as Windows 7, then orange for good', () => {
    const lit = litSteps(7, 20)
    assert.equal(lit.filter((on, step) => on && step <= 12).length, 7)
    assert.deepEqual(lit.slice(0, 13), [true, false, true, false, true, false, true, false, true, false, true, false, true])
    assert.equal(lit.slice(12).every(on => on), true)
    assert.equal(flashDone(11, 7), false)
    assert.equal(flashDone(12, 7), true)
})

test('one flash is orange at once and stays', () => {
    assert.equal(flashDone(0, 1), true)
    assert.deepEqual(litSteps(1, 4), [true, true, true, true])
})

test('no count flashes for as long as the app asks', () => {
    assert.equal(flashDone(1000, 0), false)
    assert.equal(flashLit(999, 0), false)
    assert.equal(flashLit(1000, 0), true)
})
