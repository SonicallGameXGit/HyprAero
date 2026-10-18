pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import 'power.js' as PowerLogic
import 'tray.js' as TrayList

// The laptop's battery and power plan, for the notification area's power icon and its flyout (Windows 7's):
// the battery from UPower, the plan from power-profiles-daemon. Like Windows 7 the icon is there only on a
// computer with a battery (`available`); a mouse's or a headset's battery does not count. Plans are offered
// only while power-profiles-daemon is on the bus, so a missing daemon never shows choices that do nothing.
Singleton {
    id: root

    readonly property var battery: {
        const device = UPower.devices.values.find(candidate => candidate.isLaptopBattery && candidate.isPresent)
        return device === undefined ? null : device
    }
    readonly property bool available: battery !== null
    readonly property bool onBattery: UPower.onBattery
    readonly property var status: available
        ? PowerLogic.batteryStatus({
            percentage: battery.percentage,
            state: PowerLogic.stateName(battery.state),
            timeToEmpty: battery.timeToEmpty,
            onBattery: onBattery,
        })
        : { kind: 'full', percent: 0, time: null }
    readonly property real level: status.percent / 100
    readonly property string badge: PowerLogic.batteryBadge(status.percent, onBattery)
    readonly property string statusText: {
        if (status.kind === 'full') {
            return qsTr('Fully charged (%1%)').arg(status.percent)
        }

        if (status.kind === 'charging') {
            return qsTr('%1% available (plugged in, charging)').arg(status.percent)
        }

        if (status.kind === 'notCharging') {
            return qsTr('%1% available (plugged in, not charging)').arg(status.percent)
        }

        if (status.time === null) {
            return qsTr('%1% remaining').arg(status.percent)
        }

        return qsTr('%1 hr %2 min (%3%) remaining').arg(status.time.hours).arg(status.time.minutes).arg(status.percent)
    }

    // power-profiles-daemon owns its name on the system bus (either of its two names).
    property bool profilesAvailable: false
    readonly property var plans: profilesAvailable ? PowerLogic.planOrder(PowerProfiles.hasPerformanceProfile) : []
    readonly property int plan: profilesAvailable ? PowerProfiles.profile : -1

    function planName(profile: int): string {
        if (profile === PowerProfile.Balanced) {
            return qsTr('Balanced (recommended)')
        }

        return profile === PowerProfile.PowerSaver ? qsTr('Power saver') : qsTr('High performance')
    }

    function setPlan(profile: int): void {
        if (profilesAvailable) {
            PowerProfiles.profile = profile
        }
    }

    Process {
        command: [
            'sh',
            '-c',
            'for name in org.freedesktop.UPower.PowerProfiles net.hadess.PowerProfiles; do gdbus call --system --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus --method org.freedesktop.DBus.NameHasOwner "$name"; done',
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.profilesAvailable = text.split('\n').some(line => TrayList.nameHasOwner(line) === true)
        }
    }
}
