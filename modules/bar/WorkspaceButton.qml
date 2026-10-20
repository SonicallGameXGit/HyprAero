import QtQuick
import qs.design
import qs.services

// One workspace: a dot when empty, the app icon when it has one app, and the biggest app's icon
// with the second biggest as a small badge in the bottom-right corner when it has several. One with
// windows is an open app's button, as on the Windows 7 taskbar, the one on screen brighter. One with windows
// can be dragged along the bar to move the workspace among the others, as Windows 7 reorders its buttons;
// where it goes is the bar's business (`reorder*` signals, the offset along the bar since the press).
TaskbarButton {
    id: root

    property var entry: null

    readonly property string mainApp: entry === null || entry.mainApp === null ? '' : entry.mainApp
    readonly property string secondApp: entry === null || entry.secondApp === null ? '' : entry.secondApp
    readonly property string mainPath: mainApp === '' ? '' : AppIcons.pathFor(mainApp)
    readonly property string secondPath: secondApp === '' ? '' : AppIcons.pathFor(secondApp)
    readonly property int iconSize: 36
    readonly property int badgeSize: 18

    readonly property bool focused: entry !== null && entry.focused

    signal reorderStarted()
    signal reorderMoved(real offset)
    signal reorderEnded()

    iconSource: mainPath
    open: entry !== null && entry.windows.length > 0
    current: focused
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

    DotIcon {
        anchors.centerIn: parent
        visible: root.mainApp === ''
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
        visible: root.secondApp !== '' && root.secondPath === ''
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
