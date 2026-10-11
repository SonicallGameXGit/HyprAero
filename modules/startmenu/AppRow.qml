import QtQuick
import qs.design
import qs.services
import '../../services/startMenu.js' as StartMenuList

// One app in the start menu: icon, name and under it what the app is (its description, or the program it
// runs), lit like a list row while it is the current one, and the star that features it at the right end
// (always shown on featured apps, on the lit row otherwise). Dragged, it takes the app to a workspace to
// start it there.
Item {
    id: root

    required property var app
    property bool big: false
    property bool lit: false
    property bool featured: false
    // The menu's shared tooltip.
    property Tooltip tooltip: null
    // The bar's screen and the menu window's place in the bar, for the ghost a drag leaves behind, and
    // where a drop puts the app back.
    property var screen: null
    property point windowOffset: Qt.point(0, 0)
    property Item returnArea: null
    // Picked up by holding it (touch controls) instead of by moving.
    property bool holdToDrag: false
    readonly property int holdDelay: 400
    // Out of the menu in a drag: its place stays empty (the ghost is drawn there), so nothing moves.
    readonly property bool takenOut: BarDrag.appId === app.id

    signal launched()
    signal pointed()
    signal featureToggled()
    signal menuRequested(point at)

    readonly property string iconPath: AppIcons.forName(app.icon)
    readonly property int iconSize: big ? 32 : 24
    readonly property string detail: StartMenuList.appDetail(app)

    implicitHeight: big ? 50 : 42
    opacity: takenOut ? 0 : 1
    Accessible.role: Accessible.Button
    Accessible.name: app.name

    DragSource {
        id: dragSource

        appId: root.app.id
        screen: root.screen
        windowOffset: root.windowOffset
        returnArea: root.returnArea
        holdToDrag: root.holdToDrag
    }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Theme.space1
        anchors.rightMargin: Theme.space1
        anchors.topMargin: 1
        anchors.bottomMargin: 1
        radius: Theme.radiusControl
        opacity: root.lit ? 1 : 0
        border.width: 1
        border.color: Theme.rowHoverBorder

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
        }

        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.rowHoverFace[0] }
            GradientStop { position: 1.0; color: Theme.rowHoverFace[1] }
        }
    }

    AppIconImage {
        id: icon

        x: Theme.space3
        anchors.verticalCenter: parent.verticalCenter
        width: root.iconSize
        height: root.iconSize
        visible: root.iconPath !== ''
        source: root.iconPath
    }

    GenericAppIcon {
        anchors.fill: icon
        visible: root.iconPath === ''
    }

    Column {
        anchors.left: icon.right
        anchors.right: star.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.space2
        anchors.rightMargin: Theme.space1

        Text {
            width: parent.width
            text: root.app.name
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.fontUi
            font.pixelSize: Theme.fontSizeBody
        }

        Text {
            width: parent.width
            visible: root.detail !== ''
            text: root.detail
            elide: Text.ElideRight
            color: Theme.textMuted
            font.family: Theme.fontUi
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                root.pointed()
            }
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        pressAndHoldInterval: root.holdDelay
        // Not accepted, a long press still ends in a click.
        onPressAndHold: mouse => {
            if (root.holdToDrag === false || mouse.button !== Qt.LeftButton) {
                mouse.accepted = false
                return
            }

            dragSource.start(Qt.point(mouse.x, mouse.y), () => mouseArea.pressed)
        }
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.menuRequested(Qt.point(mouse.x, mouse.y))
                return
            }

            root.launched()
        }
    }

    Item {
        id: star

        anchors.right: parent.right
        anchors.rightMargin: Theme.space2
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 24
        visible: root.featured || root.lit
        Accessible.role: Accessible.CheckBox
        Accessible.name: root.featured ? qsTr('Remove from Featured') : qsTr('Add to Featured')
        Accessible.checked: root.featured
        Accessible.onPressAction: root.featureToggled()

        StarGlyph {
            anchors.centerIn: parent
            size: 16
            on: root.featured || starHover.hovered
        }

        HoverHandler {
            id: starHover

            onHoveredChanged: {
                if (root.tooltip === null) {
                    return
                }

                if (hovered) {
                    root.tooltip.target = star
                    root.tooltip.text = star.Accessible.name
                }

                root.tooltip.shown = hovered
            }
        }

        // The row moves to the other section, so its tooltip goes away at once.
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.tooltip !== null) {
                    root.tooltip.shown = false
                }

                root.featureToggled()
            }
        }
    }
}
