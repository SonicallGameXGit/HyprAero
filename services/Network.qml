pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import 'network.js' as NetworkLogic

// The network, for the notification area's network icon and its flyout (Windows 7's "View Available
// Networks"): wired and Wi-Fi connections from NetworkManager through Quickshell's Networking module, the
// Wi-Fi networks around, connecting (with a key typed in the flyout) and disconnecting. Without
// NetworkManager the icon is not shown (`available`). What the icon shows and what a button does is
// decided in `services/network.js`.
//
// "Connect automatically" is a setting of NetworkManager's saved connection, which the module does not
// reach; it is read and written with nmcli when nmcli is there, and the check box is not offered without it.
Singleton {
    id: root

    readonly property bool available: Networking.backend === NetworkBackendType.NetworkManager
    readonly property var devices: available ? Networking.devices.values : []
    readonly property var wifiDevice: {
        const device = devices.find(candidate => candidate.type === DeviceType.Wifi)
        return device === undefined ? null : device
    }
    readonly property var wiredDevice: {
        const device = devices.find(candidate => candidate.type === DeviceType.Wired && candidate.connected)
        return device === undefined ? null : device
    }
    readonly property bool wifiEnabled: available && Networking.wifiEnabled
    // The Wi-Fi networks as the flyout lists them: `{ name, connected, strength, network }`.
    readonly property var networks: {
        if (wifiDevice === null || wifiEnabled === false) {
            return []
        }

        return NetworkLogic.sortNetworks(wifiDevice.networks.values.map(network => ({
            name: network.name,
            connected: network.connected,
            strength: network.signalStrength,
            network: network,
        })))
    }
    readonly property var wifiNetwork: {
        const connected = networks.find(entry => entry.connected)
        return connected === undefined ? null : connected.network
    }
    readonly property bool connecting: devices.some(device => device.state === ConnectionState.Connecting)
    readonly property string connectivity: NetworkLogic.connectivityName(Networking.connectivity)
    readonly property bool internet: connectivity === 'full' || connectivity === 'unknown'
    readonly property var icon: NetworkLogic.iconState({
        wiredConnected: wiredDevice !== null,
        wifiConnected: wifiNetwork !== null,
        strength: wifiNetwork === null ? 0 : wifiNetwork.signalStrength,
        connecting: connecting,
        connectivity: connectivity,
        hasWifi: wifiDevice !== null && wifiEnabled,
        wifiAvailable: networks.some(entry => entry.connected === false),
    })
    // The connection in use, by the name Windows 7 puts under "Currently connected to:"; '' when none.
    readonly property string currentName: {
        if (wiredDevice !== null) {
            return wiredDevice.network !== null && wiredDevice.network.name !== '' ? wiredDevice.network.name : qsTr('Wired network')
        }

        return wifiNetwork === null ? '' : wifiNetwork.name
    }
    readonly property string accessText: internet ? qsTr('Internet access') : qsTr('No Internet access')
    readonly property string tooltip: {
        if (currentName !== '') {
            return currentName + '\n' + accessText
        }

        if (connecting) {
            return qsTr('Connecting...')
        }

        return icon.badge === 'available'
            ? qsTr('Not connected') + '\n' + qsTr('Connections are available')
            : qsTr('Not connected') + '\n' + qsTr('No connections are available')
    }

    // While the flyout is open the Wi-Fi device keeps looking for networks.
    property bool scanning: false
    // nm-connection-editor (Windows' "Network and Sharing Center") and nmcli, looked for at startup.
    property bool hasSettingsProgram: false
    property bool hasNmcli: false
    // The network to keep from connecting by itself once it is connected ('' when none).
    property string manualName: ''

    // Asks for the networks to be listed again at once (the flyout's refresh button).
    function rescan(): void {
        if (wifiDevice === null) {
            return
        }

        wifiDevice.scannerEnabled = false
        wifiDevice.scannerEnabled = true
    }

    // `autoconnect` false ("Connect automatically" unticked) is written to the new connection once it is
    // connected: NetworkManager only creates it then.
    function connectTo(network: var, autoconnect: bool): void {
        manualName = autoconnect || hasNmcli === false ? '' : network.name
        network.connect()
    }

    function connectWithKey(network: var, key: string, autoconnect: bool): void {
        manualName = autoconnect || hasNmcli === false ? '' : network.name
        network.connectWithPsk(key)
    }

    onWifiNetworkChanged: {
        if (wifiNetwork !== null && manualName !== '' && wifiNetwork.name === manualName) {
            setAutoconnect(manualName, false)
            manualName = ''
        }
    }

    function disconnectFrom(network: var): void {
        network.disconnect()
    }

    function setWifiEnabled(on: bool): void {
        Networking.wifiEnabled = on
    }

    function openSettings(): void {
        Quickshell.execDetached(['nm-connection-editor'])
    }

    // NetworkManager names a Wi-Fi connection after its network; the name is passed as a parameter.
    function setAutoconnect(name: string, on: bool): void {
        if (hasNmcli === false) {
            return
        }

        Quickshell.execDetached(['nmcli', 'connection', 'modify', 'id', name, 'connection.autoconnect', on ? 'yes' : 'no'])
    }

    Binding {
        target: root.wifiDevice
        property: 'scannerEnabled'
        value: true
        when: root.scanning && root.wifiDevice !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    Process {
        command: ['sh', '-c', 'command -v nm-connection-editor; command -v nmcli']
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.hasSettingsProgram = text.includes('/nm-connection-editor')
                root.hasNmcli = text.includes('/nmcli')
            }
        }
    }
}
