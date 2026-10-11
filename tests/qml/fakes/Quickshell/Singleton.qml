import QtQuick

// Stand-in for Quickshell's `Singleton` in QML tests, so design/Theme.qml (the real tokens) loads without
// the Quickshell runtime. Only the type is needed.
QtObject {
}
