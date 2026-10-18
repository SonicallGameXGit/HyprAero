.pragma library

// The notification area's network icon and its flyout, after Windows 7's ("View Available Networks").
// Plain JS, no Quickshell imports, so node can test it. Words are QML's (they go through qsTr); this file
// only decides.

// Quickshell's `WifiSecurityType` values, in their order, grouped by what connecting needs: nothing
// ('open'), a key typed in the flyout ('personal'), or more than a key ('enterprise': a user name,
// certificates), which the flyout cannot ask for. WEP and unknown types count as 'other', also handed to
// the network settings: NetworkManager takes their key in another form.
const securityGroups = [
    'enterprise',
    'personal',
    'enterprise',
    'personal',
    'enterprise',
    'personal',
    'other',
    'enterprise',
    'enterprise',
    'open',
    'open',
    'other',
]

function securityGroup(security) {
    const group = securityGroups[security]
    return group === undefined ? 'other' : group
}

// Windows 7 draws a Wi-Fi network's signal as five bars; `strength` is 0 to 1.
function signalBars(strength) {
    if (typeof strength !== 'number' || Number.isNaN(strength) || strength <= 0) {
        return 0
    }

    return Math.min(5, Math.max(1, Math.ceil(strength * 5)))
}

// The bar icon: `{ kind, bars, badge }`. `kind` is 'wired' (Windows 7's monitor with its cable) or 'wifi'
// (the bars); `badge` is drawn over it: 'none', 'busy' (connecting), 'warning' (connected without full
// internet access), 'available' (not connected, networks to connect to) or 'error' (not connected and
// nothing to connect to). `state` holds what the network service knows:
//     wiredConnected, wifiConnected, strength (of the connected Wi-Fi network), connecting,
//     connectivity ('full', 'limited', 'portal', 'none' or 'unknown'), hasWifi (a Wi-Fi device that is
//     on), wifiAvailable (networks seen that are not connected).
// A wired connection is shown before Wi-Fi, as Windows shows the connection it uses.
function iconState(state) {
    const limited = state.connectivity === 'limited' || state.connectivity === 'portal' || state.connectivity === 'none'
    const kind = state.wiredConnected || state.hasWifi === false ? 'wired' : 'wifi'
    if (state.connecting) {
        return { kind: kind, bars: state.wifiConnected ? signalBars(state.strength) : 0, badge: 'busy' }
    }

    if (state.wiredConnected || state.wifiConnected) {
        const bars = state.wiredConnected ? 0 : signalBars(state.strength)
        return { kind: kind, bars: bars, badge: limited ? 'warning' : 'none' }
    }

    return { kind: kind, bars: 0, badge: state.hasWifi && state.wifiAvailable ? 'available' : 'error' }
}

// The name of Windows 7's own picture for the bar icon `icon` (`iconState`) in `resources/icons/`: the bars
// (0 to 5) or the monitor, with the gold warning sign for 'warning', the gold star for 'available' and the
// red cross for 'error'; 'busy' is frame `step` (1 to 9) of Windows' connecting animation. A wired icon has
// no star: Windows shows it with the cross until a cable is plugged in.
function iconName(icon, step) {
    const kind = icon.kind === 'wired' ? 'wired' : 'wifi'
    if (icon.badge === 'busy') {
        return `network-${kind}-connecting-${step}`
    }

    if (icon.badge === 'error' || (kind === 'wired' && icon.badge === 'available')) {
        return `network-${kind}-none`
    }

    if (kind === 'wired') {
        return icon.badge === 'warning' ? 'network-wired-limited' : 'network-wired'
    }

    if (icon.badge === 'available') {
        return 'network-wifi-available'
    }

    const bars = Math.min(5, Math.max(0, icon.bars))
    return icon.badge === 'warning' ? 'network-wifi-limited-' + bars : 'network-wifi-' + bars
}

// The picture beside "Currently connected to:" in the flyout, in `resources/icons/`. Connected, it is the
// network's location; Windows 7 asks for one (home, work, public) and starts a new network as public, and
// NetworkManager has no such choice, so it is always Windows' public one (the bench). Not connected, it is
// the flyout's own: the monitor with the red cross (wired, nothing plugged in), the bars with the gold star
// (networks to connect to, also while connecting) or with the red cross (none).
function currentPicture(connected, icon) {
    if (connected) {
        return 'network-public'
    }

    if (icon.kind === 'wired') {
        return 'flyout-wired-none'
    }

    return icon.badge === 'error' ? 'flyout-wifi-none' : 'flyout-wifi-available'
}

// The flyout list's signal bars for a network of `strength` (0 to 1), Windows 7's green bars. On Slate's dark
// pane (`slate`) it is the copy whose light bevel is darkened (`resources/README.md`): Windows drew it for a
// white pane, and on a dark one it reads as a bright outline.
function barsPicture(strength, slate) {
    return (slate ? 'signal-bars-slate-' : 'signal-bars-') + signalBars(strength)
}

// The networks of the flyout's list, `[{ name, connected, strength, ... }]`: the connected one first,
// then by signal, then by name. A network without a name (a hidden one) is left out: it cannot be told
// apart or chosen by name.
function sortNetworks(networks) {
    return networks
        .filter(network => typeof network.name === 'string' && network.name !== '')
        .sort((first, second) => {
            if (first.connected !== second.connected) {
                return first.connected ? -1 : 1
            }

            if (first.strength !== second.strength) {
                return second.strength - first.strength
            }

            return first.name.localeCompare(second.name)
        })
}

// What the button of an opened network row does: 'disconnect' (it is connected), 'connect' (it needs
// nothing more: open, or known to NetworkManager with its key saved), 'askKey' (a key is typed in first)
// or 'settings' (it needs more than a key: the network settings program).
function connectAction(network) {
    if (network.connected) {
        return 'disconnect'
    }

    const group = securityGroup(network.security)
    if (network.known || group === 'open') {
        return 'connect'
    }

    return group === 'personal' ? 'askKey' : 'settings'
}

// Whether a typed key can be a WPA key at all: 8 to 63 characters, or 64 hexadecimal digits. Anything
// else would only fail after a wait.
function validKey(key) {
    if (key.length >= 8 && key.length <= 63) {
        return true
    }

    return key.length === 64 && /^[0-9a-fA-F]+$/.test(key)
}

// Quickshell's `ConnectionFailReason` as what the flyout says: 'key' (the key was wrong or not given:
// NoSecrets, WifiAuthTimeout), 'lost' (the network went away) or 'failed'.
function failureKind(reason) {
    if (reason === 1 || reason === 4) {
        return 'key'
    }

    return reason === 5 ? 'lost' : 'failed'
}

// Quickshell's `NetworkConnectivity` (Unknown, None, Portal, Limited, Full) as a word for `iconState`.
function connectivityName(connectivity) {
    const names = ['unknown', 'none', 'portal', 'limited', 'full']
    const name = names[connectivity]
    return name === undefined ? 'unknown' : name
}
