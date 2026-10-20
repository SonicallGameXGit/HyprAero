import Quickshell.Wayland
import QtQuick
import qs.services
import '../../services/peek.js' as PeekLogic
import '../../services/pictureBounds.js' as PictureBounds

// One window of the peek, drawn where it really is on its monitor and at its real size. Hyprland's numbers
// are layout pixels; `unit` says how many of them one unit of this layer is, so the picture is right
// whatever QT_SCALE_FACTOR the shell runs with.
//
// A window hanging off its monitor is drawn only where it lies on it. Hyprland leaves the part it did not
// draw transparent in the capture and the part that is drawn does not land where the window's position says
// (`PreviewCards`), so such a window is captured once, the picture is read for its drawn part
// (`pictureBounds.js`) and only that part is shown, in the visible place.
Item {
    id: root

    property var window: null
    property real unit: 1
    // The layer is shown, so the window may be captured.
    property bool active: true

    // The part of the window on its monitor, in this layer's units (null: nowhere to draw it).
    readonly property var place: {
        if (window === null) {
            return null
        }

        const visible = PeekLogic.visibleRect(window)
        if (visible === null) {
            return null
        }

        return {
            x: visible.x / unit,
            y: visible.y / unit,
            width: visible.width / unit,
            height: visible.height / unit,
        }
    }
    readonly property bool still: window !== null && window.offScreen
    // The drawn part of the capture as fractions of it, found by `scan`; the whole capture while not `still`.
    property var crop: null
    readonly property var shownCrop: still ? crop : ({ x: 0, y: 0, width: 1, height: 1 })
    // Has its picture, or will never get one (nothing to draw, or the compositor offers no handle).
    readonly property bool settled: place === null || window.preview === null || (still ? crop !== null : view.hasContent)
    // Its window was asked to close: no more frames are asked for (`Workspaces.closingAddresses`).
    readonly property bool closing: window !== null && Workspaces.closingAddresses.includes(window.address)
    // The capture is drawn at twice the size and shrunk with mipmaps, as on the cards, so it is not jagged.
    readonly property int oversample: 2
    readonly property int scanDelay: 100
    readonly property int scanSize: 256
    readonly property int scanThreshold: 128
    // Keeps the grabbed copy alive until `sampler` has read it.
    property var grab: null

    x: place === null ? 0 : place.x
    y: place === null ? 0 : place.y
    width: place === null ? 0 : place.width
    height: place === null ? 0 : place.height

    function scan(): void {
        const host = view.Window.window
        if (host === null || host.visible === false) {
            return
        }

        view.grabToImage(result => {
            grab = result
            scanImage.source = result.url
        }, Qt.size(scanSize, scanSize))
    }

    Connections {
        target: view

        function onHasContentChanged(): void {
            if (view.hasContent && root.still) {
                scanTimer.restart()
            }
        }
    }

    Timer {
        id: scanTimer

        interval: root.scanDelay
        onTriggered: root.scan()
    }

    // The whole window, at its full size: its picture is cut from it below (`texture`).
    ScreencopyView {
        id: view

        width: (root.window === null ? 0 : root.window.width) / root.unit * root.oversample
        height: (root.window === null ? 0 : root.window.height) / root.unit * root.oversample
        captureSource: root.active && root.place !== null && root.window !== null ? root.window.preview : null
        live: root.active && root.still === false && root.closing === false
        smooth: true
    }

    ShaderEffectSource {
        id: texture

        anchors.fill: parent
        // Not before the scan has found what to show; the capture itself is made all the same.
        visible: root.shownCrop !== null && root.shownCrop.width > 0 && root.shownCrop.height > 0
        sourceItem: view
        hideSource: true
        sourceRect: root.shownCrop === null
            ? Qt.rect(0, 0, 0, 0)
            : Qt.rect(root.shownCrop.x * view.width, root.shownCrop.y * view.height, root.shownCrop.width * view.width, root.shownCrop.height * view.height)
        textureSize: Qt.size(sourceRect.width, sourceRect.height)
        mipmap: true
        smooth: true
        live: root.still === false
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
            root.grab = null
            const bounds = PictureBounds.opaqueBounds(pixels, width, height, root.scanThreshold)
            root.crop = bounds
            // Nothing drawn at all: it counts as scanned, with nothing to show.
            if (bounds === null) {
                root.crop = ({ x: 0, y: 0, width: 0, height: 0 })
            }

            Qt.callLater(texture.scheduleUpdate)
        }
    }
}
