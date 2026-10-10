import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/workspaceList.js', import.meta.url), 'utf8').replace('.pragma library', '')
const buildEntries = new Function(source + '\nreturn buildEntries')()

const ids = entries => entries.map(entry => entry.id)

test('fresh desktop shows the minimum, first one focused', () => {
    const entries = buildEntries([], 1, 5)
    assert.deepEqual(ids(entries), [1, 2, 3, 4, 5])
    assert.equal(entries[0].focused, true)
    assert.equal(entries.some(entry => entry.occupied), false)
})

test('existing workspaces beyond the minimum are added in order', () => {
    const entries = buildEntries([{ id: 8 }, { id: 2 }], 2, 5)
    assert.deepEqual(ids(entries), [1, 2, 3, 4, 5, 8])
    assert.equal(entries.find(entry => entry.id === 8)?.occupied, true)
    assert.equal(entries.find(entry => entry.id === 3)?.occupied, false)
})

test('a focused empty workspace beyond the minimum is still shown', () => {
    assert.deepEqual(ids(buildEntries([], 7, 3)), [1, 2, 3, 7])
})

test('special workspaces are never listed', () => {
    assert.deepEqual(ids(buildEntries([{ id: -98 }], -98, 2)), [1, 2])
})
