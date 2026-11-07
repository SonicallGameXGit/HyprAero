import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import qs.design
import qs.services

// One workspace: a dot when empty, the window's icon when it has one window, and the biggest window's icon
// with the second biggest's as a small badge in the bottom-right corner when it has several, of one app or
// not (each that window's icon, `IconOverrides.windowIcon`). While a window asks for attention it is the
// main icon, the others after it, and the button flashes as Windows 7's (`bar.attentionFlashes`
// times, then orange until the window gets focus). A workspace given an icon of its own (`IconOverrides`)
// always shows only that, whatever its windows are, empty too. One with windows is an open
// app's button, as on the Windows 7 taskbar, the one on screen brighter. One with windows can be dragged
// along the bar to move the workspace among the others, as Windows 7 reorders its buttons; where it goes is
// the bar's business (`reorder*` signals, the offset along the bar since the press). A right click asks for
// its menu (`menuRequested`). A title the user gave the workspace (`WorkspaceTitles`) is drawn small along
// the bottom of the button, with a soft shadow and nothing behind it.
TaskbarButton {
    id: root

    property var entry: null

    readonly property string mainApp: entry === null || entry.mainApp === null ? '' : entry.mainApp
    readonly property string secondApp: entry === null || entry.secondApp === null ? '' : entry.secondApp
    readonly property string mainWindow: entry === null || typeof entry.mainWindow !== 'string' ? '' : entry.mainWindow
    readonly property string secondWindow: entry === null || typeof entry.secondWindow !== 'string' ? '' : entry.secondWindow
    // The workspace's own icon, '' when it shows its windows' icons.
    readonly property string ownPath: entry === null ? '' : IconOverrides.workspaceIcon(entry.id)
    readonly property string mainPath: {
        if (ownPath !== '') {
            return ownPath
        }

        return mainApp === '' ? '' : IconOverrides.windowIcon(mainWindow, mainApp)
    }
    readonly property string secondPath: ownPath !== '' || secondApp === '' ? '' : IconOverrides.windowIcon(secondWindow, secondApp)
    // The user's title for it, '' for none.
    readonly property string title: entry === null ? '' : WorkspaceTitles.titleOf(entry.id)
    readonly property int iconSize: 36
    readonly property int badgeSize: 18

    readonly property bool focused: entry !== null && entry.focused

    signal reorderStarted()
    signal reorderMoved(real offset)
    signal reorderEnded()
    // `at` is in this button.
    signal menuRequested(point at)

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

    // Everything but the title: with a title it fades out towards the bottom, down to the title's height, so
    // the words are easy to read over it while the button stays see-through (a mask, not a pane). Without a GPU
    // (Qt's software renderer leaves effects out) it stays as it is. `OpacityMask` (Qt5Compat) does it:
    // `MultiEffect`'s mask took no effect when its mask item was not drawn, and one that is drawn shows.
    Item {
        id: icons

        anchors.fill: parent
        // With a title the faded copy below is what shows, drawn from this one.
        visible: root.title === ''
        layer.enabled: root.title !== ''

        DotIcon {
            anchors.centerIn: icons
            visible: root.mainApp === '' && root.ownPath === ''
        }

        GenericAppIcon {
            anchors.centerIn: icons
            width: root.iconSize
            height: root.iconSize
            visible: root.mainApp !== '' && root.mainPath === ''
        }

        AppIconImage {
            anchors.centerIn: icons
            width: root.iconSize
            height: root.iconSize
            visible: root.mainPath !== ''
            source: root.mainPath
        }

        GenericAppIcon {
            x: icons.width / 2 + root.iconSize / 2 - root.badgeSize + 2
            y: icons.height / 2 + root.iconSize / 2 - root.badgeSize + 2
            width: root.badgeSize
            height: root.badgeSize
            visible: root.ownPath === '' && root.secondApp !== '' && root.secondPath === ''
        }

        AppIconImage {
            x: icons.width / 2 + root.iconSize / 2 - root.badgeSize + 2
            y: icons.height / 2 + root.iconSize / 2 - root.badgeSize + 2
            width: root.badgeSize
            height: root.badgeSize
            visible: root.secondPath !== ''
            source: root.secondPath
        }
    }

    OpacityMask {
        anchors.fill: icons
        visible: root.title !== ''
        source: icons
        maskSource: fadeMask
    }

    // Only its transparency counts, and it is never drawn itself.
    Item {
        id: fadeMask

        anchors.fill: parent
        visible: false

        Rectangle {
            anchors.fill: parent

            // Whole down to just above the title, gone by the middle of its height. (A stop's `parent` is the
            // gradient, not the rectangle, so the size is read from the mask.)
            gradient: Gradient {
                GradientStop {
                    position: Math.max(0, (fadeMask.height - titleText.implicitHeight - Theme.space1) / fadeMask.height)
                    color: '#ffffff'
                }

                GradientStop {
                    position: Math.max(0, (fadeMask.height - titleText.implicitHeight / 2) / fadeMask.height)
                    color: 'transparent'
                }
            }
        }
    }

    // The user's title for the workspace (`WorkspaceTitles`): white words with Windows 7's soft shadow, drawn
    // straight on the button along the bottom; the badge stays over it. The effects sit under the text, which
    // draws over them again: without a GPU (Qt's software renderer leaves effects out) the text alone still
    // shows, over the bold copy. What casts the shadow: the same words in bold, so the shadow is thicker than the text without being
    // stretched. Black, and under the text.
    GlassText {
        id: shadowText

        anchors.centerIn: titleText
        color: Theme.taskbarGlassTextShadowColor
        visible: root.title !== ''
        text: root.title
        elide: Text.ElideRight
        // Bold is a little wider than the title: room for that, cut off the same way when it is long.
        width: Math.min(implicitWidth, parent.width - Theme.space1)
        font.pixelSize: Theme.fontSizeSmall
        // font.bold: true
    }

    Repeater {
        model: root.title === '' ? 0 : Theme.taskbarGlassTextShadowLayers

        MultiEffect {
            anchors.fill: shadowText
            source: shadowText
            shadowEnabled: true
            shadowColor: Theme.taskbarGlassTextShadowColor
            shadowHorizontalOffset: Theme.taskbarGlassTextShadowOffset
            shadowVerticalOffset: Theme.taskbarGlassTextShadowOffset
            shadowBlur: 1
            blurMax: Theme.taskbarGlassTextShadowBlur
            autoPaddingEnabled: true
        }
    }

    GlassText {
        id: titleText

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        width: Math.min(implicitWidth, parent.width - Theme.space1)
        elide: Text.ElideRight
        visible: root.title !== ''
        text: root.title
        font.pixelSize: Theme.fontSizeSmall
    }
}
