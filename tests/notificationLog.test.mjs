import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/notificationLog.js', import.meta.url), 'utf8').replace('.pragma library', '')
const notificationLog = new Function(source + '\nreturn { describe }')()

const plain = {
    id: 3,
    appName: 'Firefox',
    urgency: 1,
    summaryLength: 12,
    bodyLength: 0,
    actionCount: 0,
    hasImage: false,
}

test('a plain notification: id, app, urgency and the summary\'s length', () => {
    assert.equal(notificationLog.describe(plain), '#3 from "Firefox", normal, summary of 12 characters')
})

test('body, actions and picture are mentioned only when there', () => {
    const full = Object.assign({}, plain, { urgency: 2, bodyLength: 1, actionCount: 2, hasImage: true })
    assert.equal(notificationLog.describe(full), '#3 from "Firefox", critical, summary of 12 characters, body of 1 character, 2 actions, a picture')
    const one = Object.assign({}, plain, { urgency: 0, summaryLength: 1, actionCount: 1 })
    assert.equal(notificationLog.describe(one), '#3 from "Firefox", low, summary of 1 character, 1 action')
})

test('a notification the user chose not to see says so', () => {
    const line = notificationLog.describe(Object.assign({}, plain, { hidden: true }))
    assert.equal(line, '#3 from "Firefox", normal, summary of 12 characters, hidden as chosen on the bar\'s Notification Area Icons page')
})

test('an app without a name and an unknown urgency still give a line', () => {
    const odd = Object.assign({}, plain, { appName: '', urgency: 7, summaryLength: 0 })
    assert.equal(notificationLog.describe(odd), '#3 from an app without a name, urgency 7, summary of 0 characters')
})

test('the words of a notification never reach the line', () => {
    const line = notificationLog.describe(Object.assign({}, plain, { summary: 'Your code is 482913', body: 'secret' }))
    assert.equal(line.includes('482913'), false)
    assert.equal(line.includes('secret'), false)
})
