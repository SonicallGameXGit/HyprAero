import Quickshell
import QtQuick
import qs.design

// The tooltip of an icon-only control on the bar (a pin, a tray icon). The bar is too low to hold one, so it
// is a small popup of the bar standing on the bar's top edge over the control, drawn by the family
// `Tooltip`. With `overTarget` it stands over the control itself instead, for a control in a popup of the
// bar (the tray's flyout), the popup then being its window. It is
// placed only once the pointer has rested (`Tooltip.waited`): by then the last one has faded out, so it
// never jumps while shown.
PopupWindow {
    id: root

    // The control, in the bar's window; `shown` usually its hover.
    property Item target: null
    property bool shown: false
    property string text: ''
    // Over the control's top edge instead of the window's.
    property bool overTarget: false
    // The middle of the control across its window, and the edge the tooltip stands on, taken when the
    // tooltip is placed.
    property real centerX: 0
    property real topY: 0
    // Placed over the control the pointer rests on and about to fade in.
    property bool placed: false
    // Room around the tooltip for its shadow.
    readonly property int shadowRoom: Theme.menuShadowBlur + Theme.menuShadowOffset

    // The popup's bottom hangs into the bar, so the tooltip itself stands `space1` over the bar's top edge
    // with only its shadow on the glass.
    anchor.rect: Qt.rect(centerX, topY + shadowRoom - Theme.space1, 1, 1)
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    implicitWidth: tip.width + shadowRoom * 2
    implicitHeight: tip.height + shadowRoom * 2
    color: 'transparent'
    // Shown as soon as the tooltip is placed, and kept while it fades out. Not from the tooltip's
    // `visible` (an item of a hidden window never counts as visible) and not from its opacity alone: the
    // fade is driven by the window it is in, so in a hidden popup it never starts.
    visible: placed || tip.opacity > 0
    // Only looked at; the pointer goes through to whatever is under it.
    mask: Region {}

    // Placed by the popup, not by itself: `Tooltip` finds its place with `mapToItem`, which is not
    // re-read when the popup's window takes its size, and stayed partly above the window (cut off).
    Tooltip {
        id: tip

        x: root.shadowRoom
        y: root.shadowRoom
        target: root.target
        shown: root.shown && root.target !== null
        text: root.text
        onWaitedChanged: {
            if (waited && root.target !== null && root.text !== '') {
                const place = root.target.mapToItem(null, root.target.width / 2, 0)
                root.centerX = place.x
                root.topY = root.overTarget ? place.y : 0
                root.placed = true
                return
            }

            root.placed = false
        }
    }
}
