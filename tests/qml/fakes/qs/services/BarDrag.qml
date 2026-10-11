pragma Singleton

import QtQuick

// Stand-in for services/BarDrag.qml in QML tests: records what a drag source asks for. The last begun
// workspace is kept apart because a drag without a compositor (offscreen tests) ends at once.
QtObject {
    property string address: ''
    property int workspaceId: 0
    property int begins: 0
    property int begunWorkspaceId: 0
    property rect begunOrigin: Qt.rect(0, 0, 0, 0)

    function begin(windowAddress: string, workspace: int, grab: var, size: size, point: point, screen: var, rect: rect): void {
        address = windowAddress
        workspaceId = workspace
        begunWorkspaceId = workspace
        begunOrigin = rect
        begins++
    }

    function end(): void {
        address = ''
        workspaceId = 0
    }
}
