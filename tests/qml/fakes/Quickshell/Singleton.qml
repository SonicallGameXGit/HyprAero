import QtQuick

// Stand-in for Quickshell's `Singleton` in QML tests, so Theme.qml (the real tokens) and SystemTheme.qml load
// without the Quickshell runtime. It holds children, as the real one does.
QtObject {
    default property list<QtObject> data
}
