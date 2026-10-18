.pragma library

// The notification area's "Safely Remove Hardware and Eject Media" icon, after Windows 7's: which plugged-in
// drives can be ejected, and the command that ejects one. Plain JS, no Quickshell imports, so node can test
// it.

// What `lsblk` is asked for, as JSON with sizes in bytes.
const listCommand = ['lsblk', '--json', '--bytes', '--output', 'NAME,PATH,TYPE,RM,HOTPLUG,SIZE,MOUNTPOINTS,LABEL,VENDOR,MODEL,TRAN']

// The system's own mount places: a drive holding one is never offered (it cannot be taken out while the
// system runs on it).
const systemPlaces = ['/', '/boot', '/boot/efi', '/efi', '/home', '/usr', '/var']

// lsblk writes flags as true / false, older versions as "1" / "0" or 1 / 0.
function flag(value) {
    return value === true || value === '1' || value === 1
}

function word(value) {
    return typeof value === 'string' ? value.trim() : ''
}

// The mount places of a device and of everything under it, as `[{ path, place }]`.
function mounted(device) {
    const result = []
    const places = Array.isArray(device.mountpoints) ? device.mountpoints : []
    for (const place of places) {
        if (typeof place === 'string' && place !== '') {
            result.push({ path: word(device.path), place: place })
        }
    }

    const children = Array.isArray(device.children) ? device.children : []
    for (const child of children) {
        result.push(...mounted(child))
    }

    return result
}

function labels(device) {
    const result = []
    const label = word(device.label)
    if (label !== '') {
        result.push(label)
    }

    const children = Array.isArray(device.children) ? device.children : []
    for (const child of children) {
        result.push(...labels(child))
    }

    return result
}

// The drives that can be ejected, from lsblk's JSON (`listCommand`), as
// `[{ path, title, labels, partitions }]`: plugged-in disks (removable or hot-pluggable, with a medium in
// them) with something mounted, not holding the system. A drive with nothing mounted is already safe to
// pull out; offering it anyway would power off devices that only carry a small built-in disk (an audio
// interface's "Welcome Disk": powering it off takes the whole device away). `title` is the drive's maker and model, `labels` its partitions' names,
// `partitions` the device paths mounted now (unmounted before the drive is powered off). Text that is not
// lsblk's JSON gives no drive.
function removableDrives(text) {
    let data = null
    try {
        data = JSON.parse(text)
    } catch (error) {
        return []
    }

    if (typeof data !== 'object' || data === null || Array.isArray(data.blockdevices) === false) {
        return []
    }

    const result = []
    for (const device of data.blockdevices) {
        if (typeof device !== 'object' || device === null || device.type !== 'disk') {
            continue
        }

        const pluggable = flag(device.rm) || flag(device.hotplug)
        const size = typeof device.size === 'number' ? device.size : Number(device.size)
        const path = word(device.path)
        if (pluggable === false || (size > 0) === false || path === '') {
            continue
        }

        const mounts = mounted(device)
        if (mounts.length === 0 || mounts.some(mount => systemPlaces.includes(mount.place))) {
            continue
        }

        const title = [word(device.vendor), word(device.model)].filter(part => part !== '').join(' ')
        result.push({
            path: path,
            title: title === '' ? word(device.name) : title,
            labels: labels(device),
            partitions: mounts.map(mount => mount.path).filter((value, index, list) => list.indexOf(value) === index),
        })
    }

    return result
}

// How a drive is named in the menu: "SanDisk Cruzer (STICK)", its labels in brackets as Windows puts the
// drive letters.
function driveName(drive) {
    if (drive.labels.length === 0) {
        return drive.title
    }

    return `${drive.title} (${drive.labels.join(', ')})`
}

// The command that ejects a drive: every mounted partition unmounted (exit 2 when one cannot be: it is in
// use), then the drive powered off. A drive that cannot be powered off (a card reader) is still safe to
// take out once unmounted, so that only fails with exit 3. The paths are passed to `sh` as parameters,
// never put into the script's text. Never asks for a password (no one may be there to answer).
function ejectCommand(drive) {
    const script = [
        'disk=$1',
        'shift',
        'for part in "$@"; do',
        '    udisksctl unmount --no-user-interaction --block-device "$part" || exit 2',
        'done',
        'udisksctl power-off --no-user-interaction --block-device "$disk" || exit 3',
    ].join('\n')
    return ['sh', '-c', script, 'sh', drive.path].concat(drive.partitions)
}
