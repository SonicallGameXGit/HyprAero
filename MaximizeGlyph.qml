import QtQuick

// The flat "maximize" box of a window's caption, or with `restore` the two stacked boxes of "restore down",
// drawn as on Windows: thin sides and a thicker top edge, the title bar. A structural glyph like `CloseGlyph`.
Item {
    id: root

    property int size: 8
    property bool restore: false
    property int thickness: 1
    property int topThickness: 2
    property color color: Theme.controlText

    // How far the back box of "restore" sits up and to the right of the front one.
    readonly property int offset: Math.round(size / 4)
    readonly property int boxSize: restore ? size - offset : size

    implicitWidth: size
    implicitHeight: size

    // The back box of "restore": only the parts the front box does not cover.
    Rectangle {
        x: root.offset
        width: root.boxSize
        height: root.topThickness
        visible: root.restore
        color: root.color
    }

    Rectangle {
        x: root.size - root.thickness
        width: root.thickness
        height: root.boxSize
        visible: root.restore
        color: root.color
    }

    Rectangle {
        x: root.boxSize
        y: root.boxSize - root.thickness
        width: root.offset
        height: root.thickness
        visible: root.restore
        color: root.color
    }

    // The front box, the only one of "maximize".
    Rectangle {
        y: root.restore ? root.offset : 0
        width: root.boxSize
        height: root.boxSize
        color: 'transparent'
        border.width: root.thickness
        border.color: root.color

        Rectangle {
            width: parent.width
            height: root.topThickness
            color: root.color
        }
    }
}
