pragma ComponentBehavior: Bound

import QtQuick
import qs.design
import qs.services
import '../../services/startMenu.js' as StartMenuList

// One app in the start menu: icon, name and under it what the app is (its description, or the program it
// runs), lit like a list row while it is the current one; at the right end the star that features it
// (always shown on featured apps, on the lit row otherwise) and, for an app with actions of its own, the
// arrow button joined to the row that shows them, as Windows 7's split rows: the actions open in the menu's
// right column (`ActionsPane`), and while the arrow is pointed at or they are open the row is lit deeper blue.
// Dragged, the app goes to a workspace to start there.
Item {
    id: root

    required property var app
    property bool big: false
    property bool lit: false
    // Its actions are open in the right column.
    property bool actionsShown: false
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
    readonly property bool takenOut: BarDrag.from === 'startMenu' && BarDrag.appId === app.id

    signal launched()
    signal pointed()
    // The pointer came onto the row or left it, and onto its arrow or off it.
    signal rowHovered(bool hovered)
    signal arrowHovered(bool hovered)
    signal featureToggled()
    signal expandToggled()
    signal menuRequested(point at)

    readonly property string iconPath: IconOverrides.appIcon(app.id, app.icon)
    readonly property int iconSize: big ? 32 : 24
    readonly property string detail: StartMenuList.appDetail(app)
    readonly property bool hasActions: app.actions.length > 0
    // Lit deeper blue, as Windows 7 lights a row whose arrow is pointed at or whose actions are open.
    readonly property bool deep: actionsShown || (hasActions && arrowHover.hovered)

    implicitHeight: head.height
    Accessible.role: Accessible.Button
    Accessible.name: app.name

    // Shows or hides the menu's tooltip for one of the small controls at the right end.
    function tip(control: Item, text: string, hovered: bool): void {
        if (tooltip === null) {
            return
        }

        if (hovered) {
            tooltip.target = control
            tooltip.text = text
        }

        tooltip.shown = hovered
    }

    // The app itself; only this part is dragged.
    Item {
        id: head

        width: parent.width
        height: root.big ? 50 : 42
        opacity: root.takenOut ? 0 : 1

        DragSource {
            id: dragSource

            appId: root.app.id
            from: 'startMenu'
            screen: root.screen
            windowOffset: root.windowOffset
            returnArea: root.returnArea
            holdToDrag: root.holdToDrag
        }

        // Lit like a list row, deeper blue over it (row-selected-*).
        Rectangle {
            id: highlight

            anchors.fill: parent
            anchors.leftMargin: Theme.space1
            anchors.rightMargin: Theme.space1
            anchors.topMargin: 1
            anchors.bottomMargin: 1
            opacity: root.lit || root.deep ? 1 : 0
            radius: Theme.radiusControl
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

        Rectangle {
            anchors.fill: highlight
            opacity: root.deep ? 1 : 0
            radius: Theme.radiusControl
            border.width: 1
            border.color: Theme.rowSelectedBorder

            Behavior on opacity {
                NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
            }

            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.rowSelectedFace[0] }
                GradientStop { position: 1.0; color: Theme.rowSelectedFace[1] }
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

                root.rowHovered(hovered)
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
                    root.menuRequested(mapToItem(root, mouse.x, mouse.y))
                    return
                }

                root.launched()
            }
        }

        // The star keeps its place whether or not the app has actions, so the stars line up.
        Item {
            id: star

            anchors.right: arrow.left
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

                onHoveredChanged: root.tip(star, star.Accessible.name, starHover.hovered)
            }

            // The row moves to the other section, so its tooltip goes away at once.
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.tip(star, '', false)
                    root.featureToggled()
                }
            }
        }

        // The arrow's half of the split row: a line parts it from the app while the row is lit.
        Item {
            id: arrow

            anchors.right: parent.right
            anchors.rightMargin: Theme.space1
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 1
            anchors.bottomMargin: 1
            width: 26
            visible: root.hasActions
            Accessible.role: Accessible.Button
            Accessible.name: root.actionsShown ? qsTr('Hide actions') : qsTr('Show actions')
            Accessible.onPressAction: root.expandToggled()

            Rectangle {
                width: 1
                height: parent.height
                color: root.deep ? Theme.rowSelectedBorder : Theme.rowHoverBorder
                opacity: root.lit || root.deep ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
                }
            }

            ChevronGlyph {
                anchors.centerIn: parent
                size: 10
                color: root.lit || root.deep ? Theme.text : Theme.textMuted
            }

            HoverHandler {
                id: arrowHover

                onHoveredChanged: root.arrowHovered(arrowHover.hovered)
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.expandToggled()
            }
        }
    }
}
