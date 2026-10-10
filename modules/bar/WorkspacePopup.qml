import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.design
import qs.services

// The window previews of a workspace, shown above its button like the Windows 7 taskbar thumbnails:
// one card per window (icon and title on top, a live picture below), biggest window first.
//
// The popup window itself is created once, as wide as the bar, and never moves; only the glass panel
// inside it glides to the hovered button. Moving or resizing a popup window makes the compositor
// re-place it, which showed as a jump to the screen corner. The window passes the pointer through
// everywhere except on the panel.
PopupWindow {
    id: root

    // The windows to show, the x of the hovered button's center in the bar, and whether to show at all.
    property var windows: []
    property real centerX: 0
    property bool shown: false

    readonly property int maxColumns: 4
    readonly property int columns: Math.max(Math.min(windows.length, maxColumns), 1)
    readonly property int cardWidth: 200
    readonly property int previewHeight: 120
    readonly property int iconSize: 16
    readonly property int edgeMargin: Theme.space2
    // Room for the tallest list (three rows of cards) so the window never has to resize.
    readonly property int windowHeight: 520
    // The first placement after a pause snaps; only moves between buttons glide.
    property bool glide: false

    signal hoverChanged(bool hovered)

    implicitWidth: anchor.rect.width
    implicitHeight: windowHeight
    color: 'transparent'
    visible: shown || panel.opacity > 0
    mask: Region {
        item: panel
    }

    onShownChanged: {
        if (shown) {
            return
        }

        glide = false
    }

    // Once the panel has been placed, later moves animate.
    Timer {
        id: glideTimer

        interval: 30
        running: root.shown
        onTriggered: root.glide = true
    }

    GlassPanel {
        id: panel

        readonly property real wantedX: root.centerX - width / 2

        x: Math.max(root.edgeMargin, Math.min(wantedX, root.width - width - root.edgeMargin))
        y: root.height - height
        width: grid.implicitWidth + Theme.space3 * 2
        height: grid.implicitHeight + Theme.space3 * 2
        cornerRadius: Theme.radiusPanel
        opacity: root.shown && root.windows.length > 0 ? 1 : 0

        Behavior on x {
            enabled: root.glide
            NumberAnimation { duration: Theme.motionSoft; easing.type: Easing.OutCubic }
        }

        Behavior on width {
            enabled: root.glide
            NumberAnimation { duration: Theme.motionSoft; easing.type: Easing.OutCubic }
        }

        Behavior on height {
            enabled: root.glide
            NumberAnimation { duration: Theme.motionSoft; easing.type: Easing.OutCubic }
        }

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
        }

        // Lets the bar keep the popup open while the pointer is on it, not only on the button.
        HoverHandler {
            onHoveredChanged: root.hoverChanged(hovered)
        }

        Grid {
            id: grid

            x: Theme.space3
            y: Theme.space3
            columns: root.columns
            spacing: Theme.space2

            Repeater {
                model: root.windows.length

                Column {
                    id: card

                    required property int index

                    readonly property var window: root.windows[index]
                    readonly property string iconPath: AppIcons.pathFor(window.appId)

                    width: root.cardWidth
                    spacing: Theme.space1

                    Row {
                        width: parent.width
                        height: root.iconSize
                        spacing: Theme.space1

                        GenericAppIcon {
                            width: root.iconSize
                            height: root.iconSize
                            visible: card.iconPath === ''
                        }

                        Image {
                            width: root.iconSize
                            height: root.iconSize
                            sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
                            visible: card.iconPath !== ''
                            source: card.iconPath
                            asynchronous: true
                            smooth: true
                        }

                        Text {
                            width: parent.width - root.iconSize - Theme.space1
                            height: root.iconSize
                            verticalAlignment: Text.AlignVCenter
                            // An untitled window still needs a name in the card.
                            text: card.window.title === '' ? card.window.appId : card.window.title
                            color: Theme.glassText
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fontSizeBody
                            elide: Text.ElideRight
                        }
                    }

                    // A fixed slot keeps the grid steady; the frame inside hugs the picture, so only the
                    // window itself is outlined, not the empty space around it.
                    Item {
                        id: slot

                        width: parent.width
                        height: root.previewHeight

                        Rectangle {
                            // Keep the window's proportions, as large as the slot allows. The size comes
                            // from Hyprland: the capture view reports none of its own.
                            readonly property real fit: card.window.width > 0 && card.window.height > 0
                                ? Math.min((slot.width - 2) / card.window.width, (slot.height - 2) / card.window.height)
                                : 0

                            anchors.centerIn: parent
                            width: view.hasContent ? card.window.width * fit + 2 : slot.width
                            height: view.hasContent ? card.window.height * fit + 2 : slot.height
                            radius: Theme.radiusControl
                            color: view.hasContent ? 'transparent' : Theme.surfaceSunken
                            border.width: 1
                            border.color: Theme.surfaceBorder

                            // Shown until the compositor delivers a picture, and kept when it never does.
                            GenericAppIcon {
                                anchors.centerIn: parent
                                width: 48
                                height: 48
                                visible: !view.hasContent
                            }

                            Item {
                                id: content

                                anchors.fill: parent
                                anchors.margins: 1

                                // The picture is captured at the window's full size, far bigger than the card.
                                // Drawn straight down it would alias (look pixelated), so it is first drawn
                                // at twice the card size and then shown through a mipmapped texture.
                                ScreencopyView {
                                    id: view

                                    width: content.width * 2
                                    height: content.height * 2
                                    captureSource: card.window.preview
                                    live: root.visible
                                    smooth: true
                                }

                                ShaderEffectSource {
                                    anchors.fill: parent
                                    sourceItem: view
                                    hideSource: true
                                    textureSize: Qt.size(view.width, view.height)
                                    mipmap: true
                                    smooth: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
