import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/workspaceList.js', import.meta.url), 'utf8').replace('.pragma library', '')
const buildEntries = new Function(source + '\nreturn buildEntries')()

const ids = entries => entries.map(entry => entry.id)
const entryOf = (entries, id) => entries.find(entry => entry.id === id)

test('fresh desktop shows the minimum, first one focused, no icons', () => {
    const entries = buildEntries([], [], 1, 5)
    assert.deepEqual(ids(entries), [1, 2, 3, 4, 5])
    assert.equal(entries[0].focused, true)
    assert.equal(entries.some(entry => entry.occupied), false)
    assert.equal(entries[0].mainApp, null)
    assert.equal(entries[0].secondApp, null)
})

test('existing workspaces beyond the minimum are added in order', () => {
    const entries = buildEntries([8, 2], [], 2, 5)
    assert.deepEqual(ids(entries), [1, 2, 3, 4, 5, 8])
    assert.equal(entryOf(entries, 8).occupied, true)
    assert.equal(entryOf(entries, 3).occupied, false)
})

test('a focused empty workspace beyond the minimum is still shown', () => {
    assert.deepEqual(ids(buildEntries([], [], 7, 3)), [1, 2, 3, 7])
})

test('special workspaces are never listed', () => {
    assert.deepEqual(ids(buildEntries([-98], [], -98, 2)), [1, 2])
})

test('a single app gives only a main icon, even with several windows', () => {
    const windows = [
        { workspaceId: 1, appId: 'code', area: 100 },
        { workspaceId: 1, appId: 'code', area: 50 },
    ]
    const entry = entryOf(buildEntries([1], windows, 1, 2), 1)
    assert.equal(entry.mainApp, 'code')
    assert.equal(entry.secondApp, null)
    assert.equal(entry.occupied, true)
})

test('several apps: the biggest is main, the second biggest is the badge, the rest are dropped', () => {
    const windows = [
        { workspaceId: 1, appId: 'small', area: 10 },
        { workspaceId: 1, appId: 'big', area: 300 },
        { workspaceId: 1, appId: 'middle', area: 200 },
        { workspaceId: 2, appId: 'other', area: 999 },
    ]
    const entry = entryOf(buildEntries([1, 2], windows, 1, 2), 1)
    assert.equal(entry.mainApp, 'big')
    assert.equal(entry.secondApp, 'middle')
})

test('an app counts with its biggest window', () => {
    const windows = [
        { workspaceId: 1, appId: 'a', area: 100 },
        { workspaceId: 1, appId: 'a', area: 400 },
        { workspaceId: 1, appId: 'b', area: 300 },
    ]
    const entry = entryOf(buildEntries([1], windows, 1, 1), 1)
    assert.equal(entry.mainApp, 'a')
    assert.equal(entry.secondApp, 'b')
})

test('equal sizes are ordered by app id', () => {
    const windows = [
        { workspaceId: 1, appId: 'b', area: 100 },
        { workspaceId: 1, appId: 'a', area: 100 },
    ]
    assert.equal(entryOf(buildEntries([1], windows, 1, 1), 1).mainApp, 'a')
})

test('an entry lists its own windows, biggest first, ties by app id then title', () => {
    const windows = [
        { workspaceId: 1, appId: 'b', title: 'two', area: 100 },
        { workspaceId: 1, appId: 'a', title: 'zed', area: 100 },
        { workspaceId: 1, appId: 'a', title: 'alpha', area: 100 },
        { workspaceId: 1, appId: 'big', title: 'main', area: 900 },
        { workspaceId: 2, appId: 'other', title: 'elsewhere', area: 5000 },
    ]
    const entry = entryOf(buildEntries([1, 2], windows, 1, 2), 1)
    assert.deepEqual(entry.windows.map(window => window.title), ['main', 'alpha', 'zed', 'two'])
})

test('an empty workspace has no windows', () => {
    assert.deepEqual(entryOf(buildEntries([], [], 1, 2), 1).windows, [])
})

const hangsOffMonitor = new Function(source + '\nreturn hangsOffMonitor')()
const monitor = { x: 0, y: 0, width: 1920, height: 1080 }

test('a window inside its monitor does not hang off it', () => {
    assert.equal(hangsOffMonitor([0, 0], [1920, 1080], monitor), false)
})

test('a window one pixel past any edge hangs off its monitor', () => {
    assert.equal(hangsOffMonitor([-1, 0], [800, 600], monitor), true)
    assert.equal(hangsOffMonitor([0, -1], [800, 600], monitor), true)
    assert.equal(hangsOffMonitor([1121, 0], [800, 600], monitor), true)
    assert.equal(hangsOffMonitor([0, 481], [800, 600], monitor), true)
})

test('an unknown monitor or position counts as on screen', () => {
    assert.equal(hangsOffMonitor([-100, 0], [800, 600], null), false)
    assert.equal(hangsOffMonitor(undefined, [800, 600], monitor), false)
})
