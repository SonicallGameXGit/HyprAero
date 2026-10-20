import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/iconColor.js', import.meta.url), 'utf8').replace('.pragma library', '')
const iconColor = new Function(source + '\nreturn { dominantColor, toHsv, cached, remember }')()

// RGBA data of `count` pixels of each colour given as [red, green, blue, alpha].
function pixels(...parts) {
    const data = []
    for (const [count, colour] of parts) {
        for (let index = 0; index < count; index++) {
            data.push(...colour)
        }
    }

    return data
}

function hueOf(hexColour) {
    const red = parseInt(hexColour.slice(1, 3), 16)
    const green = parseInt(hexColour.slice(3, 5), 16)
    const blue = parseInt(hexColour.slice(5, 7), 16)
    return iconColor.toHsv(red, green, blue)
}

test('a red icon lights red, made bright', () => {
    const colour = iconColor.dominantColor(pixels([100, [200, 30, 40, 255]]))
    const hsv = hueOf(colour)
    assert.ok(hsv.hue < 0.03 || hsv.hue > 0.97)
    assert.equal(hsv.value, 1)
})

test('the most common hue wins over a smaller one', () => {
    const colour = iconColor.dominantColor(pixels([70, [30, 90, 220, 255]], [30, [230, 140, 20, 255]]))
    const hsv = hueOf(colour)
    assert.ok(hsv.hue > 0.55 && hsv.hue < 0.7, 'blue, got ' + colour)
})

test('greys, white and black do not count, the coloured part does', () => {
    const colour = iconColor.dominantColor(pixels([60, [255, 255, 255, 255]], [20, [40, 40, 40, 255]], [20, [40, 200, 60, 255]]))
    const hsv = hueOf(colour)
    assert.ok(hsv.hue > 0.25 && hsv.hue < 0.42, 'green, got ' + colour)
})

test('an icon without a colour of its own has none', () => {
    assert.equal(iconColor.dominantColor(pixels([100, [240, 240, 240, 255]], [50, [90, 90, 90, 255]])), '')
    // A few coloured pixels in a grey icon are not enough.
    assert.equal(iconColor.dominantColor(pixels([97, [200, 200, 200, 255]], [3, [255, 0, 0, 255]])), '')
})

test('see-through pixels are left out', () => {
    assert.equal(iconColor.dominantColor(pixels([100, [255, 0, 0, 20]])), '')
    assert.equal(iconColor.dominantColor([]), '')
    const colour = iconColor.dominantColor(pixels([90, [255, 0, 0, 10]], [10, [20, 60, 230, 255]]))
    const hsv = hueOf(colour)
    assert.ok(hsv.hue > 0.55 && hsv.hue < 0.7, 'blue, got ' + colour)
})

test('a hue on the border of two buckets is not split away', () => {
    // Two oranges either side of 30 degrees outweigh a blue that is larger than each alone.
    const colour = iconColor.dominantColor(pixels([30, [255, 120, 20, 255]], [30, [255, 160, 20, 255]], [40, [20, 60, 230, 255]]))
    const hsv = hueOf(colour)
    assert.ok(hsv.hue > 0.03 && hsv.hue < 0.14, 'orange, got ' + colour)
})

test('an icon is remembered once read, a colourless one too', () => {
    assert.equal(iconColor.cached('image://icon/a'), undefined)
    assert.equal(iconColor.remember('image://icon/a', '#ff0000'), '#ff0000')
    assert.equal(iconColor.cached('image://icon/a'), '#ff0000')
    iconColor.remember('image://icon/b', '')
    assert.equal(iconColor.cached('image://icon/b'), '')
    assert.equal(iconColor.cached('toString'), undefined)
})

test('the result is a colour in #rrggbb', () => {
    assert.match(iconColor.dominantColor(pixels([10, [10, 200, 200, 255]])), /^#[0-9a-f]{6}$/)
})
