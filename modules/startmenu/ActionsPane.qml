pragma ComponentBehavior: Bound

import QtQuick
import qs.design

// The actions of an app, shown in the start menu's right column in place of the places while they are open,
// as Windows 7 shows an app's jump list there: a white pane edged like the left one, each action lit like a
// list row under the pointer or the keyboard.
Item {
    id: root

    // The app whose actions are shown (null: none; the last one stays while the pane fades out).
    property var app: null
    property bool shown: false
    // The action the keyboard or the pointer is on (-1: none).
    property int current: -1
    readonly property bool hovered: hoverHandler.hovered
    readonly property int rowHeight: 26

    signal pointed(int index)
    signal launched(int index)

    opacity: shown ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
    }

    // The pane's etched edge, as the left pane's: a light line around its dark border.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        radius: Theme.radiusControl + 1
        color: 'transparent'
        border.width: 1
        border.color: Theme.taskbarGlassBorderInner
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusControl
        color: Theme.surface
        border.width: 1
        border.color: Theme.taskbarGlassBorderOuter
    }

    Column {
        x: 1
        y: Theme.space1
        width: parent.width - 2

        Repeater {
            model: root.app === null ? [] : root.app.actions

            Item {
                id: action

                required property string modelData
                required property int index

                width: parent.width
                height: root.rowHeight
                Accessible.role: Accessible.Button
                Accessible.name: modelData
                Accessible.onPressAction: root.launched(index)

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space1
                    anchors.rightMargin: Theme.space1
                    anchors.topMargin: 1
                    anchors.bottomMargin: 1
                    opacity: root.current === action.index ? 1 : 0
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
                    x: Theme.space3
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

    HoverHandler {
        id: hoverHandler
    }
}
