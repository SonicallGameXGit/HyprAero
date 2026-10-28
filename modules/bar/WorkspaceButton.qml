import QtQuick
import qs.design
import qs.services

// One workspace: a dot when empty, the app icon when it has one app, and the biggest app's icon
// with the second biggest as a small badge in the bottom-right corner when it has several (each the icon of
// that app's biggest window, `IconOverrides.windowIcon`). While a window asks for attention its app is the
// main icon (of that window), the others after it, and the button flashes as Windows 7's (`bar.attentionFlashes`
// times, then orange until the window gets focus). A workspace given an icon of its own (`IconOverrides`)
// always shows only that, whatever its windows are, empty too. One with windows is an open
// app's button, as on the Windows 7 taskbar, the one on screen brighter. One with windows can be dragged
// along the bar to move the workspace among the others, as Windows 7 reorders its buttons; where it goes is
// the bar's business (`reorder*` signals, the offset along the bar since the press). A right click asks for
// its menu (`menuRequested`).
TaskbarButton {
    id: root

    property var entry: null

    readonly property string mainApp: entry === null || entry.mainApp === null ? '' : entry.mainApp
    readonly property string secondApp: entry === null || entry.secondApp === null ? '' : entry.secondApp
    // The workspace's own icon, '' when it shows its windows' icons.
    readonly property string ownPath: entry === null ? '' : IconOverrides.workspaceIcon(entry.id)
    readonly property string mainPath: {
        if (ownPath !== '') {
            return ownPath
        }

        return mainApp === '' ? '' : appWindowIcon(mainApp)
    }
    readonly property string secondPath: ownPath !== '' || secondApp === '' ? '' : appWindowIcon(secondApp)
    readonly property int iconSize: 36
    readonly property int badgeSize: 18

    readonly property bool focused: entry !== null && entry.focused

    signal reorderStarted()
    signal reorderMoved(real offset)
    signal reorderEnded()
    // `at` is in this button.
    signal menuRequested(point at)

    // The icon of the app's window asking for attention, else of its biggest (the windows come biggest first).
    function appWindowIcon(appId: string): string {
        const asking = entry.windows.find(item => item.appId === appId && item.urgent === true)
        const window = asking === undefined ? entry.windows.find(item => item.appId === appId) : asking
        return IconOverrides.windowIcon(window === undefined ? '' : window.address, appId)
    }

    iconSource: mainPath
    open: entry !== null && entry.windows.length > 0
    current: focused
    attention: entry !== null && entry.attention === true
    attentionFlashes: Math.max(0, Math.min(Config.bar.attentionFlashes, 100))
    implicitWidth: 72
    implicitHeight: 48

    // Under the button's MouseArea (`TaskbarButton`), so a click still gets through; sideways only.
    DragHandler {
        id: reorderHandler

        target: null
        yAxis.enabled: false
        enabled: root.entry !== null && root.entry.windows.length > 0
        onActiveChanged: {
            if (active) {
                root.reorderStarted()
            } else {
                root.reorderEnded()
            }
        }
        onActiveTranslationChanged: {
            if (active) {
                root.reorderMoved(activeTranslation.x)
            }
        }
    }

    // A window here asking again while it already asks: the flashing starts over, as on Windows 7.
    Connections {
        target: Workspaces

        function onAttentionRequested(address: string): void {
            if (root.entry !== null && root.entry.windows.some(window => window.address === address && window.urgent === true)) {
                root.flash()
            }
        }
    }

    // The button's own MouseArea takes only the left button, so a right press comes down to here.
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: eventPoint => root.menuRequested(eventPoint.position)
    }

    DotIcon {
        anchors.centerIn: parent
        visible: root.mainApp === '' && root.ownPath === ''
    }

    GenericAppIcon {
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        visible: root.mainApp !== '' && root.mainPath === ''
    }

    AppIconImage {
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        visible: root.mainPath !== ''
        source: root.mainPath
    }

    GenericAppIcon {
        x: parent.width / 2 + root.iconSize / 2 - root.badgeSize + 2
        y: parent.height / 2 + root.iconSize / 2 - root.badgeSize + 2
        width: root.badgeSize
        height: root.badgeSize
        visible: root.ownPath === '' && root.secondApp !== '' && root.secondPath === ''
    }

    AppIconImage {
        x: parent.width / 2 + root.iconSize / 2 - root.badgeSize + 2
        y: parent.height / 2 + root.iconSize / 2 - root.badgeSize + 2
        width: root.badgeSize
        height: root.badgeSize
        visible: root.secondPath !== ''
        source: root.secondPath
    }
}
