pragma Singleton

import Quickshell
import Quickshell.Bluetooth
import QtQuick
import 'bluetooth.js' as BluetoothLogic

// Bluetooth, for the notification area's Bluetooth icon, its menu and the "Add a device" window (Windows
// 7's): the computer's adapter and the devices paired with it or found nearby, from BlueZ through
// Quickshell's Bluetooth module. Without an adapter the icon is not shown (`available`).
//
// Pairing goes through BlueZ's own agent: devices that pair without a code (most headsets, speakers, mice)
// pair from here; one that asks for a code to be typed or compared needs a Bluetooth agent running (one is
// part of blueman or bluetoothctl).
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: available && adapter.enabled
    readonly property bool discoverable: enabled && adapter.discoverable
    readonly property var devices: available ? adapter.devices.values : []
    // `{ address, name, paired, connected, device }`, as the menu and the window list them.
    readonly property var paired: BluetoothLogic.pairedDevices(devices.map(describe))
    readonly property var found: BluetoothLogic.newDevices(devices.map(describe))
    readonly property string tooltip: {
        const connected = paired.filter(entry => entry.connected)
        if (connected.length === 0) {
            return qsTr('Bluetooth Devices')
        }

        return qsTr('Bluetooth Devices') + '\n' + connected.map(entry => entry.name).join('\n')
    }

    // The "Add a device" window is open; the adapter looks for devices meanwhile.
    property bool addOpen: false
    // The device being added: once paired it is trusted and connected.
    property var pending: null

    function describe(device: var): var {
        return {
            address: device.address,
            name: device.name,
            paired: device.paired,
            connected: device.connected,
            device: device,
        }
    }

    function toggleConnection(device: var): void {
        if (device.connected) {
            device.disconnect()
        } else {
            device.connect()
        }
    }

    function setEnabled(on: bool): void {
        if (available) {
            adapter.enabled = on
        }
    }

    // Windows 7's "Allow a Device to Connect": the computer can be found by other devices.
    function setDiscoverable(on: bool): void {
        if (enabled) {
            adapter.discoverable = on
        }
    }

    // Paired, then trusted (it may connect again by itself) and connected, as Windows 7's wizard does.
    function add(device: var): void {
        pending = device
        device.pair()
    }

    function openAdd(): void {
        if (enabled === false) {
            setEnabled(true)
        }

        addOpen = false
        addOpen = true
    }

    Connections {
        target: root.pending

        function onPairedChanged(): void {
            const device = root.pending
            if (device !== null && device.paired) {
                device.trusted = true
                device.connect()
                root.pending = null
            }
        }
    }

    Binding {
        target: root.adapter
        property: 'discovering'
        value: true
        when: root.addOpen && root.enabled
        restoreMode: Binding.RestoreBindingOrValue
    }
}
