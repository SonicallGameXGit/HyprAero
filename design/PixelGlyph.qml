import QtQuick

// A pixel drawing (`design/trayGlyphs.js`): each letter of `rows` one pixel of a palette colour, drawn
// sharp, never smoothed, as Windows 7 draws its notification-area icons (.aero/STYLE.md "Notification area
// glyphs"). At a `size` that is a whole multiple of the drawing, every pixel grows to a square.
Item {
    id: root

    property var rows: []
    property real size: 16

    readonly property int across: rows.length === 0 ? 0 : rows[0].length
    readonly property int step: across === 0 ? 1 : Math.max(1, Math.floor(size / across))
    // Each letter's colours, drawn in order.
    readonly property var palette: {
        return {
            '#': [Theme.trayGlyphEdge],
            'W': [Theme.trayGlyphInk],
            'g': [Theme.trayGlyphShade],
            'l': [Theme.trayGlyphShadeLight],
            's': [Theme.trayGlyphScreen],
            'r': [Theme.iconRedDark],
            'p': [Theme.iconRedLight],
            'R': [Theme.iconRedEdge],
            'y': [Theme.iconGoldLight],
            'Y': [Theme.iconGoldDark],
            'o': [Theme.iconGoldEdge],
            'k': [Theme.iconInkDark],
            'v': [Theme.iconGreenLight],
            'V': [Theme.iconGreenDark],
            'n': [Theme.iconGreenEdge],
            'b': [Theme.iconBlueLight],
            'B': [Theme.iconBlueDark],
            'e': [Theme.iconBlueEdge],
            'm': [Theme.iconSteelLight],
            'M': [Theme.iconSteelDark],
            't': [Theme.iconSteelEdge],
        }
    }

    function css(color: color): string {
        return `rgba(${Math.round(color.r * 255)}, ${Math.round(color.g * 255)}, ${Math.round(color.b * 255)}, ${color.a})`
    }

    implicitWidth: size
    implicitHeight: size
    onRowsChanged: canvas.requestPaint()
    onPaletteChanged: canvas.requestPaint()

    Canvas {
        id: canvas

        anchors.centerIn: parent
        width: root.across * root.step
        height: root.rows.length * root.step
        onWidthChanged: requestPaint()
        onPaint: {
            const context = getContext('2d')
            context.reset()
            for (let y = 0; y < root.rows.length; y++) {
                const row = root.rows[y]
                for (let x = 0; x < row.length; x++) {
                    const colors = root.palette[row[x]]
                    if (colors === undefined) {
                        continue
                    }

                    for (const color of colors) {
                        context.fillStyle = root.css(color)
                        context.fillRect(x * root.step, y * root.step, root.step, root.step)
                    }
                }
            }
        }
    }
}
