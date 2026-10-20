pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

// A context menu drawn inside a window: a white panel (menu-*) with rows that light up like list rows, and
// Windows 7's icon margin down its left side, closed by an etched line (menu-gutter-*).
// `items` is a list of `{ text, enabled, bold, indent, check, checked, icon, submenu }` (only `text` is
// needed), or `{ separator: true }`; other fields are kept for the owner. `bold` marks what a click on the
// thing itself does, as in Windows 7; `indent` rows hang under the row above on a tree line, as the actions
// of an app. In the margin left of the text a row shows its `icon` (an image source), or a tick when
// `checked` (`check`: 'box' a check mark, 'radio' a dot). A `submenu` row has an arrow at its end and
// choosing it asks for its submenu (`submenuRequested`) instead of closing. Place it in an item that covers
// the window: a press anywhere outside the panel closes it.
Item {
    id: root

    property var items: []
    property bool open: false
    // Where the panel goes in the parent: its top-left corner, or with `above` its bottom-right corner.
    // It is kept inside the parent.
    property point at: Qt.point(0, 0)
    property bool above: false
    // Still drawn after it was closed, while its owner fades it out.
    property bool keepShown: false
    // The row the keyboard is on (-1: none).
    property int current: -1
    // The panel's size, for a window made to fit around it.
    readonly property alias panelWidth: panel.width
    readonly property alias panelHeight: panel.height
    // The margin left of the text that holds icons and ticks, and where the text starts after its line.
    readonly property int gutterWidth: Theme.space5 + Theme.space1
    readonly property int textStart: gutterWidth + 2 + Theme.space1

    signal chosen(int index)
    signal submenuRequested(int index)

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

        if (item.submenu === true) {
            current = index
            submenuRequested(index)
            return
        }

        close()
        chosen(index)
    }

    // A row's place in this item, for a submenu opening beside it.
    function rowRect(index: int): rect {
        const row = rows.itemAt(index)
        if (row === null) {
            return Qt.rect(0, 0, 0, 0)
        }

        const place = row.mapToItem(root, 0, 0)
        return Qt.rect(place.x, place.y, row.width, row.height)
    }

    visible: open || keepShown
    z: 50

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: root.close()
    }

    Item {
        id: panel

        readonly property real widestRow: {
            let widest = 0
            for (let index = 0; index < rows.count; index++) {
                const row = rows.itemAt(index)
                if (row !== null) {
                    widest = Math.max(widest, row.implicitWidth)
                }
            }

            return widest
        }

        x: Math.max(0, Math.min(root.above ? root.at.x - width : root.at.x, root.width - width))
        y: Math.max(0, Math.min(root.above ? root.at.y - height : root.at.y, root.height - height))
        // From the rows' own widths: the column only knows the width it gives them, the panel's.
        width: Math.max(160, widestRow + 4)
        height: column.implicitHeight + 4

        RectangularShadow {
            anchors.fill: parent
            offset.x: Theme.menuShadowOffset
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

        // The etched line closing the icon margin, from top to bottom; a lit row covers it.
        Rectangle {
            x: 2 + root.gutterWidth
            y: 2
            width: 1
            height: column.implicitHeight
            color: Theme.menuGutterLine
        }

        Rectangle {
            x: 3 + root.gutterWidth
            y: 2
            width: 1
            height: column.implicitHeight
            color: Theme.menuGutterLight
        }

        Column {
            id: column

            x: 2
            y: 2
            width: parent.width - 4

            Repeater {
                id: rows

                model: root.items

                Item {
                    id: row

                    required property var modelData
                    required property int index

                    readonly property bool separator: modelData.separator === true
                    readonly property bool enabled: separator === false && modelData.enabled !== false
                    readonly property bool lit: enabled && root.current === index
                    readonly property bool indent: modelData.indent === true
                    // The tree line goes on down to the next row when that one hangs under the same row.
                    readonly property bool lastIndent: {
                        const next = root.items[index + 1]
                        return next === undefined || next.indent !== true
                    }
                    readonly property int textX: indent ? root.textStart + Theme.space3 : root.textStart
                    readonly property bool submenu: modelData.submenu === true
                    readonly property string icon: typeof modelData.icon === 'string' ? modelData.icon : ''

                    width: column.width
                    implicitWidth: separator ? 0 : label.implicitWidth + textX + Theme.space5 + (submenu ? Theme.space3 : 0)
                    height: separator ? Theme.space2 : 24

                    // Etched like the margin's line, starting after it.
                    Rectangle {
                        visible: row.separator
                        y: row.height / 2 - 1
                        x: root.gutterWidth + 2
                        width: parent.width - x - Theme.space1
                        height: 1
                        color: Theme.menuGutterLine
                    }

                    Rectangle {
                        visible: row.separator
                        y: row.height / 2
                        x: root.gutterWidth + 2
                        width: parent.width - x - Theme.space1
                        height: 1
                        color: Theme.menuGutterLight
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

                    // The tree line: down from the row above, and a short branch to the text.
                    Rectangle {
                        visible: row.indent
                        x: root.textStart + 2
                        width: 1
                        height: row.lastIndent ? row.height / 2 : row.height
                        color: Theme.surfaceBorder
                    }

                    Rectangle {
                        visible: row.indent
                        x: root.textStart + 2
                        y: row.height / 2
                        width: row.textX - x - Theme.space1
                        height: 1
                        color: Theme.surfaceBorder
                    }

                    // The margin left of the text: the row's icon, or its tick.
                    Image {
                        visible: row.icon !== '' && row.separator === false
                        x: (root.gutterWidth - width) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        sourceSize: Qt.size(32, 32)
                        source: row.icon
                        smooth: true
                        mipmap: true
                    }

                    CheckGlyph {
                        visible: row.icon === '' && row.modelData.check === 'box' && row.modelData.checked === true
                        x: (root.gutterWidth - width) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: row.enabled ? Theme.text : Theme.textMuted
                    }

                    Rectangle {
                        visible: row.icon === '' && row.modelData.check === 'radio' && row.modelData.checked === true
                        x: (root.gutterWidth - width) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6
                        height: 6
                        radius: 3
                        color: row.enabled ? Theme.text : Theme.textMuted
                    }

                    ChevronGlyph {
                        visible: row.submenu
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space2
                        anchors.verticalCenter: parent.verticalCenter
                        color: row.enabled ? Theme.text : Theme.textMuted
                    }

                    Text {
                        id: label

                        visible: row.separator === false
                        anchors.verticalCenter: parent.verticalCenter
                        x: row.textX
                        text: row.separator ? '' : row.modelData.text
                        color: row.enabled ? Theme.text : Theme.textMuted
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fontSizeBody
                        font.bold: row.modelData.bold === true
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
