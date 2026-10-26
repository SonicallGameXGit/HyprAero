import Quickshell
import Quickshell.Wayland
import QtQuick

// Reads an icon's pixels at 16 or 32 pixels, for the plugin, which cannot read files itself (AGENTS.md section
// 5.1). The icon is loaded at that size by the icon theme (sharp, as the theme made it for that size) and read back
// from a canvas. A canvas only paints inside a window, so this is one: see-through, behind everything, taking no
// input, and made only while it reads (shell.qml).
PanelWindow {
    id: root

    property string source: ''
    property int size: 16
    // Read once for each start, however many times the canvas paints
    property bool waiting: false
    readonly property int largest: 32

    signal read(var pixels)
    signal failed

    function start(path: string, pixelSize: int): void {
        // A canvas keeps a picture by its address alone, whatever size it was loaded at: let the last one go, so
        // the same icon at the next size is loaded again instead of the smaller one being scaled up
        if (source !== '') {
            canvas.unloadImage(source)
        }

        size = pixelSize
        source = path
        waiting = true
        canvas.loadImage(path, Qt.size(pixelSize, pixelSize))
        canvas.check()
    }

    WlrLayershell.namespace: 'hypraero-frames-icons'
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        left: true
    }

    implicitWidth: largest
    implicitHeight: largest
    color: 'transparent'
    mask: Region {}

    Canvas {
        id: canvas

        // Painted once the picture is there, or gives up when it cannot be loaded
        function check(): void {
            if (root.waiting === false) {
                return
            }

            if (isImageError(root.source)) {
                root.waiting = false
                root.failed()
            } else if (isImageLoaded(root.source)) {
                requestPaint()
            }
        }

        width: root.largest
        height: root.largest
        // Still painted at no opacity, so it is read without being seen.
        opacity: 0

        onImageLoaded: check()

        onPaint: {
            if (root.waiting === false || isImageLoaded(root.source) === false) {
                return
            }

            root.waiting = false

            const context = getContext('2d')
            context.clearRect(0, 0, width, height)
            context.drawImage(root.source, 0, 0, root.size, root.size)
            root.read(context.getImageData(0, 0, root.size, root.size).data)
        }
    }
}
