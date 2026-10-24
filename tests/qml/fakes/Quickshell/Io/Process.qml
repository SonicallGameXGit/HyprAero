import QtQuick

// Stand-in for Quickshell's `Process` in QML tests: never runs anything, so SystemTheme.qml stays light.
QtObject {
    property bool running: false
    property var command: []
    property QtObject stdout: null
}
