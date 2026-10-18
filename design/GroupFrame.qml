import QtQuick

// A group inside a window, as Windows 7 draws it (.aero/STYLE.md "Group boxes"): a rounded frame 2px wide
// whose top edge runs through the group's name, which sits on the window's surface along the top left. With
// `accelerator` the name's first letter is underlined, as Windows marks the key that jumps to a group's
// first control. What goes in the group is placed in the frame's own coordinates, the frame's corner at 0, 0.
Item {
    id: root

    property string title: ''
    property bool accelerator: false

    default property alias content: body.data

    // The name, with its first letter underlined when it is the accelerator (StyledText markup; the words are
    // escaped, they are plain text).
    readonly property string markup: {
        const escaped = title.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        return accelerator && escaped !== '' ? '<u>' + escaped.charAt(0) + '</u>' + escaped.slice(1) : escaped
    }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: heading.height / 2
        color: 'transparent'
        radius: Theme.radiusControl
        border.width: 2
        border.color: Theme.groupBorder
    }

    Item {
        id: body

        anchors.fill: parent
    }

    // The name breaks the frame's top edge: its own background covers the line behind it.
    Rectangle {
        x: Theme.space2
        width: heading.width + 4
        height: heading.height
        color: Theme.surface
        visible: root.title !== ''

        Text {
            id: heading

            x: 2
            textFormat: Text.StyledText
            text: root.markup
            color: Theme.text
            font.family: Theme.fontUi
            font.pixelSize: Theme.fontSizeBody
        }
    }
}
