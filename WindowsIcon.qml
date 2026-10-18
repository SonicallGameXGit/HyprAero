import QtQuick
import '../resources/icons/frames.js' as IconFrames

// One of Windows' own icons kept in `resources/icons/` (`resources/README.md`): `name` drawn `size` pixels
// wide. Windows draws an icon again by hand for each size it ships, so the frame made for the size on the
// screen is taken (`frames.js`); only between those sizes, or on a scaled screen, a bigger frame is shrunk
// by the GPU, as Windows itself shrinks one (the network flyout's signal bars: 32 drawn at 24).
Item {
    id: root

    property string name: ''
    property int size: 16

    readonly property real screenSize: size * Screen.devicePixelRatio
    readonly property int frame: IconFrames.frameFor(name, screenSize)

    implicitWidth: size
    implicitHeight: size

    Image {
        anchors.fill: parent
        visible: root.frame > 0
        source: root.frame > 0 ? Qt.resolvedUrl(`../resources/icons/${root.name}-${root.frame}.png`) : ''
        // At its own size a frame is drawn pixel for pixel, as Windows does.
        smooth: root.frame !== root.screenSize
        mipmap: root.frame !== root.screenSize
    }
}
