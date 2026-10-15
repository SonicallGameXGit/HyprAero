pragma Singleton

import QtQuick

// Stand-in for services/BarDrag.qml in QML tests: records what a drag source asks for. What was begun last
// is kept apart because a drag without a compositor (offscreen tests) ends at once.
QtObject {
    property string address: ''
    property int workspaceId: 0
    property string appId: ''
    property string trayKey: ''
    property string from: ''
    property int begins: 0
    property int begunWorkspaceId: 0
    property string begunAppId: ''
    property string begunTrayKey: ''
    property rect begunOrigin: Qt.rect(0, 0, 0, 0)
    property rect begunReturn: Qt.rect(0, 0, 0, 0)

    readonly property bool active: address !== '' || workspaceId !== 0 || appId !== '' || trayKey !== ''

    function begin(windowAddress: string, workspace: int, app: string, tray: string, source: string, grab: var, size: size, point: point, screen: var, rect: rect, returnArea: rect): void {
        from = source
        address = windowAddress
        workspaceId = workspace
        appId = app
        trayKey = tray
        begunWorkspaceId = workspace
        begunAppId = app
        begunTrayKey = tray
        begunOrigin = rect
        begunReturn = returnArea
        begins++
    }

    function end(): void {
        address = ''
        workspaceId = 0
        appId = ''
        trayKey = ''
        from = ''
    }
}
