import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../trayGlyphs.js', import.meta.url), 'utf8').replace('.pragma library', '')
const glyphs = new Function(source + `
return {
    outline,
    badge,
    battery,
    drive,
    bluetooth,
}`)()

// Every letter `PixelGlyph` has a colour for.
const palette = new Set('.#Wgls1234rpRyYokvVnbBemMt'.split(''))

const isPicture = (rows, size) => {
    assert.equal(rows.length, size)
    for (const row of rows) {
        assert.equal(row.length, size, JSON.stringify(row))
        for (const letter of row) {
            assert.ok(palette.has(letter), `unknown letter ${letter} in ${row}`)
        }
    }
}

const every = [
    glyphs.battery(1, true, 'none'),
    glyphs.battery(0.5, false, 'none'),
    glyphs.battery(0.08, false, 'warning'),
    glyphs.battery(0, false, 'error'),
    glyphs.drive(false, 0),
    glyphs.drive(true, 5),
    glyphs.bluetooth(true),
    glyphs.bluetooth(false),
]

test('every picture is 16 x 16 in the palette\'s letters', () => {
    for (const rows of every) {
        isPicture(rows, 16)
    }
})

test('every badge is 9 x 9, and "none" draws nothing', () => {
    for (const kind of ['error', 'muted', 'warning', 'available', 'check', 'busy']) {
        isPicture(glyphs.badge(kind, 0), 9)
    }

    assert.equal(glyphs.badge('none', 0).join(''), '.'.repeat(81))
})

test('outline: an edge beside every drawn pixel, none on the diagonal', () => {
    assert.deepEqual(glyphs.outline(['...', '.W.', '...'], '#'), ['.#.', '#W#', '.#.'])
})

test('battery: fuller shows more white, plugged in shows the plug', () => {
    const white = rows => rows.join('').split('W').length - 1
    assert.ok(white(glyphs.battery(1, false, 'none')) > white(glyphs.battery(0.2, false, 'none')))
    assert.notDeepEqual(glyphs.battery(0.5, true, 'none'), glyphs.battery(0.5, false, 'none'))
})

test('busy: the dot goes round, eight frames', () => {
    const frames = [0, 1, 2, 3, 4, 5, 6, 7].map(frame => glyphs.badge('busy', frame).join(''))
    assert.equal(new Set(frames).size, 8)
    assert.equal(glyphs.badge('busy', 8).join(''), frames[0])
})

test('bluetooth: steel instead of blue while the adapter is off', () => {
    const off = glyphs.bluetooth(false).join('')
    assert.ok(/[bBe]/.test(off) === false)
    assert.ok(/[bBe]/.test(glyphs.bluetooth(true).join('')))
})
