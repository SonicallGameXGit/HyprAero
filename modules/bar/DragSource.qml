import QtQuick
import qs.services

// Makes its parent draggable out of the bar: a window (`address`) or a whole workspace (`workspaceId`).
// It is a real Wayland drag, so it can be dropped anywhere on the screen (`DropLayer`, another surface).
// Once the pointer has moved far enough `picture` is grabbed, and the drag starts when that is ready;
// the drop layer draws it, held where the pointer took it.
//
// It sits under its siblings (z -1): a DragHandler above a button's MouseArea swallows the click (a press
// and release without moving never reaches `clicked`), while one under it lets the click through and
// still takes the press over once the pointer moves far enough. The close button of a card, above
// everything, keeps its own presses too.
Item {
    id: root

    // What is dragged: set one of the two. Nothing set: no drag.
    property string address: ''
    property int workspaceId: 0
    property Item picture: parent
    // The screen of the bar it belongs to, and where its window's top-left is in that bar's coordinates
    // (0, 0 inside the bar itself), so the drop layer can leave a ghost where it was taken from.
    property var screen: null
    property point windowOffset: Qt.point(0, 0)

    readonly property bool dragging: Drag.active

    z: -1
    anchors.fill: parent
    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.MoveAction
    Drag.mimeData: address !== ''
        ? ({ [Workspaces.windowDragFormat]: address })
        : ({ [Workspaces.workspaceDragFormat]: String(workspaceId) })
    Drag.onActiveChanged: {
        if (Drag.active === false) {
            BarDrag.end()
        }
    }

    DragHandler {
        id: dragHandler

        target: null
        enabled: root.address !== '' || root.workspaceId > 0
        onActiveChanged: {
            if (active === false) {
                return
            }

            const hotSpot = root.mapToItem(root.picture, centroid.pressPosition)
            root.picture.grabToImage(result => {
                // Let go before the picture was ready: no drag.
                if (dragHandler.active === false) {
                    return
                }

                const place = root.picture.mapToItem(null, 0, 0)
                const origin = Qt.rect(
                    place.x + root.windowOffset.x,
                    place.y + root.windowOffset.y,
                    root.picture.width,
                    root.picture.height,
                )
                BarDrag.begin(root.address, root.workspaceId, result, Qt.size(root.picture.width, root.picture.height), hotSpot, root.screen, origin)
                root.Drag.active = true
            })
        }
    }
}
