import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/peek.js', import.meta.url), 'utf8').replace('.pragma library', '')
const { worthPeeking, peekLayout, peekMode, peekPlace, worthPeekingWorkspace, visibleRect, stackOrder, peekScene, sceneKey, staysMapped } = new Function(source + '\nreturn { worthPeeking, peekLayout, peekMode, peekPlace, worthPeekingWorkspace, visibleRect, stackOrder, peekScene, sceneKey, staysMapped }')()

const window = (address, workspaceId, floating) => ({ address: address, workspaceId: workspaceId, floating: floating })

test('the only tiled window of a workspace on screen is not worth peeking at', () => {
    const only = window('0x1', 1, false)
    assert.equal(worthPeeking(only, [only], [1]), false)
})

test('a window with company on a shown workspace is worth peeking at', () => {
    const first = window('0x1', 1, false)
    const second = window('0x2', 1, false)
    assert.equal(worthPeeking(first, [first, second], [1]), true)
})

test('a window of a workspace that is not on screen is worth peeking at', () => {
    const only = window('0x1', 3, false)
    assert.equal(worthPeeking(only, [only], [1]), true)
})

test('a lone floating window is worth peeking at, it is shown bigger', () => {
    const only = window('0x1', 1, true)
    assert.equal(worthPeeking(only, [only], [1]), true)
})

test('an unknown window is not worth peeking at', () => {
    assert.equal(worthPeeking(undefined, [], [1]), false)
    assert.equal(worthPeeking(null, [], [1]), false)
})

const chrome = { border: 8, title: 28 }

test('a wide window is limited by the width, centred, picture inside the frame', () => {
    const layout = peekLayout(2, { width: 1000, height: 800 }, 20, chrome)
    // 1000 - 40 - 16 = 944 wide available, 800 - 40 - 16 - 28 = 716 high: 944 / 2 = 472 < 716.
    // The frame is 960 x 516, so it sits at (20, 142) and the picture 8px in and 28px + 8px down.
    assert.deepEqual(layout.frame, { x: 20, y: 142, width: 960, height: 516 })
    assert.deepEqual(layout.picture, { x: 28, y: 178, width: 944, height: 472 })
})

test('a tall window is limited by the height and keeps its proportions', () => {
    const layout = peekLayout(0.5, { width: 1000, height: 800 }, 20, chrome)
    assert.equal(layout.picture.height, 716)
    assert.equal(layout.picture.width, 358)
    assert.equal(layout.frame.width, 358 + 16)
    assert.equal(layout.frame.height, 716 + 16 + 28)
    assert.equal(layout.frame.x, Math.floor((1000 - layout.frame.width) / 2))
})

test('the picture lies inside the frame, below its title', () => {
    const layout = peekLayout(16 / 9, { width: 1920, height: 1032 }, 32, chrome)
    assert.equal(layout.picture.x, layout.frame.x + chrome.border)
    assert.equal(layout.picture.y, layout.frame.y + chrome.border + chrome.title)
    assert.equal(layout.picture.x + layout.picture.width + chrome.border, layout.frame.x + layout.frame.width)
    assert.equal(layout.picture.y + layout.picture.height + chrome.border, layout.frame.y + layout.frame.height)
})

test('no room or no proportions give no layout', () => {
    assert.equal(peekLayout(0, { width: 1000, height: 800 }, 20, chrome), null)
    assert.equal(peekLayout(1.5, { width: 50, height: 800 }, 20, chrome), null)
})

const placed = (address, workspaceId, floating, extra) => Object.assign({
    address: address,
    workspaceId: workspaceId,
    floating: floating,
    fullscreen: false,
    at: { x: 1300, y: 40 },
    monitor: { x: 1280, y: 0, width: 1920, height: 1080 },
    width: 400,
    height: 300,
}, extra)

test('fullscreen and a lone tiled window are lifted out, framed', () => {
    const full = placed('0x1', 1, true, { fullscreen: true })
    const lone = placed('0x2', 2, false)
    assert.equal(peekMode(full, [full]), 'fit')
    assert.equal(peekMode(lone, [lone]), 'fit')
})

test('a floating window and a tiled one beside others stay where they are', () => {
    const floating = placed('0x1', 1, true)
    const tiled = placed('0x2', 2, false)
    const other = placed('0x3', 2, false)
    assert.equal(peekMode(floating, [floating]), 'place')
    assert.equal(peekMode(tiled, [tiled, other]), 'place')
})

test('without a known place it falls back to the frame', () => {
    const floating = placed('0x1', 1, true, { at: null })
    assert.equal(peekMode(floating, [floating]), 'fit')
})

test('the place is relative to the monitor, at the real size', () => {
    assert.deepEqual(peekPlace(placed('0x1', 1, true)), { x: 20, y: 40, width: 400, height: 300 })
})

test('a window lying on its monitor is visible whole, relative to the monitor', () => {
    assert.deepEqual(visibleRect(placed('0x1', 1, true)), { x: 20, y: 40, width: 400, height: 300 })
})

