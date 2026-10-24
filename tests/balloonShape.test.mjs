import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../balloonShape.js', import.meta.url), 'utf8').replace('.pragma library', '')
const balloonShape = new Function(source + '\nreturn { outline }')()

const stem = (edge, side) => ({ edge: edge, side: side, width: 16, height: 12, inset: 20 })

// The path's corner points, as [x, y] pairs, without its arcs' radii.
const points = path => {
    const found = []
    const pattern = /(?:[ML]|A \S+ \S+ 0 0 1) (\S+) (\S+)/g
    let match = pattern.exec(path)
    while (match !== null) {
        found.push([Number(match[1]), Number(match[2])])
        match = pattern.exec(path)
    }

    return found
}

test('without a stem: a closed rounded box inside the stroke', () => {
    const path = balloonShape.outline(200, 80, 6, 1, stem('none', 'right'))
    assert.match(path, /^M 6.5 0.5 /)
    assert.match(path, / Z$/)
    for (const [x, y] of points(path)) {
        assert.ok(x >= 0.5 && x <= 199.5, `x ${x} inside`)
        assert.ok(y >= 0.5 && y <= 79.5, `y ${y} inside`)
    }
})

test('a bottom-right stem stands against its wall: upright on the right, its point at the bottom', () => {
    const path = balloonShape.outline(200, 92, 6, 1, stem('bottom', 'right'))
    const found = points(path)
    const point = found.find(([, y]) => y === 91.5)
    assert.deepEqual(point, [179.5, 91.5])
    // The upright side leaves the box's bottom edge right above the point.
    assert.ok(found.some(([x, y]) => x === 179.5 && y === 79.5))
    assert.ok(found.some(([x, y]) => x === 163.5 && y === 79.5))
})

test('a top-left stem points up at the left', () => {
    const found = points(balloonShape.outline(200, 92, 6, 1, stem('top', 'left')))
    assert.ok(found.some(([x, y]) => x === 20.5 && y === 0.5))
    // The box itself starts under the stem.
    assert.ok(found.some(([x, y]) => x === 36.5 && y === 12.5))
})

test('a centred stem has its point in the middle', () => {
    const found = points(balloonShape.outline(200, 92, 6, 1, stem('bottom', 'center')))
    assert.ok(found.some(([x, y]) => x === 100 && y === 91.5))
    assert.ok(found.some(([x, y]) => x === 92 && y === 79.5))
    assert.ok(found.some(([x, y]) => x === 108 && y === 79.5))
})

test('corners never grow past half of a small box', () => {
    const path = balloonShape.outline(10, 8, 6, 1, stem('none', 'right'))
    assert.match(path, /A 3.5 3.5 /)
})
