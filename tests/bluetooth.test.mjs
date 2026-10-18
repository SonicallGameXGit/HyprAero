import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/bluetooth.js', import.meta.url), 'utf8').replace('.pragma library', '')
const bluetooth = new Function(source + `
return {
    pairedDevices,
    newDevices,
}`)()

const device = (name, paired, connected, address) => ({ name: name, paired: paired, connected: connected, address: address })

test('paired: connected first, then by name', () => {
    const list = bluetooth.pairedDevices([
        device('Speaker', true, false, '00:00:00:00:00:02'),
        device('Mouse', false, false, '00:00:00:00:00:03'),
        device('Headset', true, true, '00:00:00:00:00:01'),
        device('Keyboard', true, false, '00:00:00:00:00:04'),
    ])
    assert.deepEqual(list.map(item => item.name), ['Headset', 'Keyboard', 'Speaker'])
})

test('new: not paired, named, by name; one named only by its address is left out', () => {
    const list = bluetooth.newDevices([
        device('Speaker', false, false, '00:00:00:00:00:02'),
        device('', false, false, '00:00:00:00:00:05'),
        device('00-00-00-00-00-06', false, false, '00:00:00:00:00:06'),
        device('Headset', true, false, '00:00:00:00:00:01'),
        device('Earbuds', false, false, '00:00:00:00:00:07'),
    ])
    assert.deepEqual(list.map(item => item.name), ['Earbuds', 'Speaker'])
})
