pragma Singleton

import QtQuick

// Stand-in for services/SystemTheme.qml in QML tests: always the light theme.
QtObject {
    readonly property bool dark: false
}
