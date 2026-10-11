pragma Singleton

import QtQuick

// Stand-in for services/Workspaces.qml in QML tests: only the drag formats.
QtObject {
    readonly property string windowDragFormat: 'application/x-hypraero-window'
    readonly property string workspaceDragFormat: 'application/x-hypraero-workspace'
}
