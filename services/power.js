.pragma library

// The notification area's power icon and its flyout (the laptop's battery), after Windows 7's. Plain JS, no
// Quickshell imports, so node can test it. Words are QML's; this file only decides.

// Quickshell's `UPowerDeviceState` values, in their order.
const stateNames = ['unknown', 'charging', 'discharging', 'empty', 'full', 'pendingCharge', 'pendingDischarge']

function stateName(state) {
    const name = stateNames[state]
    return name === undefined ? 'unknown' : name
}

// Whole hours and minutes of a time in seconds (minutes rounded down); null when it is not known (UPower
// says 0 while it is still estimating).
function duration(seconds) {
    if (typeof seconds !== 'number' || Number.isNaN(seconds) || seconds < 60) {
        return null
    }

    const minutes = Math.floor(seconds / 60)
    return { hours: Math.floor(minutes / 60), minutes: minutes % 60 }
}

// What Windows 7 says about the battery, as `{ kind, percent, time }`:
//     'full'          Fully charged (100%)
//     'charging'      54% available (plugged in, charging)
//     'notCharging'   54% available (plugged in, not charging)
//     'remaining'     1 hr 20 min (54%) remaining, `time` from `duration` (null: "54% remaining")
// `battery` is `{ percentage (0 to 1), state (a `stateName`), timeToEmpty (seconds), onBattery }`.
function batteryStatus(battery) {
    const percent = Math.round(Math.min(1, Math.max(0, battery.percentage)) * 100)
    if (battery.state === 'full' || (battery.onBattery === false && percent >= 100)) {
        return { kind: 'full', percent: percent, time: null }
    }

    if (battery.state === 'charging' || battery.state === 'pendingCharge') {
        return { kind: 'charging', percent: percent, time: null }
    }

    if (battery.onBattery === false) {
        return { kind: 'notCharging', percent: percent, time: null }
    }

    return { kind: 'remaining', percent: percent, time: duration(battery.timeToEmpty) }
}

// The badge over the bar's battery: 'none', 'warning' at Windows' low level (10%) and below, 'error' at its
// critical level (5%) and below. Plugged in, the battery is filling: no badge.
function batteryBadge(percent, onBattery) {
    if (onBattery === false) {
        return 'none'
    }

    if (percent <= 5) {
        return 'error'
    }

    return percent <= 10 ? 'warning' : 'none'
}

// Quickshell's `PowerProfile` values (PowerSaver, Balanced, Performance) in the order Windows 7 lists its
// plans: Balanced first (the recommended one), Power saver, and High performance only where the machine has
// it ("Show additional plans").
function planOrder(hasPerformance) {
    return hasPerformance ? [1, 0, 2] : [1, 0]
}
