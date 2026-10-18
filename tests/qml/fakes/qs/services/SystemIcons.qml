pragma Singleton

import QtQuick

// Stand-in for services/SystemIcons.qml in QML tests: what each system icon's picture draws.
QtObject {
    property var pictures: ({
        drives: { ejecting: false },
        bluetooth: { enabled: true },
        power: { level: 0.5, plugged: false, badge: 'none' },
        network: { kind: 'wifi', bars: 3, badge: 'none' },
        volume: { level: 'medium' },
    })
}
