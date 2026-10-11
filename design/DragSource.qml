import QtQuick
import qs.services

// Makes its parent draggable out of the bar or the start menu: a window (`address`), a whole workspace
// (`workspaceId`) or an app to start (`appId`). It is a real Wayland drag, so it can be dropped anywhere on
// the screen (`modules/bar/DropLayer.qml`, another surface). Once the pointer has moved far enough
// `picture` is grabbed, and the drag starts when that is ready; the drop layer draws it, held where the
// pointer took it.
//
// With `holdToDrag` moving does not start a drag (the list around it scrolls instead); the owner calls
// `start` after a long press, as on a phone.
//
// It sits under its siblings (z -1): a DragHandler above a button's MouseArea swallows the click (a press
// and release without moving never reaches `clicked`), while one under it lets the click through and
// still takes the press over once the pointer moves far enough. The close button of a card, above
// everything, keeps its own presses too.
Item {
    id: root

    // What is dragged: set one of the three. Nothing set: no drag.
    property string address: ''
    property int workspaceId: 0
    property string appId: ''
    property Item picture: parent
    property bool holdToDrag: false
    // The screen of the bar it belongs to, and where its window's top-left is in that bar's coordinates
    // (0, 0 inside the bar itself), so the drop layer can leave a ghost where it was taken from.
    property var screen: null
    property point windowOffset: Qt.point(0, 0)
    // Where a drop counts as putting it back, when that is more than the ghost itself (the whole start
    // menu for an app); in the same window as the picture.
    property Item returnArea: null

    readonly property bool dragging: Drag.active
    readonly property bool hasSubject: address !== '' || workspaceId > 0 || appId !== ''

    z: -1
    anchors.fill: parent
    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.MoveAction
    Drag.mimeData: {
        if (address !== '') {
            return { [Workspaces.windowDragFormat]: address }
        }

        if (appId !== '') {
            return { [Apps.appDragFormat]: appId }
        }

        return { [Workspaces.workspaceDragFormat]: String(workspaceId) }
    }
    Drag.onActiveChanged: {
        if (Drag.active === false) {
            BarDrag.end()
        }
    }

    // A place of an item in the bar's coordinates.
    function barRect(item: Item): rect {
        const place = item.mapToItem(null, 0, 0)
        return Qt.rect(place.x + windowOffset.x, place.y + windowOffset.y, item.width, item.height)
    }

    // Grabs the picture and starts the drag, held at `pressPosition` (in this item). `held` says whether
    // the press is still going on when the picture is ready; let go before that, there is no drag.
    function start(pressPosition: point, held: var): void {
        if (hasSubject === false || Drag.active) {
            return
        }

        const hotSpot = mapToItem(picture, pressPosition)
        picture.grabToImage(result => {
            if (held() === false) {
                return
            }

            const origin = barRect(picture)
            BarDrag.begin(address, workspaceId, appId, result, Qt.size(picture.width, picture.height), hotSpot, screen, origin, returnArea === null ? origin : barRect(returnArea))
            root.Drag.active = true
        })
    }

    DragHandler {
        id: dragHandler

        target: null
        enabled: root.hasSubject && root.holdToDrag === false
        onActiveChanged: {
            if (active) {
                root.start(centroid.pressPosition, () => dragHandler.active)
            }
        }
    }
}
