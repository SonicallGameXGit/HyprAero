import Quickshell.Wayland
import QtQuick
import qs.design
import qs.services
import '../../services/peek.js' as PeekLogic

// One picture of the peek (`peekScene` in `services/peek.js`), from the back to the front:
//   - the Aero backdrop, when the workspace is not on screen (what the real one would show is not there to
//     show through); with a workspace on screen nothing is drawn, so the real windows show through;
//   - the windows of the workspace that are under the highlighted one, each where it is (`PeekWindow`);
//   - a darkening of all that, when one window is highlighted;
//   - the highlighted window: where it is, or, for a window that fills the screen anyway (a fullscreen or a
//     lone tiled one), lifted out almost full screen in a frame of window glass with its icon and title.
Item {
    id: root

    property var scene: null
    // Layout pixels per unit of this item (see `PeekWindow`).
    property real unit: 1
    // The layer is shown: windows are captured.
    property bool active: false

    readonly property string key: PeekLogic.sceneKey(scene)
    // Every picture has arrived (or never will), so the scene can be shown without empty places.
    readonly property bool ready: {
        if (scene === null) {
            return true
        }

        if (others.count !== scene.windows.length) {
            return false
        }

        for (let index = 0; index < others.count; index++) {
            const item = others.itemAt(index)
            if (item === null || item.settled === false) {
                return false
            }
        }

        if (scene.mode === 'fit') {
            return fitWindow === null || fitWindow.preview === null || fitView.hasContent
        }

        return highlighted.settled
    }
    readonly property var fitWindow: scene !== null && scene.mode === 'fit' ? scene.highlight : null
    // The capture's own size wins over Hyprland's window size, as on the cards.
    readonly property size fitSize: fitView.sourceSize.width > 0 && fitView.sourceSize.height > 0
        ? Qt.size(fitView.sourceSize.width, fitView.sourceSize.height)
        : (fitWindow === null ? Qt.size(0, 0) : Qt.size(fitWindow.width, fitWindow.height))
    readonly property real fitAspect: fitSize.width > 0 && fitSize.height > 0 ? fitSize.width / fitSize.height : 0
    readonly property var fitPlacement: PeekLogic.peekLayout(
        fitAspect,
        { width: width, height: height },
        Theme.space5 + Theme.space2,
        { border: frameBorder, title: titleHeight },
    )
    // The frame is the window glass of FlyoutFrame: lines and glass 8px wide.
    readonly property int frameBorder: 8
    readonly property int titleHeight: 24
    readonly property int iconSize: 16
    readonly property string fitIconPath: fitWindow === null ? '' : AppIcons.pathFor(fitWindow.appId)
    readonly property bool fitClosing: fitWindow !== null && Workspaces.closingAddresses.includes(fitWindow.address)

    Item {
        anchors.fill: parent
        visible: root.scene !== null && root.scene.base === 'backdrop'

        Rectangle {
            anchors.fill: parent

            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.backdropTop }
                GradientStop { position: 0.55; color: Theme.backdropMiddle }
                GradientStop { position: 1.0; color: Theme.backdropBottom }
            }
        }

        // The sky's light, from the top.
        Rectangle {
            anchors.fill: parent

            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.backdropLight }
                GradientStop { position: 0.45; color: 'transparent' }
            }
        }
    }

    Repeater {
        id: others

        model: root.scene === null ? 0 : root.scene.windows.length

        PeekWindow {
            required property int index

            window: root.scene.windows[index]
            unit: root.unit
            active: root.active
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.scene !== null && root.scene.scrim
        color: Theme.overlay
    }

    PeekWindow {
        id: highlighted

        window: root.scene !== null && root.scene.mode === 'compose' ? root.scene.highlight : null
        unit: root.unit
        active: root.active
    }

    Item {
        id: frame

        visible: root.fitWindow !== null && root.fitPlacement !== null
        x: root.fitPlacement === null ? 0 : root.fitPlacement.frame.x
        y: root.fitPlacement === null ? 0 : root.fitPlacement.frame.y
        width: root.fitPlacement === null ? 0 : root.fitPlacement.frame.width
        height: root.fitPlacement === null ? 0 : root.fitPlacement.frame.height

        GlassPanel {
            anchors.fill: parent
            cornerRadius: Theme.radiusWindow
            kind: 'window'
        }

        Row {
            x: root.frameBorder
            y: root.frameBorder
            width: parent.width - root.frameBorder * 2
            height: root.titleHeight
            spacing: Theme.space1

            Item {
                width: root.iconSize
                height: root.titleHeight

                GenericAppIcon {
                    anchors.centerIn: parent
                    width: root.iconSize
                    height: root.iconSize
                    visible: root.fitIconPath === ''
                }

                AppIconImage {
                    anchors.centerIn: parent
                    width: root.iconSize
                    height: root.iconSize
                    visible: root.fitIconPath !== ''
                    source: root.fitIconPath
                }
            }

            GlassText {
                width: parent.width - root.iconSize - Theme.space1
                height: root.titleHeight
                verticalAlignment: Text.AlignVCenter
                // An untitled window still needs a name.
                text: root.fitWindow === null ? '' : (root.fitWindow.title === '' ? root.fitWindow.appId : root.fitWindow.title)
                elide: Text.ElideRight
            }
        }

        // The window itself, sunken into the frame by a thin dark line like a window's client area.
        Rectangle {
            x: root.fitPlacement === null ? 0 : root.fitPlacement.picture.x - frame.x - 1
            y: root.fitPlacement === null ? 0 : root.fitPlacement.picture.y - frame.y - 1
            width: root.fitPlacement === null ? 0 : root.fitPlacement.picture.width + 2
            height: root.fitPlacement === null ? 0 : root.fitPlacement.picture.height + 2
            color: Theme.surfaceSunken
            border.width: 1
            border.color: Theme.glassBorderOuter

            ScreencopyView {
                id: fitView

                x: 1
                y: 1
                width: parent.width - 2
                height: parent.height - 2
                captureSource: root.active && root.fitWindow !== null ? root.fitWindow.preview : null
                live: root.active && root.fitClosing === false
                smooth: true
            }
        }
    }
}
