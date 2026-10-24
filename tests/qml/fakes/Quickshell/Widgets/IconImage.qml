import QtQuick

// Stand-in for Quickshell's `IconImage` in QML tests: an image sized by `implicitSize`.
Image {
    property real implicitSize: 0

    width: implicitSize
    height: implicitSize
}