test('a window hanging off the monitor is visible only where it lies on it', () => {
    const left = placed('0x1', 1, true, { at: { x: 1180, y: 40 } })
    assert.deepEqual(visibleRect(left), { x: 0, y: 40, width: 300, height: 300 })
    const big = placed('0x2', 1, true, { at: { x: 1200, y: -100 }, width: 3000, height: 1400 })
    assert.deepEqual(visibleRect(big), { x: 0, y: 0, width: 1920, height: 1080 })
})

test('a window wholly off the monitor or of unknown place has no visible part', () => {
    assert.equal(visibleRect(placed('0x1', 1, true, { at: { x: 3500, y: 0 } })), null)
    assert.equal(visibleRect(placed('0x2', 1, true, { at: null })), null)
})

test('floating windows are drawn over tiled ones, the latest focused last', () => {
    const tiledOld = placed('0xa', 1, false, { focusOrder: 3 })
    const tiledNew = placed('0xb', 1, false, { focusOrder: 0 })
    const floatingOld = placed('0xc', 1, true, { focusOrder: 2 })
    const floatingNew = placed('0xd', 1, true, { focusOrder: 1 })
    const order = stackOrder([floatingNew, tiledNew, floatingOld, tiledOld]).map(window => window.address)
    assert.deepEqual(order, ['0xa', '0xb', '0xc', '0xd'])
})

test('a workspace is worth peeking at when it has windows and is not on screen', () => {
    const windows = [placed('0x1', 2, false)]
    assert.equal(worthPeekingWorkspace(2, windows, [1]), true)
    assert.equal(worthPeekingWorkspace(2, windows, [2]), false)
    assert.equal(worthPeekingWorkspace(3, windows, [1]), false)
})

test('a window of a workspace not on screen: the others under it on the backdrop, all darkened but it', () => {
    const wanted = placed('0x1', 2, true, { focusOrder: 0 })
    const tiled = placed('0x2', 2, false, { focusOrder: 1 })
    const elsewhere = placed('0x3', 5, false)
    const scene = peekScene({ kind: 'window', address: '0x1' }, [wanted, tiled, elsewhere], [1])
    assert.equal(scene.mode, 'compose')
    assert.equal(scene.base, 'backdrop')
    assert.equal(scene.scrim, true)
    assert.equal(scene.highlight.address, '0x1')
    assert.deepEqual(scene.windows.map(window => window.address), ['0x2'])
})

test('a window of the workspace on screen: what is really there shows through, darkened', () => {
    const wanted = placed('0x1', 1, true)
    const other = placed('0x2', 1, false)
    const scene = peekScene({ kind: 'window', address: '0x1' }, [wanted, other], [1])
    assert.equal(scene.base, 'none')
    assert.equal(scene.scrim, true)
    assert.deepEqual(scene.windows, [])
})

test('a lone tiled window is lifted out, framed', () => {
    const lone = placed('0x1', 2, false)
    const scene = peekScene({ kind: 'window', address: '0x1' }, [lone], [1])
    assert.equal(scene.mode, 'fit')
    assert.equal(scene.base, 'backdrop')
    assert.equal(scene.highlight.address, '0x1')
})

test('a workspace: all its windows, nothing highlighted or darkened; none when on screen or empty', () => {
    const first = placed('0x1', 2, false, { focusOrder: 1 })
    const second = placed('0x2', 2, false, { focusOrder: 0 })
    const scene = peekScene({ kind: 'workspace', workspaceId: 2 }, [first, second], [1])
    assert.equal(scene.base, 'backdrop')
    assert.equal(scene.scrim, false)
    assert.equal(scene.highlight, null)
    assert.deepEqual(scene.windows.map(window => window.address), ['0x1', '0x2'])
    assert.equal(peekScene({ kind: 'workspace', workspaceId: 2 }, [first, second], [2]), null)
    assert.equal(peekScene({ kind: 'workspace', workspaceId: 7 }, [first, second], [1]), null)
    assert.equal(peekScene({ kind: 'window', address: '0x9' }, [first], [1]), null)
})

test('the scene key changes with what is drawn only', () => {
    const wanted = placed('0x1', 2, true)
    const other = placed('0x2', 2, false)
    const key = sceneKey(peekScene({ kind: 'window', address: '0x1' }, [wanted, other], [1]))
    const again = sceneKey(peekScene({ kind: 'window', address: '0x1' }, [Object.assign({}, wanted), Object.assign({}, other)], [1]))
    assert.equal(again, key)
    const moved = sceneKey(peekScene({ kind: 'window', address: '0x1' }, [Object.assign({}, wanted, { at: { x: 1400, y: 40 } }), other], [1]))
    assert.notEqual(moved, key)
    assert.equal(sceneKey(null), '')
})

test('the layer stays mapped once the peek ends while a menu is open over the bar', () => {
    assert.equal(staysMapped(false, true, false), true)
    assert.equal(staysMapped(true, false, true), true)
    assert.equal(staysMapped(true, false, false), false)
    assert.equal(staysMapped(false, false, true), false)
})
