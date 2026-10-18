import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/volume.js', import.meta.url), 'utf8').replace('.pragma library', '')
const volume = new Function(source + `
return {
    percent,
    iconLevel,
    iconName,
    wheeled,
    playbackStreams,
    outputDevices,
}`)()

test('percent: whole points between 0 and 100', () => {
    assert.equal(volume.percent(0.4500274658203125), 45)
    assert.equal(volume.percent(1.3), 100)
    assert.equal(volume.percent(-1), 0)
    assert.equal(volume.percent(Number.NaN), 0)
})

test('icon: no device, muted, then waves by level', () => {
    assert.equal(volume.iconLevel(0.5, false, false), 'none')
    assert.equal(volume.iconLevel(0.5, true, true), 'muted')
    assert.equal(volume.iconLevel(0, false, true), 'silent')
    assert.equal(volume.iconLevel(0.2, false, true), 'low')
    assert.equal(volume.iconLevel(0.5, false, true), 'medium')
    assert.equal(volume.iconLevel(0.66, false, true), 'high')
})

test('icon: every level has Windows\' own picture kept in resources', () => {
    const frames = readFileSync(new URL('../resources/icons/frames.js', import.meta.url), 'utf8')
    for (const level of ['none', 'muted', 'silent', 'low', 'medium', 'high']) {
        assert.ok(frames.includes(`'${volume.iconName(level)}':`), level)
    }

    assert.equal(volume.iconName('low'), 'volume-low')
    assert.equal(volume.iconName('nonsense'), 'volume-high')
})

test('wheel: 2 points a notch, kept between 0 and 1 on whole points', () => {
    assert.equal(volume.wheeled(0.45, 120), 0.47)
    assert.equal(volume.wheeled(0.45, -240), 0.41)
    assert.equal(volume.wheeled(0.4500274658203125, 120), 0.47)
    assert.equal(volume.wheeled(0.99, 360), 1)
    assert.equal(volume.wheeled(0.01, -120), 0)
})

test('mixer: only playback streams, named by their app', () => {
    const streams = volume.playbackStreams([
        { id: 59, mediaClass: 'Audio/Sink', appName: '', appIcon: '', appBinary: '', description: 'Scarlett', name: 'alsa_output' },
        { id: 120, mediaClass: 'Stream/Output/Audio', appName: 'Firefox', appIcon: 'firefox', appBinary: 'firefox', description: '', name: 'Firefox' },
        { id: 121, mediaClass: 'Stream/Input/Audio', appName: 'Discord', appIcon: '', appBinary: '', description: '', name: '' },
        { id: 122, mediaClass: 'Stream/Output/Audio', appName: '', appIcon: '', appBinary: 'mpv', description: 'Big Buck Bunny', name: 'mpv' },
    ])
    assert.deepEqual(streams, [
        { id: 122, name: 'Big Buck Bunny', icon: 'mpv' },
        { id: 120, name: 'Firefox', icon: 'firefox' },
    ])
})

test('devices: the sinks, by the name people know', () => {
    const devices = volume.outputDevices([
        { id: 83, mediaClass: 'Audio/Sink', description: 'HDMI', nickname: '', name: 'alsa_output.hdmi' },
        { id: 59, mediaClass: 'Audio/Sink', description: '', nickname: 'Scarlett Solo USB', name: 'alsa_output.usb' },
        { id: 54, mediaClass: 'Audio/Source', description: 'Mic', nickname: '', name: 'alsa_input' },
    ])
    assert.deepEqual(devices, [{ id: 83, name: 'HDMI' }, { id: 59, name: 'Scarlett Solo USB' }])
})
