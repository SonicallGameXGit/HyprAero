import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync, readdirSync } from 'node:fs'

// The library scripts run in Quickshell's JavaScript engine, which lacks some of what node has (measured on
// Quickshell 0.3.2: `typeof ''.trimEnd` and the others below are 'undefined' there). A call to one passes the
// node tests and throws in the module, and the engine's error then prints the string it was called on, which
// can be a notification's words.
const missing = [
    'trimEnd',
    'trimStart',
    'replaceAll',
    'matchAll',
    'flatMap',
    'fromEntries',
]
const missingCalls = [
    /\.at\(/,
    /\.flat\(/,
]

const folders = ['../services/', '../resources/icons/', '../design/']
const scripts = folders.flatMap(folder => readdirSync(new URL(folder, import.meta.url))
    .filter(name => name.endsWith('.js'))
    .map(name => new URL(folder + name, import.meta.url)))

test('no library script uses what Quickshell\'s engine lacks', () => {
    assert.ok(scripts.length > 0)
    for (const script of scripts) {
        // Comments may name them, to say why they are not used.
        const code = readFileSync(script, 'utf8').split('\n').filter(line => line.trim().startsWith('//') === false).join('\n')
        for (const name of missing) {
            assert.equal(code.includes(name), false, `${script.pathname} uses ${name}`)
        }
        for (const call of missingCalls) {
            assert.equal(call.test(code), false, `${script.pathname} uses ${call}`)
        }
    }
})
