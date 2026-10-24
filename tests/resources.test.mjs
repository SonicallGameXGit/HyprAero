import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync, existsSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../resources/icons/frames.js', import.meta.url), 'utf8').replace('.pragma library', '')
const { frames, frameFor } = new Function(source + '\nreturn { frames, frameFor }')()

test('every frame listed is in the folder', () => {
    for (const [name, sizes] of Object.entries(frames)) {
        for (const size of sizes) {
            assert.ok(existsSync(new URL(`../resources/icons/${name}-${size}.png`, import.meta.url)), `${name}-${size}.png`)
        }
    }
})

test('the frame drawn for a size: its own, else the next bigger, else the biggest', () => {
    assert.equal(frameFor('error', 16), 16)
    assert.equal(frameFor('error', 20), 24)
    assert.equal(frameFor('warning', 64), 48)
    assert.equal(frameFor('nothing', 16), 0)
})
