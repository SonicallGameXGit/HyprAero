pragma Singleton

import QtQuick

// Stand-in for services/Workspaces.qml in QML tests: the drag formats, the entries (set by the test) and a
// record of what was asked of Hyprland.
QtObject {
    readonly property string windowDragFormat: 'application/x-hypraero-window'
    readonly property string workspaceDragFormat: 'application/x-hypraero-workspace'
    property var entries: []
    property int switchedTo: 0
    // The last reorder and the last join (a workspace's windows moved to another) asked for: { ids, from,
    // to } and { from, to }, null for none.
    property var reordered: null
    property var joined: null

    function switchTo(id: int): void {
        switchedTo = id
    }

    function reorder(ids: var, from: int, to: int): bool {
        reordered = { ids: ids, from: from, to: to }
        return true
    }

    function moveWorkspace(fromId: int, toId: int): void {
        joined = { from: fromId, to: toId }
    }
}
