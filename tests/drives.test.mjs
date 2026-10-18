import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync, mkdtempSync, writeFileSync, chmodSync, readFileSync as read } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/drives.js', import.meta.url), 'utf8').replace('.pragma library', '')
const drives = new Function(source + `
return {
    listCommand,
    removableDrives,
    driveName,
    ejectCommand,
}`)()

// Shaped like this machine's lsblk: an audio interface's tiny built-in disk (nothing mounted), the system
// disk, and a USB stick with one mounted partition.
const listing = JSON.stringify({
    blockdevices: [
        {
            name: 'sda', path: '/dev/sda', type: 'disk', rm: true, hotplug: true, size: 196608, mountpoints: [],
            label: null, vendor: 'Scarlett', model: 'Welcome Disk', tran: 'usb',
            children: [{ name: 'sda1', path: '/dev/sda1', type: 'part', rm: true, hotplug: true, size: 164352, mountpoints: [], label: 'SCARLETT' }],
        },
        {
            name: 'nvme0n1', path: '/dev/nvme0n1', type: 'disk', rm: false, hotplug: false, size: 1024209543168, mountpoints: [],
            children: [{ name: 'nvme0n1p2', path: '/dev/nvme0n1p2', type: 'part', rm: false, hotplug: false, size: 100, mountpoints: ['/'] }],
        },
        {
            name: 'sdb', path: '/dev/sdb', type: 'disk', rm: '1', hotplug: '1', size: 16008609792, mountpoints: [null],
            label: null, vendor: 'SanDisk ', model: 'Cruzer Blade', tran: 'usb',
            children: [
                { name: 'sdb1', path: '/dev/sdb1', type: 'part', size: 16000000000, mountpoints: ['/run/media/me/STICK'], label: 'STICK' },
                { name: 'sdb2', path: '/dev/sdb2', type: 'part', size: 8000000, mountpoints: [], label: null },
            ],
        },
        { name: 'sdc', path: '/dev/sdc', type: 'disk', rm: true, hotplug: true, size: 0, mountpoints: [], vendor: 'Generic', model: 'Card Reader' },
        {
            name: 'sdd', path: '/dev/sdd', type: 'disk', rm: false, hotplug: true, size: 500000000000, mountpoints: ['/home'],
            vendor: 'WD', model: 'Passport',
        },
    ],
})

test('drives: plugged in, something mounted, not the system', () => {
    assert.deepEqual(drives.removableDrives(listing), [
        { path: '/dev/sdb', title: 'SanDisk Cruzer Blade', labels: ['STICK'], partitions: ['/dev/sdb1'] },
    ])
})

test('drives: text that is not lsblk\'s JSON gives none', () => {
    assert.deepEqual(drives.removableDrives(''), [])
    assert.deepEqual(drives.removableDrives('{ "blockdevices": 3 }'), [])
    assert.deepEqual(drives.removableDrives('[1]'), [])
})

test('name: the labels in brackets', () => {
    assert.equal(drives.driveName({ title: 'SanDisk Cruzer', labels: ['STICK'] }), 'SanDisk Cruzer (STICK)')
    assert.equal(drives.driveName({ title: 'SanDisk Cruzer', labels: [] }), 'SanDisk Cruzer')
})

// The real script through real sh, with a stand-in udisksctl that records its arguments and fails where told.
const runEject = (drive, failOn) => {
    const folder = mkdtempSync(join(tmpdir(), 'hypraero-eject-'))
    const log = join(folder, 'log')
    writeFileSync(join(folder, 'udisksctl'), `#!/bin/sh\necho "$*" >> '${log}'\ncase "$*" in *'${failOn}'*) exit 1;; esac\n`)
    chmodSync(join(folder, 'udisksctl'), 0o755)
    const command = drives.ejectCommand(drive)
    let code = 0
    try {
        execFileSync(command[0], command.slice(1), { env: { PATH: folder + ':/usr/bin:/bin' } })
    } catch (error) {
        code = error.status
    }

    let lines = []
    try {
        lines = read(log, 'utf8').trim().split('\n')
    } catch (error) {
        lines = []
    }

    return { code: code, lines: lines }
}

test('eject: unmounts each partition, then powers the drive off; paths stay parameters', () => {
    const drive = { path: '/dev/sdb', partitions: ['/dev/sdb1', '/dev/sd b2;echo x'] }
    assert.deepEqual(runEject(drive, 'nothing'), {
        code: 0,
        lines: [
            'unmount --no-user-interaction --block-device /dev/sdb1',
            'unmount --no-user-interaction --block-device /dev/sd b2;echo x',
            'power-off --no-user-interaction --block-device /dev/sdb',
        ],
    })
})

test('eject: a partition in use stops it (2); a drive that cannot power off says 3', () => {
    const drive = { path: '/dev/sdb', partitions: ['/dev/sdb1'] }
    assert.equal(runEject(drive, 'unmount').code, 2)
    assert.deepEqual(runEject(drive, 'power-off'), {
        code: 3,
        lines: [
            'unmount --no-user-interaction --block-device /dev/sdb1',
            'power-off --no-user-interaction --block-device /dev/sdb',
        ],
    })
})

test('list command asks lsblk for JSON in bytes', () => {
    assert.equal(drives.listCommand[0], 'lsblk')
    assert.equal(drives.listCommand.includes('--json'), true)
    assert.equal(drives.listCommand.includes('--bytes'), true)
})
