import Quickshell
import QtQuick
import qs.design

// The start orb at the bar's left end. As in Windows Vista it is bigger than the bar and rises above its
// top edge, which the bar cannot draw (a window cannot draw outside itself), so the orb is its own popup of
// the bar, always above it. Only the orb and the bar's corner under it take the pointer: the rest of the
// popup lets clicks through, and throwing the pointer into the screen's corner still hits the button.
PopupWindow {
    id: root

    property int barHeight: 48

    readonly property int orbDiameter: 50
    // The gap between the orb and the screen's bottom edge.
    readonly property int bottomGap: 3
    // How far the orb rises above the bar's top edge.
    readonly property int rise: orbDiameter + bottomGap - barHeight
    // Room around the orb for its hover glow.
    readonly property int glowRoom: Theme.orbGlowBlur

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: mouseArea.pressed

    signal clicked()

    implicitWidth: orb.x + orbDiameter + glowRoom
    implicitHeight: glowRoom + rise + barHeight
    color: 'transparent'
    visible: true
    mask: Region {
        item: corner

        Region {
            item: orb
            shape: RegionShape.Ellipse
        }
    }

    // The bar's part of the button: from the screen's left edge to just past the orb, the bar's height.
    Item {
        id: corner

        y: root.height - root.barHeight
        width: orb.x + root.orbDiameter + Theme.space1
        height: root.barHeight
    }

    StartOrb {
        id: orb

        x: Theme.space2
        y: root.height - root.bottomGap - root.orbDiameter
        diameter: root.orbDiameter
        hovered: root.hovered
        pressed: root.pressed
    }

    Item {
        anchors.fill: parent
        Accessible.role: Accessible.Button
        Accessible.name: qsTr('Start')
        Accessible.onPressAction: root.clicked()

        HoverHandler {
            id: hoverHandler
        }

        MouseArea {
            id: mouseArea

            anchors.fill: parent
            onClicked: root.clicked()
        }
    }
}
