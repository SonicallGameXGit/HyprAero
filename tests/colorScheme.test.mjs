import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const source = readFileSync(new URL('../colorScheme.js', import.meta.url), 'utf8').replace('.pragma library', '')
const parseColorScheme = new Function(source + '\nreturn parseColorScheme')()

test('reply of Settings.Read', () => {
    assert.equal(parseColorScheme('(<<uint32 1>>,)'), 'dark')
    assert.equal(parseColorScheme('(<<uint32 2>>,)'), 'light')
    assert.equal(parseColorScheme('(<<uint32 0>>,)'), 'unknown')
})

test('SettingChanged signal for color-scheme', () => {
    const line = '/org/freedesktop/portal/desktop: org.freedesktop.portal.Settings.SettingChanged (\'org.freedesktop.appearance\', \'color-scheme\', <uint32 2>)'
    assert.equal(parseColorScheme(line), 'light')
})

test('signals about other settings and garbage are ignored', () => {
    const line = '/org/freedesktop/portal/desktop: org.freedesktop.portal.Settings.SettingChanged (\'org.freedesktop.appearance\', \'accent-color\', <uint32 1>)'
    assert.equal(parseColorScheme(line), 'unknown')
    assert.equal(parseColorScheme('Error: no such service'), 'unknown')
})
