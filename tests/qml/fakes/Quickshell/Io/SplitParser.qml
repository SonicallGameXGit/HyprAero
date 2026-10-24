import QtQuick

// Stand-in for Quickshell's `SplitParser` in QML tests; nothing is ever read.
QtObject {
    signal read(string data)
}
