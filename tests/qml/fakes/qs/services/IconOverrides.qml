pragma Singleton

import QtQuick

// Stand-in for services/IconOverrides.qml in QML tests: the workspaces' own icons (set by the test, `{ id:
// source }`), nothing chosen for apps or windows, and a record of the last reorder the icons were asked to
// follow (`{ ids, from, to }`, null for none).
QtObject {
    property var workspaceIcons: ({})
    property var reordered: null

    function workspaceIcon(id: int): string {
        const source = workspaceIcons[String(id)]
        return source === undefined ? '' : source
    }

    function appIcon(id: string, iconName: string): string {
        return ''
    }

    function windowIcon(address: string, appId: string): string {
        return ''
    }

    function reorderWorkspaces(ids: var, from: int, to: int): void {
        reordered = { ids: ids, from: from, to: to }
    }
}
