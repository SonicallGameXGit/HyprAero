import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/workspaceTitles.js', import.meta.url), 'utf8').replace('.pragma library', '')
const { titleOf, withTitle, maxLength } = new Function(source + '\nreturn { titleOf, withTitle, maxLength }')()

test('a workspace without a title has the empty one', () => {
    assert.equal(titleOf({}, 2), '')
    assert.equal(titleOf({ 2: 'Mail' }, 2), 'Mail')
    assert.equal(titleOf({ 2: 5 }, 2), '')
})

test('setting a title trims it and keeps the others', () => {
    assert.deepEqual(withTitle({ 1: 'Code' }, 2, '  Mail '), { 1: 'Code', 2: 'Mail' })
})

test('a title is cut to the longest one', () => {
    assert.equal(titleOf(withTitle({}, 1, 'x'.repeat(maxLength + 10)), 1).length, maxLength)
})

test('empty text takes the title away, and nothing changes without a change', () => {
    assert.deepEqual(withTitle({ 1: 'Code', 2: 'Mail' }, 2, '   '), { 1: 'Code' })
    const titles = { 1: 'Code' }
    assert.equal(withTitle(titles, 1, 'Code'), titles)
    assert.equal(withTitle(titles, 5, ''), titles)
})

test('a title does not change the object it was given', () => {
    const titles = { 1: 'Code' }
    withTitle(titles, 1, 'Other')
    assert.deepEqual(titles, { 1: 'Code' })
})
