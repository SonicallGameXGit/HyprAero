pragma Singleton

import QtQuick

// Stand-in for services/Tray.qml in QML tests: fixed lists of shown and hidden icons (plain objects shaped
// like Quickshell's tray items), and a record of what the app was asked to do.
QtObject {
    readonly property string trayDragFormat: 'application/x-hypraero-tray'

    // Every icon ever seen (only its length matters here).
    property var icons: []
    property var shown: []
    property var hidden: []
    property var activated: []
    property var secondary: []
    property var scrolled: []

    function keyOf(item: var): string {
        return item.id
    }

    function pictureOf(source: string): string {
        return source
    }

    function tooltipOf(item: var): string {
        return item.title
    }

    function activate(item: var): void {
        activated = activated.concat([item.id])
    }

    function secondaryActivate(item: var): void {
        secondary = secondary.concat([item.id])
    }

    function scroll(item: var, delta: int, horizontal: bool): void {
        scrolled = scrolled.concat([{ id: item.id, delta: delta, horizontal: horizontal }])
    }
}
