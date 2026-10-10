import QtQuick
import qs.design
import qs.services

// One workspace: a dot when empty, the app icon when it has one app, and the biggest app's icon
// with the second biggest as a small badge in the bottom-right corner when it has several.
ControlButton {
    id: root

    property var entry: null

    readonly property string mainApp: entry === null || entry.mainApp === null ? '' : entry.mainApp
    readonly property string secondApp: entry === null || entry.secondApp === null ? '' : entry.secondApp
    readonly property string mainPath: mainApp === '' ? '' : AppIcons.pathFor(mainApp)
    readonly property string secondPath: secondApp === '' ? '' : AppIcons.pathFor(secondApp)
    readonly property int iconSize: 28
    readonly property int badgeSize: 16

    kind: 'tool'
    implicitWidth: 44
    implicitHeight: 40

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
