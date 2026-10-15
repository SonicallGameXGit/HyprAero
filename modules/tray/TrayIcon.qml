import Quickshell.Widgets
import QtQuick
import qs.design
import qs.services

// One app's icon in the notification area, on the bar or in the flyout: a tool button with the app's
// 16px icon, lit as glass, as on Windows 7. A click does what the app says (most open their window), a right click asks
// for the app's menu, a middle click and the wheel go to the app too. An app that only has a menu opens it
// on a click as well. A drag takes it along the bar's icons, into the flyout or out of it.
ControlButton {
    id: root

    required property var item
    // The bar's screen, what it is in ('tray': the bar, 'trayFlyout': the flyout) and where its window's
    // top-left is in the bar's coordinates, for the ghost a drag leaves behind.
    property var screen: null
    property string from: 'tray'
    property point windowOffset: Qt.point(0, 0)

    readonly property string key: item === null ? '' : Tray.keyOf(item)
    readonly property string tooltipText: item === null ? '' : Tray.tooltipOf(item)
    readonly property int iconSize: 16
    // Out on a drag: its place stays empty (the ghost is drawn there), so nothing moves under the pointer.
    readonly property bool takenOut: BarDrag.from === from && BarDrag.trayKey === key && BarDrag.originScreen === screen

    // `at` is in this button.
    signal menuRequested(point at)
    // The app was asked to do something (a click or a middle click).
    signal activated()

    kind: 'glassTool'
    opacity: takenOut ? 0 : 1
    Accessible.name: tooltipText
    onClicked: {
        if (item === null) {
            return
        }

        if (item.onlyMenu) {
            menuRequested(Qt.point(width / 2, height / 2))
            return
        }

        Tray.activate(item)
        activated()
    }

    DragSource {
        trayKey: root.key
        from: root.from
        screen: root.screen
        windowOffset: root.windowOffset
    }

    IconImage {
        id: picture

        anchors.centerIn: parent
        implicitSize: root.iconSize
        source: root.item === null ? '' : Tray.pictureOf(root.item.icon)
        visible: source !== '' && status === Image.Ready
    }

    // An app whose icon cannot be read still has a place to click.
    GenericAppIcon {
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        visible: picture.visible === false
    }

    // The button's own MouseArea takes only the left button, so other presses come down to here.
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: eventPoint => root.menuRequested(eventPoint.position)
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: {
            if (root.item !== null) {
                Tray.secondaryActivate(root.item)
                root.activated()
            }
        }
    }

    WheelHandler {
        onWheel: event => {
            if (root.item === null) {
                return
            }

            if (event.angleDelta.y !== 0) {
                Tray.scroll(root.item, event.angleDelta.y, false)
            }

            if (event.angleDelta.x !== 0) {
                Tray.scroll(root.item, event.angleDelta.x, true)
            }
        }
    }
}
