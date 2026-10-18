import QtQuick
import 'trayGlyphs.js' as TrayGlyphs

// Windows 7's Bluetooth icon, a pixel drawing (`trayGlyphs.js`): the white rune on a blue rounded badge,
// steel grey while the adapter is off (`active` false).
Item {
    id: root

    property bool active: true
    property real size: 16

    implicitWidth: size
    implicitHeight: size

    PixelGlyph {
        anchors.fill: parent
        size: root.size
        rows: TrayGlyphs.bluetooth(root.active)
    }
}
