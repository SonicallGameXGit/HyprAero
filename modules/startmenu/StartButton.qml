import Quickshell
import QtQuick
import qs.design

// The start orb at the bar's left end. As in Windows Vista it is bigger than the bar and rises above its
// top edge, which the bar cannot draw (a window cannot draw outside itself), so the orb is its own popup of
// the bar, always above it. Only the orb and the bar's corner under it take the pointer: the rest of the
// popup lets clicks through, and throwing the pointer into the screen's corner still hits the button.
// The popup runs past the screen's bottom edge as far as it rises above the bar, so the orb is cut by the
// screen itself (it reads as going on out of sight) and never by the popup's own edge.
PopupWindow {
    id: root

    property int barHeight: 48
    // Its menu is open, however it was opened (a click, or a key binding through IPC): the orb stays lit
    // as under the pointer, as in Windows 7.
    property bool menuOpen: false

    readonly property int orbDiameter: 54
    // How far the orb rises above the bar's top edge: it is centred on the bar, so as much of it hangs
    // below the screen's bottom edge, out of sight.
    readonly property int rise: (orbDiameter - barHeight) / 2
    // How much of the bar the button takes from its left end (the corner that counts as the orb).
    readonly property int barWidth: corner.width
    // Room around the orb for its hover glow.
    readonly property int glowRoom: Theme.orbGlowBlur

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: mouseArea.pressed

    signal clicked()

    implicitWidth: orb.x + orbDiameter + glowRoom
    implicitHeight: glowRoom + orbDiameter + glowRoom
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

        y: root.glowRoom - root.rise
        width: orb.x + root.orbDiameter + Theme.space1
        height: root.barHeight
    }

    StartOrb {
        id: orb

        x: Theme.space2
        y: root.glowRoom
        diameter: root.orbDiameter
        hovered: root.hovered
        pressed: root.pressed
        highlighted: root.menuOpen
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
