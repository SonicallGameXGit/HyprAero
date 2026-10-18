import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/power.js', import.meta.url), 'utf8').replace('.pragma library', '')
const power = new Function(source + `
return {
    stateName,
    duration,
    batteryStatus,
    batteryBadge,
    planOrder,
}`)()

test('state names follow Quickshell\'s order', () => {
    assert.equal(power.stateName(1), 'charging')
    assert.equal(power.stateName(2), 'discharging')
    assert.equal(power.stateName(4), 'full')
    assert.equal(power.stateName(12), 'unknown')
})

test('duration: whole hours and minutes, unknown while UPower estimates', () => {
    assert.deepEqual(power.duration(4830), { hours: 1, minutes: 20 })
    assert.deepEqual(power.duration(60), { hours: 0, minutes: 1 })
    assert.equal(power.duration(0), null)
    assert.equal(power.duration(Number.NaN), null)
})

test('status: Windows 7\'s four sentences', () => {
    assert.deepEqual(power.batteryStatus({ percentage: 1, state: 'full', timeToEmpty: 0, onBattery: false }), { kind: 'full', percent: 100, time: null })
    assert.deepEqual(power.batteryStatus({ percentage: 0.54, state: 'charging', timeToEmpty: 0, onBattery: false }), { kind: 'charging', percent: 54, time: null })
    assert.deepEqual(power.batteryStatus({ percentage: 0.54, state: 'pendingCharge', timeToEmpty: 0, onBattery: false }), { kind: 'charging', percent: 54, time: null })
    assert.deepEqual(power.batteryStatus({ percentage: 0.8, state: 'unknown', timeToEmpty: 0, onBattery: false }), { kind: 'notCharging', percent: 80, time: null })
    assert.deepEqual(power.batteryStatus({ percentage: 0.54, state: 'discharging', timeToEmpty: 4830, onBattery: true }), { kind: 'remaining', percent: 54, time: { hours: 1, minutes: 20 } })
    assert.deepEqual(power.batteryStatus({ percentage: 0.54, state: 'discharging', timeToEmpty: 0, onBattery: true }), { kind: 'remaining', percent: 54, time: null })
})

test('badge: low and critical on battery only', () => {
    assert.equal(power.batteryBadge(50, true), 'none')
    assert.equal(power.batteryBadge(10, true), 'warning')
    assert.equal(power.batteryBadge(5, true), 'error')
    assert.equal(power.batteryBadge(3, false), 'none')
})

test('plans: Balanced first, High performance only where there is one', () => {
    assert.deepEqual(power.planOrder(false), [1, 0])
    assert.deepEqual(power.planOrder(true), [1, 0, 2])
})
