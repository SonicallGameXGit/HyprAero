import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/launchPlacement.js', import.meta.url), 'utf8').replace('.pragma library', '')
const { addLaunch, placeWindow, liveLaunches } = new Function(source + '\nreturn { addLaunch, placeWindow, liveLaunches }')()

test('a new window of a dropped app goes to the workspace it was dropped on', () => {
    const launches = addLaunch([], 'code', 4, 1000)
    assert.equal(placeWindow(launches, 'code', 3000).workspaceId, 4)
})

test('a window of another app stays where it opened', () => {
    const launches = addLaunch([], 'code', 4, 1000)
    assert.equal(placeWindow(launches, 'discord', 2000).workspaceId, 0)
    assert.equal(placeWindow([], 'code', 2000).workspaceId, 0)
})

test('a slow app is still waited for, but not forever', () => {
    const launches = addLaunch([], 'code', 4, 0)
    assert.equal(placeWindow(launches, 'code', 29000).workspaceId, 4)
    assert.equal(placeWindow(launches, 'code', 30000).workspaceId, 0)
})

test('windows right after the first one follow it (splash, then the main window), later ones do not', () => {
    const first = placeWindow(addLaunch([], 'discord', 6, 0), 'discord', 2000)
    assert.equal(first.workspaceId, 6)
    const second = placeWindow(first.launches, 'discord', 6000)
    assert.equal(second.workspaceId, 6)
    assert.equal(placeWindow(second.launches, 'discord', 7000).workspaceId, 0)
})

test('two quick drops of one app to two workspaces give each one a window, oldest first', () => {
    let launches = addLaunch([], 'vivaldi', 3, 0)
    launches = addLaunch(launches, 'vivaldi', 5, 100)
    const first = placeWindow(launches, 'vivaldi', 1000)
    assert.equal(first.workspaceId, 3)
    const second = placeWindow(first.launches, 'vivaldi', 1100)
    assert.equal(second.workspaceId, 5)
    // Both have their window: another one right after follows the newest.
    assert.equal(placeWindow(second.launches, 'vivaldi', 1200).workspaceId, 5)
})

test('finished launches are dropped', () => {
    const launches = addLaunch(addLaunch([], 'a', 1, 0), 'b', 2, 20000)
    assert.deepEqual(liveLaunches(launches, 40000).map(launch => launch.app), ['b'])
    assert.equal(liveLaunches(launches, 60000).length, 0)
})

test('placing never changes the list it was given', () => {
    const launches = addLaunch([], 'code', 4, 0)
    placeWindow(launches, 'code', 1000)
    assert.equal(launches[0].firstAt, 0)
})
