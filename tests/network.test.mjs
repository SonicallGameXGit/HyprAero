import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/network.js', import.meta.url), 'utf8').replace('.pragma library', '')
const network = new Function(source + `
return {
    securityGroup,
    signalBars,
    iconState,
    iconName,
    currentPicture,
    barsPicture,
    sortNetworks,
    connectAction,
    validKey,
    failureKind,
    connectivityName,
}`)()

const idle = {
    wiredConnected: false,
    wifiConnected: false,
    strength: 0,
    connecting: false,
    connectivity: 'unknown',
    hasWifi: true,
    wifiAvailable: false,
}
const state = changes => Object.assign({}, idle, changes)

test('signal: five bars, at least one for any signal', () => {
    assert.equal(network.signalBars(0), 0)
    assert.equal(network.signalBars(Number.NaN), 0)
    assert.equal(network.signalBars(0.01), 1)
    assert.equal(network.signalBars(0.49), 3)
    assert.equal(network.signalBars(0.8), 4)
    assert.equal(network.signalBars(1), 5)
    assert.equal(network.signalBars(1.4), 5)
})

test('icon: wired before Wi-Fi, a warning without full internet', () => {
    assert.deepEqual(network.iconState(state({ wiredConnected: true, wifiConnected: true, strength: 1, connectivity: 'full' })), { kind: 'wired', bars: 0, badge: 'none' })
    assert.deepEqual(network.iconState(state({ wifiConnected: true, strength: 0.49, connectivity: 'full' })), { kind: 'wifi', bars: 3, badge: 'none' })
    assert.deepEqual(network.iconState(state({ wifiConnected: true, strength: 0.49, connectivity: 'portal' })), { kind: 'wifi', bars: 3, badge: 'warning' })
    assert.deepEqual(network.iconState(state({ wiredConnected: true, connectivity: 'none' })), { kind: 'wired', bars: 0, badge: 'warning' })
    assert.deepEqual(network.iconState(state({ wiredConnected: true, connectivity: 'unknown' })), { kind: 'wired', bars: 0, badge: 'none' })
})

test('icon: not connected, with or without networks to choose from', () => {
    assert.deepEqual(network.iconState(state({ wifiAvailable: true })), { kind: 'wifi', bars: 0, badge: 'available' })
    assert.deepEqual(network.iconState(state({})), { kind: 'wifi', bars: 0, badge: 'error' })
    assert.deepEqual(network.iconState(state({ hasWifi: false, wifiAvailable: true })), { kind: 'wired', bars: 0, badge: 'error' })
})

test('icon: busy while connecting', () => {
    assert.deepEqual(network.iconState(state({ connecting: true })), { kind: 'wifi', bars: 0, badge: 'busy' })
    assert.deepEqual(network.iconState(state({ connecting: true, hasWifi: false })), { kind: 'wired', bars: 0, badge: 'busy' })
})

test('icon picture: Windows 7\'s own picture for each state', () => {
    assert.equal(network.iconName({ kind: 'wifi', bars: 4, badge: 'none' }, 1), 'network-wifi-4')
    assert.equal(network.iconName({ kind: 'wifi', bars: 2, badge: 'warning' }, 1), 'network-wifi-limited-2')
    assert.equal(network.iconName({ kind: 'wifi', bars: 0, badge: 'available' }, 1), 'network-wifi-available')
    assert.equal(network.iconName({ kind: 'wifi', bars: 0, badge: 'error' }, 1), 'network-wifi-none')
    assert.equal(network.iconName({ kind: 'wifi', bars: 3, badge: 'busy' }, 7), 'network-wifi-connecting-7')
    assert.equal(network.iconName({ kind: 'wired', bars: 0, badge: 'none' }, 1), 'network-wired')
    assert.equal(network.iconName({ kind: 'wired', bars: 0, badge: 'warning' }, 1), 'network-wired-limited')
    assert.equal(network.iconName({ kind: 'wired', bars: 0, badge: 'error' }, 1), 'network-wired-none')
    assert.equal(network.iconName({ kind: 'wired', bars: 0, badge: 'available' }, 1), 'network-wired-none')
    assert.equal(network.iconName({ kind: 'wired', bars: 0, badge: 'busy' }, 2), 'network-wired-connecting-2')
    assert.equal(network.iconName({ kind: 'wifi', bars: 9, badge: 'none' }, 1), 'network-wifi-5')
})

