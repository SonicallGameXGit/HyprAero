import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.design
import qs.services
import '../../services/pictureBounds.js' as PictureBounds

// One set of window preview cards, like the Windows 7 taskbar thumbnails: icon and title on top, a
// picture below, biggest window first. The popup keeps two sets so the next workspace's cards can load
// behind the shown ones.
Grid {
    id: root

    // The windows to show, and whether this set is in use: only then are its pictures captured.
    property var windows: []
    property bool active: false
    // Every card has its picture (or will never get one), so the set can be shown without blank cards.
    readonly property bool ready: {
        if (cards.count !== windows.length) {
            return false
        }

        for (let index = 0; index < cards.count; index++) {
            const card = cards.itemAt(index)
            if (card === null || card.settled === false) {
                return false
            }
        }

        return true
    }

    readonly property int maxColumns: 4
    // The picture height is fixed; a card's width follows its window's proportions, kept within these
    // bounds so a very wide or very tall window cannot make a huge or a tiny card.
    readonly property int previewHeight: 120
    readonly property int minCardWidth: 64
    readonly property int maxCardWidth: 280
    // Used while Hyprland has not told the window's size yet.
    readonly property real fallbackAspect: 16 / 9
    // A window hanging off its monitor gets one still picture per opening, checked once for its blank part:
    // how long to wait for the fresh frame, the size of the copy that is checked (a finer one cuts closer
    // but costs more) and the alpha from which a pixel counts as drawn.
    readonly property int scanDelay: 100
    readonly property int scanSize: 256
    readonly property int scanThreshold: 128
    readonly property int iconSize: 16

    columns: Math.max(Math.min(windows.length, maxColumns), 1)
    spacing: Theme.space2

    Repeater {
            id: cards

            model: root.windows.length

            Column {
                id: card

                required property int index

                readonly property var window: root.windows[index]
                readonly property string iconPath: AppIcons.pathFor(window.appId)

                // The captured picture's own size wins over Hyprland's window size (they can differ,
                // e.g. for floating windows), which stays as the early guess.
                readonly property size captureSize: view.sourceSize.width > 0 && view.sourceSize.height > 0
                    ? Qt.size(view.sourceSize.width, view.sourceSize.height)
                    : Qt.size(window.width, window.height)
                // A window fully on its monitor is shown live and whole. One hanging off it is captured
                // with the off-screen part blank, and a live picture of it would also slide around during
                // workspace animations; so it gets one still picture per opening, cropped to the box
                // around its drawn pixels (fractions of the capture, found by `scan`).
                readonly property bool still: window.offScreen
                property var scannedCrop: null
                readonly property var crop: still && scannedCrop !== null ? scannedCrop : ({ x: 0, y: 0, width: 1, height: 1 })
                readonly property bool pictureReady: view.hasContent && (still === false || scannedCrop !== null)
                // Has its picture, or will never get one (the compositor offers no handle).
                readonly property bool settled: pictureReady || window.preview === null
                // A card can be handed another window (the list is re-sorted); its crop belongs to the old one.
                readonly property var preview: window.preview
                readonly property size pictureSize: Qt.size(captureSize.width * crop.width, captureSize.height * crop.height)
                readonly property real aspect: pictureSize.width > 0 && pictureSize.height > 0
                    ? pictureSize.width / pictureSize.height
                    : root.fallbackAspect
                // Keeps the grabbed copy alive until `sampler` has read it.
                property var grab: null

                width: Math.max(root.minCardWidth, Math.min(Math.round(aspect * root.previewHeight) + 2, root.maxCardWidth))
                spacing: Theme.space1

                onPreviewChanged: {
                    scannedCrop = null
                    if (still) {
                        refreshStill()
                    }
                }

                onStillChanged: {
                    if (still) {
                        refreshStill()
                    }
                }

                // Takes a fresh frame and scans it once it has had time to arrive.
                function refreshStill(): void {
                    if (view.hasContent === false) {
                        return
                    }

                    view.captureFrame()
                    scanTimer.restart()
                }

                // Copies a small version of the whole capture; `sampler` reads its pixels.
                function scan(): void {
                    view.grabToImage(result => {
                        grab = result
                        scanImage.source = result.url
                    }, Qt.size(root.scanSize, root.scanSize))
                }

                // Shows the new frame and its crop together, so the old picture never gets the new crop.
                function applyScan(bounds: var): void {
                    if (bounds !== null) {
                        scannedCrop = bounds
                    }
                    Qt.callLater(texture.scheduleUpdate)
                }

                Connections {
                    target: root

                    function onActiveChanged(): void {
                        if (root.active && card.still) {
                            card.refreshStill()
                        }
                    }
                }

                Connections {
                    target: view

                    function onHasContentChanged(): void {
                        if (view.hasContent && card.still) {
                            scanTimer.restart()
                        }
                    }
                }

                Timer {
                    id: scanTimer

                    interval: root.scanDelay
                    onTriggered: card.scan()
                }

                Row {
                    width: parent.width
                    height: root.iconSize
                    spacing: Theme.space1

                    GenericAppIcon {
                        width: root.iconSize
                        height: root.iconSize
                        visible: card.iconPath === ''
                    }

                    AppIconImage {
                        width: root.iconSize
                        height: root.iconSize
                        visible: card.iconPath !== ''
                        source: card.iconPath
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
                        // Keep the picture's proportions, as large as the slot allows.
                        readonly property real fit: card.pictureSize.width > 0 && card.pictureSize.height > 0
                            ? Math.min((slot.width - 2) / card.pictureSize.width, (slot.height - 2) / card.pictureSize.height)
                            : 0

                        anchors.centerIn: parent
                        width: card.pictureReady ? card.pictureSize.width * fit + 2 : slot.width
                        height: card.pictureReady ? card.pictureSize.height * fit + 2 : slot.height
                        radius: Theme.radiusControl
                        color: card.pictureReady ? 'transparent' : Theme.surfaceSunken
                        border.width: 1
                        border.color: Theme.surfaceBorder

                        // Shown until the compositor delivers a picture, and kept when it never does.
                        GenericAppIcon {
                            anchors.centerIn: parent
                            width: 48
                            height: 48
                            visible: card.pictureReady === false
                        }

                        Item {
                            id: content

                            anchors.fill: parent
                            anchors.margins: 1

                            // The picture is captured at the window's full size, far bigger than the card.
                            // Drawn straight down it would alias (look pixelated), so it is first drawn
                            // at twice the card size and then shown through a mipmapped texture. The view
                            // holds the whole capture in its own proportions (so it adds no bars of its
                            // own); the texture takes only the cropped part.
                            ScreencopyView {
                                id: view

                                width: content.width * 2 / card.crop.width
                                height: content.height * 2 / card.crop.height
                                captureSource: card.window.preview
                                live: root.active && card.still === false
                                smooth: true
                            }

                            ShaderEffectSource {
                                id: texture

                                anchors.fill: parent
                                sourceItem: view
                                hideSource: true
                                sourceRect: Qt.rect(card.crop.x * view.width, card.crop.y * view.height, content.width * 2, content.height * 2)
                                textureSize: Qt.size(content.width * 2, content.height * 2)
                                mipmap: true
                                smooth: true
                                // A still picture changes only together with its crop (`applyScan`).
                                live: card.still === false
                            }

                            // Where `scan` reads the pixels; never seen.
                            Image {
                                id: scanImage

                                visible: false
                                onStatusChanged: {
                                    if (status === Image.Ready) {
                                        sampler.requestPaint()
                                    }
                                }
                            }

                            Canvas {
                                id: sampler

                                width: root.scanSize
                                height: root.scanSize
                                opacity: 0
                                onPaint: {
                                    if (scanImage.status !== Image.Ready) {
                                        return
                                    }

                                    const context = getContext('2d')
                                    context.clearRect(0, 0, width, height)
                                    context.drawImage(scanImage, 0, 0, width, height)
                                    const pixels = context.getImageData(0, 0, width, height).data
                                    scanImage.source = ''
                                    card.grab = null
                                    card.applyScan(PictureBounds.opaqueBounds(pixels, width, height, root.scanThreshold))
                                }
                            }
                        }
                    }
                }
            }
        }
}
