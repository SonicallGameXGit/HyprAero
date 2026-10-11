pragma ComponentBehavior: Bound

import QtQuick
import qs.design
import qs.services
import '../../services/startMenu.js' as StartMenuList

// One app in the start menu: icon, name and under it what the app is (its description, or the program it
// runs), lit like a list row while it is the current one; at the right end the star that features it
// (always shown on featured apps, on the lit row otherwise) and, for an app with actions of its own, the
// arrow that opens them. Open, the actions hang under the app on a tree line from its icon, lined up with
// its name, so they read as part of the app and not as apps of their own. Dragged, the app goes to a
// workspace to start there.
Item {
    id: root

    required property var app
    property bool big: false
    property bool lit: false
    // Of a lit row: -1 when the app itself is current, else the index of the current action.
    property int litAction: -1
    property bool expanded: false
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

    // `actionIndex` is -1 for the app itself.
    signal launched(int actionIndex)
    signal pointed(int actionIndex)
    signal featureToggled()
    signal expandToggled()
    signal menuRequested(point at)

    readonly property string iconPath: AppIcons.forName(app.icon)
    readonly property int iconSize: big ? 32 : 24
    readonly property string detail: StartMenuList.appDetail(app)
    readonly property bool hasActions: app.actions.length > 0
    readonly property int actionHeight: 26
    // Where the tree line runs (under the middle of the icon) and where the action names start (under the
    // app's name).
    readonly property real lineX: icon.x + iconSize / 2
    readonly property real textX: icon.x + iconSize + Theme.space2

    implicitHeight: head.height + branch.height
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

        // Lit like a list row.
        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: Theme.space1
            anchors.rightMargin: Theme.space1
            anchors.topMargin: 1
            anchors.bottomMargin: 1
            opacity: root.lit && root.litAction === -1 ? 1 : 0
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

        // The start of the tree line, from under the icon down to the actions.
        Rectangle {
            x: root.lineX
            y: icon.y + icon.height + 2
            width: 1
            height: head.height - y
            color: Theme.surfaceBorder
            visible: root.expanded
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
                    root.pointed(-1)
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
                    root.menuRequested(mapToItem(root, mouse.x, mouse.y))
                    return
                }

                root.launched(-1)
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

        // Points right while closed and down while open, like a tree branch.
        Item {
            id: arrow

            anchors.right: parent.right
            anchors.rightMargin: Theme.space2
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24
            visible: root.hasActions
            Accessible.role: Accessible.Button
            Accessible.name: root.expanded ? qsTr('Hide actions') : qsTr('Show actions')
            Accessible.onPressAction: root.expandToggled()

            ChevronGlyph {
                anchors.centerIn: parent
                size: 10
                color: arrowHover.hovered ? Theme.text : Theme.textMuted
                rotation: root.expanded ? 90 : 0

                Behavior on rotation {
                    NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
                }
            }

            HoverHandler {
                id: arrowHover

                onHoveredChanged: root.tip(arrow, arrow.Accessible.name, arrowHover.hovered)
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.expandToggled()
            }
        }
    }

    // The actions, sliding open under the app.
    Item {
        id: branch

        y: head.height
        width: parent.width
        height: root.expanded ? actions.height : 0
        clip: true

        Behavior on height {
            NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
        }

        // Shut, they are hidden too: clipping does not keep the pointer away from them.
        Column {
            id: actions

            width: parent.width
            visible: branch.height > 0

            Repeater {
                model: root.app.actions

                Item {
                    id: action

                    required property string modelData
                    required property int index

                    readonly property bool last: index === root.app.actions.length - 1

                    width: actions.width
                    height: root.actionHeight

                    // Down from the app, and a short branch to the name; the last one ends there.
                    Rectangle {
                        x: root.lineX
                        width: 1
                        height: action.last ? action.height / 2 : action.height
                        color: Theme.surfaceBorder
                    }

                    Rectangle {
                        x: root.lineX
                        y: action.height / 2
                        width: root.textX - Theme.space2 - x
                        height: 1
                        color: Theme.surfaceBorder
                    }

                    // Lit like the app, from where the name starts.
                    Rectangle {
                        x: root.textX - Theme.space2 + Theme.space1
                        y: 1
                        width: parent.width - x - Theme.space1
                        height: parent.height - 2
                        opacity: root.lit && root.litAction === action.index ? 1 : 0
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

                    Text {
                        x: root.textX
                        width: parent.width - x - Theme.space2
                        anchors.verticalCenter: parent.verticalCenter
                        text: action.modelData
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fontSizeBody
                    }

                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered) {
                                root.pointed(action.index)
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.launched(action.index)
                    }
                }
            }
        }
    }
}
