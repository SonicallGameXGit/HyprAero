import Quickshell
import QtQuick
import qs.design

// The tooltip of an icon-only control on the bar (a pin). The bar is too low to hold one, so it is a small
// popup of the bar standing over the control, drawn by the family `Tooltip`. It is placed only once the
// pointer has rested (`Tooltip.waited`): by then the last one has faded out, so it never jumps while shown.
PopupWindow {
    id: root

    // The control, in the bar's window; `shown` usually its hover.
    property Item target: null
    property bool shown: false
    property string text: ''
    // Where the control is in the bar, taken when the tooltip is placed.
    property rect place: Qt.rect(0, 0, 1, 1)
    // Room around the tooltip for its shadow.
    readonly property int shadowRoom: Theme.menuShadowBlur / 2 + Theme.menuShadowOffset

    anchor.rect: Qt.rect(place.x, place.y, place.width, 1)
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    implicitWidth: tip.width + shadowRoom * 2
    implicitHeight: tip.height + Theme.space1 + shadowRoom * 2
    color: 'transparent'
    visible: tip.visible
    // Only looked at; the pointer goes through to whatever is under it.
    mask: Region {}

    Item {
        id: content

        anchors.fill: parent

        // The tooltip stands over this, as over its control.
        Item {
            id: strip

            y: parent.height - root.shadowRoom
            width: parent.width
            height: 1
        }

        Tooltip {
            id: tip

            target: strip
            shown: root.shown && root.target !== null
            text: root.text
            onWaitedChanged: {
                if (waited && root.target !== null) {
                    const at = root.target.mapToItem(null, 0, 0)
                    root.place = Qt.rect(at.x, at.y, root.target.width, root.target.height)
                }
            }
        }
    }
}
