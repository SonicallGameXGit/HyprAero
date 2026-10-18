pragma Singleton

import Quickshell
import QtQuick
import 'tray.js' as TrayList

// The shell's own icons in the notification area, Windows 7's "system icons": Safely Remove Hardware,
// Bluetooth, power, network and volume, in Windows 7's order (the last next to the clock). Each is on or
// off in the config file (`tray.*Icon`, Windows 7's "Turn system icons on or off") and is shown while it is
// on and its service is there (a battery, NetworkManager, PipeWire, an adapter, a drive to eject).
//
// To the tray they are items like an app's (`items`, keyed 'system:<name>', see `services/tray.js`), so they
// are placed, dragged, hidden and customised the same way; what a click, the wheel and a menu do comes
// from here. Power, network and volume open a flyout over their icon (one at a time, `flyoutName` on
// `flyoutScreen`); Safely Remove Hardware and Bluetooth open a menu on either click, as on Windows 7.
Singleton {
    id: root

    // `setting` is the config key that turns it on; `flyout` whether a click opens a flyout (or a menu).
    readonly property var all: [
        { name: 'drives', setting: 'drivesIcon', title: qsTr('Safely Remove Hardware and Eject Media'), flyout: false },
        { name: 'bluetooth', setting: 'bluetoothIcon', title: qsTr('Bluetooth Devices'), flyout: false },
        { name: 'power', setting: 'powerIcon', title: qsTr('Power'), flyout: true },
        { name: 'network', setting: 'networkIcon', title: qsTr('Network'), flyout: true },
        { name: 'volume', setting: 'volumeIcon', title: qsTr('Volume'), flyout: true },
    ]
    readonly property var onNames: all.filter(icon => Config.tray[icon.setting] === true).map(icon => icon.name)
    // Shaped like Quickshell's tray items as far as the tray reads them.
    readonly property var items: all
        .filter(icon => onNames.includes(icon.name) && shownNow(icon.name))
        .map(icon => ({
            id: 'system:' + icon.name,
            title: icon.title,
            tooltipTitle: '',
            tooltipDescription: '',
            icon: '',
            status: 0,
            system: icon.name,
            onlyMenu: icon.flyout === false,
            hasMenu: true,
        }))
    // The apps whose own icon these replace (nm-applet, blueman, ...), left out of the notification area.
    readonly property var hiddenApps: Config.tray.hideSystemApps ? TrayList.hiddenApps(onNames.map(name => 'system:' + name)) : []
    // What each icon draws, read by its picture.
    readonly property var pictures: ({
        drives: { ejecting: Drives.ejecting !== '' },
        bluetooth: { enabled: BluetoothDevices.enabled },
        power: { level: Power.level, plugged: Power.onBattery === false, badge: Power.badge },
        network: Network.icon,
        volume: { level: Volume.level },
    })

    // The screen and icon whose flyout is open ('' when none), and the middle of its icon in the bar's
    // coordinates.
    property string flyoutScreen: ''
    property string flyoutName: ''
    property real flyoutX: 0
    property real flyoutClosedAt: 0
    property string closedName: ''
    // A click outside the flyout closes it before the click arrives, so a click on its icon would open it
    // again at once; within this long after closing, that icon does not.
    readonly property int reopenGuard: 300

    // Whether its service is there at all, for the "Turn system icons on or off" page: an icon that can
    // never show there is offered greyed out, as Windows 7 does with Power on a desktop.
    function possible(name: string): bool {
        if (name === 'drives') {
            return Drives.available
        }

        if (name === 'bluetooth') {
            return BluetoothDevices.available
        }

        if (name === 'power') {
            return Power.available
        }

        if (name === 'network') {
            return Network.available
        }

        return Volume.available
    }

    // Whether it is on the bar now: Safely Remove Hardware only while there is a drive to eject.
    function shownNow(name: string): bool {
        if (name === 'drives') {
            return Drives.available && Drives.drives.length > 0
        }

        return possible(name)
    }

    function tooltipOf(name: string): string {
        if (name === 'drives') {
            return qsTr('Safely Remove Hardware and Eject Media')
        }

        if (name === 'bluetooth') {
            return BluetoothDevices.tooltip
        }

        if (name === 'power') {
            return Power.statusText
        }

        if (name === 'network') {
            return Network.tooltip
        }

        return Volume.tooltip
    }

    function toggleFlyout(name: string, screenName: string, x: real): void {
        if (flyoutScreen !== '') {
            const same = flyoutName === name
            closeFlyout()
            if (same) {
                return
            }
        } else if (closedName === name && Date.now() - flyoutClosedAt < reopenGuard) {
            return
        }

        Clock.closeFlyout()
        Tray.closeFlyout()
        flyoutX = x
        flyoutName = name
        flyoutScreen = screenName
    }

    function closeFlyout(): void {
        if (flyoutScreen === '') {
            return
        }

        closedName = flyoutName
        flyoutScreen = ''
        flyoutClosedAt = Date.now()
    }

    // The middle click and the wheel: the volume's mute and level, nothing on the others.
    function secondary(name: string): void {
        if (name === 'volume') {
            Volume.toggleMute()
        }
    }

    function scroll(name: string, delta: int): void {
        if (name === 'volume') {
            Volume.wheel(delta)
        }
    }

    // The icon's menu, as `MenuPanel` items each carrying `system` (its icon) and `command` for `choose`.
    function menuFor(name: string): var {
        const item = (text, command, extra) => Object.assign({ text: text, system: name, command: command }, extra)
        if (name === 'drives') {
            if (Drives.drives.length === 0) {
                return [item(qsTr('No drive to eject'), '', { enabled: false })]
            }

            // Windows 7's eject menu: each drive, its partitions under it in grey, a line between drives.
            const items = []
            for (const drive of Drives.drives) {
                if (items.length > 0) {
                    items.push({ separator: true })
                }

                items.push(item(qsTr('Eject %1').arg(drive.title), 'eject', { drive: drive, enabled: Drives.ejecting === '' }))
                for (const label of drive.labels) {
                    items.push(item('    - ' + label, '', { enabled: false }))
                }
            }

            return items
        }

        if (name === 'bluetooth') {
            const items = BluetoothDevices.paired.map(entry => item(entry.name, 'connection', {
                device: entry.device,
                check: 'box',
                checked: entry.connected,
                enabled: BluetoothDevices.enabled,
            }))
            if (items.length > 0) {
                items.push({ separator: true })
            }

            items.push(item(qsTr('Add a Device...'), 'addDevice', { bold: true, enabled: BluetoothDevices.available }))
            items.push(item(qsTr('Allow a Device to Connect'), 'discoverable', {
                check: 'box',
                checked: BluetoothDevices.discoverable,
                enabled: BluetoothDevices.enabled,
            }))
            items.push({ separator: true })
            items.push(item(BluetoothDevices.enabled ? qsTr('Turn Adapter Off') : qsTr('Turn Adapter On'), 'adapter', {}))
            items.push(item(qsTr('Remove Icon'), 'remove', {}))
            return items
        }

        if (name === 'power') {
            if (Power.plans.length === 0) {
                return [item(qsTr('No power plans (power-profiles-daemon is not running)'), '', { enabled: false })]
            }

            return Power.plans.map(plan => item(Power.planName(plan), 'plan', { plan: plan, check: 'radio', checked: Power.plan === plan }))
        }

        if (name === 'network') {
            return [
                item(qsTr('Open network connections'), 'networkSettings', { enabled: Network.hasSettingsProgram }),
                { separator: true },
                item(Network.wifiEnabled ? qsTr('Turn off Wi-Fi') : qsTr('Turn on Wi-Fi'), 'wifi', { enabled: Network.wifiDevice !== null || Network.wifiEnabled === false }),
            ]
        }

        const items = [item(qsTr('Open Volume Mixer'), 'mixer', { bold: true })]
        if (Volume.outputs.length > 1) {
            items.push({ separator: true })
            for (const output of Volume.outputs) {
                items.push(item(output.name, 'output', {
                    node: output.node,
                    check: 'radio',
                    checked: Volume.sink !== null && Volume.sink.id === output.id,
                }))
            }
        }

        return items
    }

    function choose(item: var): void {
        if (item.command === 'eject') {
            Drives.eject(item.drive)
        } else if (item.command === 'connection') {
            BluetoothDevices.toggleConnection(item.device)
        } else if (item.command === 'addDevice') {
            BluetoothDevices.openAdd()
        } else if (item.command === 'discoverable') {
            BluetoothDevices.setDiscoverable(BluetoothDevices.discoverable === false)
        } else if (item.command === 'adapter') {
            BluetoothDevices.setEnabled(BluetoothDevices.enabled === false)
        } else if (item.command === 'remove') {
            Config.set('tray', 'bluetoothIcon', false)
        } else if (item.command === 'plan') {
            Power.setPlan(item.plan)
        } else if (item.command === 'networkSettings') {
            Network.openSettings()
        } else if (item.command === 'wifi') {
            Network.setWifiEnabled(Network.wifiEnabled === false)
        } else if (item.command === 'mixer') {
            Volume.openMixer()
        } else if (item.command === 'output') {
            Volume.setOutput(item.node)
        }
    }
}
