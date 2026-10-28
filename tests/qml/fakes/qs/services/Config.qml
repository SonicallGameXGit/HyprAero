pragma Singleton

import QtQuick

// Stand-in for services/Config.qml in QML tests: the settings the tested components read, set by the test.
QtObject {
    property var bar: ({ attentionFlashes: 7 })
}
