import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/balloons.js', import.meta.url), 'utf8').replace('.pragma library', '')
const balloons = new Function(source + '\nreturn { placement, shown, stemIndex, timeout, buttons, defaultAction }')()

test('bottom right, as on Windows 7: fastened there, the stem down at the right, the newest at the bottom', () => {
    assert.deepEqual(balloons.placement('bottom-right', true), {
        top: false,
        bottom: true,
        left: false,
        right: true,
        stemEdge: 'bottom',
        stemSide: 'right',
        newestFirst: false,
    })
})

test('top left points up at the left and puts the newest on top', () => {
    const placed = balloons.placement('top-left', true)
    assert.equal(placed.top && placed.left, true)
    assert.equal(placed.stemEdge, 'top')
    assert.equal(placed.stemSide, 'left')
    assert.equal(placed.newestFirst, true)
})

test('the middle of an edge centres along it, with a centred stem', () => {
    const placed = balloons.placement('bottom', true)
    assert.equal(placed.left || placed.right, false)
    assert.equal(placed.stemEdge, 'bottom')
    assert.equal(placed.stemSide, 'center')
})

test('the middle row and the centre have nothing to point at', () => {
    for (const position of ['left', 'center', 'right']) {
        const placed = balloons.placement(position, true)
        assert.equal(placed.top || placed.bottom, false)
        assert.equal(placed.stemEdge, 'none')
    }
})

test('the stem can be turned off', () => {
    assert.equal(balloons.placement('bottom-right', false).stemEdge, 'none')
})

test('one at a time: the oldest shows and the others wait', () => {
    assert.deepEqual(balloons.shown(['a', 'b', 'c'], 1, false), ['a'])
})

test('a stack shows the oldest few, the newest of them nearest the edge', () => {
    assert.deepEqual(balloons.shown(['a', 'b', 'c', 'd'], 3, false), ['a', 'b', 'c'])
    assert.deepEqual(balloons.shown(['a', 'b', 'c', 'd'], 3, true), ['c', 'b', 'a'])
    assert.deepEqual(balloons.shown([], 3, true), [])
})

test('showing never changes the list it was given', () => {
    const kept = ['a', 'b']
    balloons.shown(kept, 2, true)
    assert.deepEqual(kept, ['a', 'b'])
})

test('the stem is on the balloon nearest the edge', () => {
    assert.equal(balloons.stemIndex(3, false), 2)
    assert.equal(balloons.stemIndex(3, true), 0)
})

test('how long a balloon stays follows the app, then the setting', () => {
    assert.equal(balloons.timeout(3000, false, 5000), 3000)
    assert.equal(balloons.timeout(-1, false, 5000), 5000)
    assert.equal(balloons.timeout(0, false, 5000), 0)
})

test('a critical notification stays unless the app gave it a time', () => {
    assert.equal(balloons.timeout(-1, true, 5000), 0)
    assert.equal(balloons.timeout(8000, true, 5000), 8000)
})

test('every action is a button in the app\'s order; "default" is also the click on the balloon', () => {
    const actions = [
        { identifier: 'default', text: 'Open' },
        { identifier: 'reply', text: 'Reply' },
        { identifier: 'mark-read', text: '' },
        { identifier: 'mute', text: 'Mute chat' },
    ]
    assert.deepEqual(balloons.buttons(actions), [
        { index: 0, text: 'Open' },
        { index: 1, text: 'Reply' },
        { index: 2, text: 'mark-read' },
        { index: 3, text: 'Mute chat' },
    ])
    assert.equal(balloons.defaultAction(actions), 0)
    assert.equal(balloons.defaultAction(actions.slice(1)), -1)
})

test('"default" without words is left for the balloon to word', () => {
    assert.deepEqual(balloons.buttons([{ identifier: 'default', text: '' }]), [{ index: 0, text: '' }])
    assert.deepEqual(balloons.buttons([]), [])
})
