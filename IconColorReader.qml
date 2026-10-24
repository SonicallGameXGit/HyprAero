import QtQuick
import 'iconColor.js' as IconColor

// Finds the main colour of an icon (`iconColor.js`) by drawing it small on a canvas that is never
// shown and reading its pixels; each icon is read once for the session. Put it anywhere in the item that
// needs the colour.
Canvas {
    id: root

    // An image source (a file or an `image://icon/` address).
    property string source: ''
    // '#rrggbb', or '' while it is being read and for an icon without a colour of its own.
    property string mainColor: ''

    function read(): void {
        const known = IconColor.cached(source)
        if (known !== undefined) {
            mainColor = known
            return
        }

        mainColor = ''
        if (source === '') {
            return
        }

        if (isImageLoaded(source)) {
            requestPaint()
        } else {
            loadImage(source)
        }
    }

    width: 16
    height: 16
    // Still painted at no opacity, so it is read without being seen.
    opacity: 0

    onSourceChanged: read()
    Component.onCompleted: read()
    onImageLoaded: requestPaint()

    onPaint: {
        if (source === '' || IconColor.cached(source) !== undefined) {
            return
        }

        if (isImageError(source)) {
            mainColor = IconColor.remember(source, '')
            return
        }

        // A paint can come before the icon has loaded; the load asks for another.
        if (isImageLoaded(source) === false) {
            return
        }

        const context = getContext('2d')
        context.clearRect(0, 0, width, height)
        context.drawImage(source, 0, 0, width, height)
        mainColor = IconColor.remember(source, IconColor.dominantColor(context.getImageData(0, 0, width, height).data))
        unloadImage(source)
    }
}
