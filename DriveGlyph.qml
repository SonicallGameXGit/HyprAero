import QtQuick
import 'trayGlyphs.js' as TrayGlyphs

// Windows 7's "Safely Remove Hardware and Eject Media" icon, a pixel drawing (`trayGlyphs.js`): a USB stick
// with a green tick on its corner, the busy disc going round while a drive is being ejected.
Item {
    id: root

    property bool busy: false
    property real size: 16
    property int frame: 0

    implicitWidth: size
    implicitHeight: size

    PixelGlyph {
        anchors.fill: parent
        size: root.size
        rows: TrayGlyphs.drive(root.busy, root.frame)
    }

    Timer {
        interval: 120
        repeat: true
        running: root.busy && root.visible
        onTriggered: root.frame = (root.frame + 1) % 8
    }
}
