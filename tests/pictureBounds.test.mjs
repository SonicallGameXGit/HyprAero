import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/pictureBounds.js', import.meta.url), 'utf8').replace('.pragma library', '')
const opaqueBounds = new Function(source + '\nreturn opaqueBounds')()

// A width x height RGBA picture, transparent except the given [x, y, alpha] pixels.
const picture = (width, height, pixels) => {
    const data = new Uint8ClampedArray(width * height * 4)
    for (const [x, y, alpha] of pixels) {
        data[(y * width + x) * 4 + 3] = alpha
    }

    return data
}

test('a fully drawn picture keeps all of it', () => {
    const data = picture(2, 2, [[0, 0, 255], [1, 1, 255]])
    assert.deepEqual(opaqueBounds(data, 2, 2, 128), { x: 0, y: 0, width: 1, height: 1 })
})

test('blank margins on any side are cut', () => {
    const data = picture(4, 4, [[1, 1, 255], [2, 2, 255]])
    assert.deepEqual(opaqueBounds(data, 4, 4, 128), { x: 0.25, y: 0.25, width: 0.5, height: 0.5 })
})

test('pixels fainter than the threshold count as blank', () => {
    const data = picture(4, 1, [[0, 0, 40], [2, 0, 255]])
    assert.deepEqual(opaqueBounds(data, 4, 1, 128), { x: 0.5, y: 0, width: 0.25, height: 1 })
})

test('a blank picture has no bounds', () => {
    assert.equal(opaqueBounds(picture(3, 3, []), 3, 3, 128), null)
})
