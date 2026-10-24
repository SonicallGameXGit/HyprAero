import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../avatar.js', import.meta.url), 'utf8').replace('.pragma library', '')
const avatar = new Function(source + '\nreturn { initial, avatarIndex }')()

test('avatar: an upper-case initial, and a stable colour within range', () => {
    assert.equal(avatar.initial(' mike'), 'M')
    assert.equal(avatar.initial(''), '?')
    const index = avatar.avatarIndex('sonicall', 6)
    assert.equal(index, avatar.avatarIndex('sonicall', 6))
    assert.ok(index >= 0 && index < 6)
})
