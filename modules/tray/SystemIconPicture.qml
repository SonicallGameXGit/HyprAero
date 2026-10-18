import QtQuick
import qs.design
import qs.services
import '../../services/network.js' as NetworkLogic
import '../../services/volume.js' as VolumeLogic

// The picture of one of the shell's own icons in the notification area (`name`: 'drives', 'bluetooth',
// 'power', 'network', 'volume'), drawn from what `SystemIcons.pictures` says about it now.
Item {
    id: root

    property string name: ''
    property real size: 16

    readonly property var state: SystemIcons.pictures[name]

    implicitWidth: size
    implicitHeight: size

    DriveGlyph {
        visible: root.name === 'drives'
        size: root.size
        busy: root.name === 'drives' && root.state.ejecting
    }

    BluetoothGlyph {
        visible: root.name === 'bluetooth'
        size: root.size
        active: root.name !== 'bluetooth' || root.state.enabled
    }

    BatteryGlyph {
        visible: root.name === 'power'
        size: root.size
        level: root.name === 'power' ? root.state.level : 0
        plugged: root.name === 'power' && root.state.plugged
        badge: root.name === 'power' ? root.state.badge : 'none'
    }

    // Windows 7's own network icon (`resources/icons/`), its connecting animation stepping through
    // Windows' nine frames.
    WindowsIcon {
        id: networkIcon

        property int step: 1

        visible: root.name === 'network'
        size: root.size
        name: root.name === 'network' ? NetworkLogic.iconName(root.state, step) : ''

        Timer {
            interval: 120
            repeat: true
            running: root.name === 'network' && root.state.badge === 'busy' && root.visible
            onTriggered: networkIcon.step = networkIcon.step % 9 + 1
        }
    }

    // Windows 7's own speaker for the level (`resources/icons/`, from `sndvolsso.dll`).
    WindowsIcon {
        visible: root.name === 'volume'
        size: root.size
        name: root.name === 'volume' ? VolumeLogic.iconName(root.state.level) : ''
    }
}
