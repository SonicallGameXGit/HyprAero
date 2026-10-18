.pragma library

// The notification area's Bluetooth icon, its menu and the "Add a device" window, after Windows 7's. Plain
// JS, no Quickshell imports, so node can test it. Devices are `{ address, name, paired, connected }`.

function byName(first, second) {
    return first.name.localeCompare(second.name) || first.address.localeCompare(second.address)
}

// The devices paired with this computer, for the menu: connected ones first, then by name.
function pairedDevices(devices) {
    return devices
        .filter(device => device.paired)
        .sort((first, second) => {
            if (first.connected !== second.connected) {
                return first.connected ? -1 : 1
            }

            return byName(first, second)
        })
}

// The devices found nearby that are not paired yet, for "Add a device": only those with a name (a device
// that only gives its address cannot be recognised), by name.
function newDevices(devices) {
    return devices
        .filter(device => device.paired === false && typeof device.name === 'string' && device.name !== '' && device.name.replace(/[-:]/g, '') !== device.address.replace(/[-:]/g, ''))
        .sort(byName)
}
