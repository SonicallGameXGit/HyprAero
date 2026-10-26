import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../plugin.js', import.meta.url), 'utf8').replace('.pragma library', '')
const plugin = new Function(source + '\nreturn { toHex, hexToText, parseMissing, themeCommand, missingCommand, iconCommand }')()

test('bytes become two hex digits each', () => {
    assert.equal(plugin.toHex([0, 15, 16, 255]), '000f10ff')
    assert.equal(plugin.toHex(new Uint8ClampedArray([65, 122])), '417a')
    assert.equal(plugin.toHex([]), '')
})

test('a class comes back from hex as text', () => {
    assert.equal(plugin.hexToText('6b69747479'), 'kitty')
    assert.equal(plugin.hexToText(Buffer.from('org.gnome.Nautilus', 'utf8').toString('hex')), 'org.gnome.Nautilus')
    assert.equal(plugin.hexToText(Buffer.from('Тест', 'utf8').toString('hex')), 'Тест')
})

test('a class that is not hex or not UTF-8 is nothing', () => {
    assert.equal(plugin.hexToText(''), null)
    assert.equal(plugin.hexToText('abc'), null)
    assert.equal(plugin.hexToText('zz'), null)
    assert.equal(plugin.hexToText('ff'), null)
    assert.equal(plugin.hexToText(undefined), null)
})

test('the plugin says its theme and what is missing', () => {
    assert.deepEqual(plugin.parseMissing('theme aero\n'), { theme: 'aero', classes: [] })
    assert.deepEqual(plugin.parseMissing('theme slate\n6b69747479\n666f6f74\n'), { theme: 'slate', classes: ['6b69747479', '666f6f74'] })
})

test('a line that is not a hex class is left out', () => {
    assert.deepEqual(plugin.parseMissing('theme aero\nkitty\nabc\n6b69\n'), { theme: 'aero', classes: ['6b69'] })
})

test('an answer that is not the plugin\'s is nothing', () => {
    assert.equal(plugin.parseMissing('unknown request'), null)
    assert.equal(plugin.parseMissing(''), null)
    assert.equal(plugin.parseMissing('error: off since an error\n'), null)
    assert.equal(plugin.parseMissing(null), null)
})

test('the commands', () => {
    assert.deepEqual(plugin.themeCommand(true), ['hyprctl', 'hypraero-frames', 'theme', 'slate'])
    assert.deepEqual(plugin.themeCommand(false), ['hyprctl', 'hypraero-frames', 'theme', 'aero'])
    assert.deepEqual(plugin.missingCommand(), ['hyprctl', 'hypraero-frames', 'missing'])
    assert.deepEqual(plugin.iconCommand(16, '6b', [255, 0, 0, 128]), ['hyprctl', 'hypraero-frames', 'icon', '16', '6b', 'ff000080'])
})
