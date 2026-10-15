import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.design
import qs.services

// Covers the whole screen, bar included, only while a window, a workspace or a tray icon is dragged out of
// a bar, or an app out of its start menu. It draws the dragged card, button or row under the pointer, held at the point where it was grabbed, and takes
// the drop anywhere on the screen; the bar decides what a drop at the pointer means. Where the drag was
// taken from, a glass ghost stays; it lights up while a drop would put it back (the pointer on it, or
// anywhere on the start menu an app came from), and such a drop changes nothing.
//
// The picture is drawn here instead of as the compositor's drag icon because Hyprland 0.56 pins the icon's
// top-left corner to the pointer: Qt sends the grab point as a surface offset and Hyprland's attach
// overwrites it.
PanelWindow {
    id: root

    // A drag is over this screen, and where the pointer is, in this window's coordinates.
    readonly property bool hovered: dropArea.containsDrag
    property point pointer: Qt.point(0, 0)
    // `pointer` holds a trustworthy position of the current drag. The layer is mapped and resized while the
    // drag starts, and the first positions it reports come out wrong (or are the last drag's), so the
    // picture waits a moment (`settleTimer`) after the first one.
    property bool pointerKnown: false
    // The bar's height: the bar runs along this layer's bottom edge, so a place in bar coordinates is
    // that much above the layer's bottom.
    property int barHeight: 0
    // The drag started on this screen, and where (in this layer's coordinates).
    readonly property bool hasOrigin: BarDrag.active && BarDrag.originScreen === screen
    readonly property rect originRect: Qt.rect(
        BarDrag.originRect.x,
        BarDrag.originRect.y + height - barHeight,
        BarDrag.originRect.width,
        BarDrag.originRect.height,
    )
    // Where a drop puts it back: the ghost, or more around it (the whole start menu for an app).
    readonly property rect returnRect: Qt.rect(
        BarDrag.returnRect.x,
        BarDrag.returnRect.y + height - barHeight,
        BarDrag.returnRect.width,
        BarDrag.returnRect.height,
    )
    // The pointer is there: a drop now puts it back, as if it was never taken.
    readonly property bool puttingBack: hovered
        && hasOrigin
        && pointer.x >= returnRect.x
        && pointer.x <= returnRect.x + returnRect.width
        && pointer.y >= returnRect.y
        && pointer.y <= returnRect.y + returnRect.height

    // Something was dropped on this screen; what it is stays in `BarDrag`.
    signal dropped()

    WlrLayershell.namespace: 'hypraero-drop'
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: 'transparent'
    visible: BarDrag.active
    onVisibleChanged: {
        pointerKnown = false
        settleTimer.stop()
    }

    Timer {
        id: settleTimer

        interval: 80
        onTriggered: root.pointerKnown = true
    }

    DropArea {
        id: dropArea

        anchors.fill: parent
        keys: [
            Workspaces.windowDragFormat,
            Workspaces.workspaceDragFormat,
            Apps.appDragFormat,
            Tray.trayDragFormat,
        ]
        onEntered: drag => {
            root.pointer = Qt.point(drag.x, drag.y)
            settleTimer.restart()
        }
        onPositionChanged: drag => {
            root.pointer = Qt.point(drag.x, drag.y)
            if (root.pointerKnown === false && settleTimer.running === false) {
                settleTimer.start()
            }
        }
        onDropped: drop => {
            root.pointer = Qt.point(drop.x, drop.y)
            drop.acceptProposedAction()
            root.dropped()
        }
    }

    // The ghost: a glass slot where it was taken from, lit while a drop would put it back.
    DropZone {
        x: root.originRect.x
        y: root.originRect.y
        width: root.originRect.width
        height: root.originRect.height
        visible: root.hasOrigin
        lit: root.puttingBack
        text: qsTr('Put back')
        Accessible.name: qsTr('Put back')
    }

    Image {
        x: root.pointer.x - BarDrag.hotSpot.x
        y: root.pointer.y - BarDrag.hotSpot.y
        width: BarDrag.pictureSize.width
        height: BarDrag.pictureSize.height
        source: BarDrag.picture === null ? '' : BarDrag.picture.url
        visible: root.hovered && root.pointerKnown
        opacity: Theme.dragImageOpacity
        smooth: true
    }

    // A drag never presses on this layer, so a press means it was left behind (a drag that ended without
    // telling): it goes at once instead of covering the screen.
    MouseArea {
        anchors.fill: parent
        onPressed: BarDrag.end()
    }
}
