import QtQuick
import qs.design
import qs.services

// One pinned app on the bar: its icon on a tool button. Click starts it, right click asks for its menu, a
// drag takes it among the pins (to move it) or to a workspace (to start it there).
ControlButton {
    id: root

    required property var app
    // The bar's screen, for the ghost left behind while the pin is dragged.
    property var screen: null

    readonly property string iconPath: AppIcons.forName(app.icon)
    // What the bar's tooltip says over it.
    readonly property string tooltipText: app.name
    readonly property int iconSize: 24
    // Out on a drag: its place stays empty (the ghost is drawn there), so nothing moves under the pointer.
    // The same pin on the other screens' bars stays.
    readonly property bool takenOut: BarDrag.from === 'pins' && BarDrag.appId === app.id && BarDrag.originScreen === screen

    // `at` is in this button.
    signal menuRequested(point at)

    kind: 'tool'
    implicitWidth: 32
    implicitHeight: 40
    opacity: takenOut ? 0 : 1
    Accessible.name: app.name
    onClicked: Apps.launch(app.id, -1)

    DragSource {
        appId: root.app.id
        from: 'pins'
        screen: root.screen
    }

    GenericAppIcon {
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        visible: root.iconPath === ''
    }

    AppIconImage {
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        visible: root.iconPath !== ''
        source: root.iconPath
    }

    // The button's own MouseArea takes only the left button, so a right press comes down to here.
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: eventPoint => root.menuRequested(eventPoint.position)
    }
}
