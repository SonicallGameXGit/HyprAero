import QtQuick
import 'trayGlyphs.js' as TrayGlyphs

// Windows 7's power icon in the notification area, a pixel drawing (`trayGlyphs.js`): a battery standing up,
// filled from the bottom as far as it is charged (`level` 0 to 1), a plug in front of it while plugged in,
// the sign of `badge` (low, critical) on its corner.
Item {
    id: root

    property real level: 1
    property bool plugged: false
    property string badge: 'none'
    property real size: 16

    implicitWidth: size
    implicitHeight: size

    PixelGlyph {
        anchors.fill: parent
        size: root.size
        rows: TrayGlyphs.battery(root.level, root.plugged, root.badge)
    }
}