test('flyout pictures: the location when connected, the flyout\'s own sign otherwise', () => {
    assert.equal(network.currentPicture(true, { kind: 'wifi', bars: 5, badge: 'none' }), 'network-public')
    assert.equal(network.currentPicture(false, { kind: 'wired', bars: 0, badge: 'error' }), 'flyout-wired-none')
    assert.equal(network.currentPicture(false, { kind: 'wifi', bars: 0, badge: 'available' }), 'flyout-wifi-available')
    assert.equal(network.currentPicture(false, { kind: 'wifi', bars: 0, badge: 'busy' }), 'flyout-wifi-available')
    assert.equal(network.currentPicture(false, { kind: 'wifi', bars: 0, badge: 'error' }), 'flyout-wifi-none')
    assert.equal(network.barsPicture(0, false), 'signal-bars-0')
    assert.equal(network.barsPicture(1, false), 'signal-bars-5')
    assert.equal(network.barsPicture(0.5, true), 'signal-bars-slate-3')
})

test('every picture named here is kept in resources/icons', () => {
    const frames = readFileSync(new URL('../resources/icons/frames.js', import.meta.url), 'utf8')
    const names = [
        network.currentPicture(true, { kind: 'wifi' }),
        network.currentPicture(false, { kind: 'wired' }),
        network.currentPicture(false, { kind: 'wifi', badge: 'none' }),
        network.currentPicture(false, { kind: 'wifi', badge: 'error' }),
    ]
    for (const kind of ['wifi', 'wired']) {
        for (const badge of ['none', 'warning', 'available', 'error']) {
            for (let bars = 0; bars <= 5; bars++) {
                names.push(network.iconName({ kind: kind, bars: bars, badge: badge }, 1))
                names.push(network.barsPicture(bars / 5, false))
                names.push(network.barsPicture(bars / 5, true))
            }
        }

        for (let step = 1; step <= 9; step++) {
            names.push(network.iconName({ kind: kind, bars: 0, badge: 'busy' }, step))
        }
    }

    for (const name of names) {
        assert.ok(frames.includes(`'${name}':`), name)
    }
})

test('list: connected first, then by signal and name, hidden networks left out', () => {
    const sorted = network.sortNetworks([
        { name: 'Cafe', connected: false, strength: 0.4 },
        { name: '', connected: false, strength: 0.9 },
        { name: 'Home', connected: true, strength: 0.2 },
        { name: 'Attic', connected: false, strength: 0.4 },
        { name: 'Office', connected: false, strength: 0.8 },
    ])
    assert.deepEqual(sorted.map(item => item.name), ['Home', 'Office', 'Attic', 'Cafe'])
})

test('security: what connecting needs', () => {
    assert.equal(network.securityGroup(3), 'personal')
    assert.equal(network.securityGroup(1), 'personal')
    assert.equal(network.securityGroup(2), 'enterprise')
    assert.equal(network.securityGroup(10), 'open')
    assert.equal(network.securityGroup(9), 'open')
    assert.equal(network.securityGroup(6), 'other')
    assert.equal(network.securityGroup(11), 'other')
    assert.equal(network.securityGroup(40), 'other')
})

test('button: disconnect, connect, ask for a key, or the settings', () => {
    assert.equal(network.connectAction({ connected: true, known: true, security: 3 }), 'disconnect')
    assert.equal(network.connectAction({ connected: false, known: true, security: 3 }), 'connect')
    assert.equal(network.connectAction({ connected: false, known: false, security: 10 }), 'connect')
    assert.equal(network.connectAction({ connected: false, known: false, security: 3 }), 'askKey')
    assert.equal(network.connectAction({ connected: false, known: false, security: 2 }), 'settings')
    assert.equal(network.connectAction({ connected: false, known: true, security: 2 }), 'connect')
})

test('key: 8 to 63 characters, or 64 hexadecimal digits', () => {
    assert.equal(network.validKey('short'), false)
    assert.equal(network.validKey('12345678'), true)
    assert.equal(network.validKey('x'.repeat(63)), true)
    assert.equal(network.validKey('x'.repeat(64)), false)
    assert.equal(network.validKey('a1'.repeat(32)), true)
})

test('failure and connectivity words', () => {
    assert.equal(network.failureKind(1), 'key')
    assert.equal(network.failureKind(4), 'key')
    assert.equal(network.failureKind(5), 'lost')
    assert.equal(network.failureKind(0), 'failed')
    assert.equal(network.connectivityName(4), 'full')
    assert.equal(network.connectivityName(2), 'portal')
    assert.equal(network.connectivityName(9), 'unknown')
})
