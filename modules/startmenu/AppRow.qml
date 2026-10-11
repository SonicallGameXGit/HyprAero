import QtQuick
import qs.design
import qs.services
import '../../services/startMenu.js' as StartMenuList

// One app in the start menu: icon, name and under it what the app is (its description, or the program it
// runs), lit like a list row while it is the current one, and the star that features it at the right end
// (always shown on featured apps, on the lit row otherwise).
Item {
    id: root

    required property var app
    property bool big: false
    property bool lit: false
    property bool featured: false
    // The menu's shared tooltip.
    property Tooltip tooltip: null

    signal launched()
    signal pointed()
    signal featureToggled()
    signal menuRequested(point at)

    readonly property string iconPath: AppIcons.forName(app.icon)
    readonly property int iconSize: big ? 32 : 24
    readonly property string detail: StartMenuList.appDetail(app)

    implicitHeight: big ? 50 : 42
    Accessible.role: Accessible.Button
    Accessible.name: app.name

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
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
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
