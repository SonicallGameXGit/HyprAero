pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

// A context menu drawn inside a window: a white panel (menu-*) with rows that light up like list rows.
// `items` is a list of `{ text, enabled }`, or `{ separator: true }`. Place it in an item that covers
// the window: a press anywhere outside the panel closes it.
Item {
    id: root

    property var items: []
    property bool open: false
    // Where the panel goes in the parent: its top-left corner, or with `above` its bottom-right corner.
    // It is kept inside the parent.
    property point at: Qt.point(0, 0)
    property bool above: false
    // The row the keyboard is on (-1: none).
    property int current: -1

    signal chosen(int index)

    function close(): void {
        open = false
        current = -1
    }

    function step(direction: int): void {
        let index = current
        for (let tries = 0; tries < items.length; tries++) {
            index = (index + direction + items.length) % items.length
            const item = items[index]
            if (item.separator !== true && item.enabled !== false) {
                current = index
                return
            }
        }
    }

    function choose(index: int): void {
        const item = items[index]
        if (item === undefined || item.separator === true || item.enabled === false) {
            return
        }

        close()
        chosen(index)
    }

    visible: open
    z: 50

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: root.close()
    }

    Item {
        id: panel

        x: Math.max(0, Math.min(root.above ? root.at.x - width : root.at.x, root.width - width))
        y: Math.max(0, Math.min(root.above ? root.at.y - height : root.at.y, root.height - height))
        width: Math.max(160, column.implicitWidth + 4)
        height: column.implicitHeight + 4

        RectangularShadow {
            anchors.fill: parent
            offset.y: Theme.menuShadowOffset
            blur: Theme.menuShadowBlur
            color: Theme.menuShadowColor
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.menuBackground
            border.width: 1
            border.color: Theme.menuBorder
        }

        Column {
            id: column

            x: 2
            y: 2
            width: parent.width - 4

            Repeater {
                model: root.items

                Item {
                    id: row

                    required property var modelData
                    required property int index

                    readonly property bool separator: modelData.separator === true
                    readonly property bool enabled: separator === false && modelData.enabled !== false
                    readonly property bool lit: enabled && root.current === index

                    width: column.width
                    implicitWidth: separator ? 0 : label.implicitWidth + Theme.space5 * 2
                    height: separator ? Theme.space2 : 24

                    Rectangle {
                        visible: row.separator
                        anchors.verticalCenter: parent.verticalCenter
                        x: Theme.space1
                        width: parent.width - Theme.space1 * 2
                        height: 1
                        color: Theme.rowSeparator
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusControl
                        visible: row.lit
                        border.width: 1
                        border.color: Theme.rowHoverBorder

                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.rowHoverFace[0] }
                            GradientStop { position: 1.0; color: Theme.rowHoverFace[1] }
                        }
                    }

                    Text {
                        id: label

                        visible: row.separator === false
                        anchors.verticalCenter: parent.verticalCenter
                        x: Theme.space5
                        text: row.separator ? '' : row.modelData.text
                        color: row.enabled ? Theme.text : Theme.textMuted
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fontSizeBody
                    }

                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered && row.enabled) {
                                root.current = row.index
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.choose(row.index)
                    }
                }
            }
        }
    }
}
