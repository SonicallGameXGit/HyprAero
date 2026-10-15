pragma ComponentBehavior: Bound

import QtQuick

// A horizontal separator as Windows 7 draws them in the start menu: a dark line with a light one under it,
// both fading out towards the ends. `light` may be transparent for a single line (on a white pane).
Item {
    id: root

    property color dark: Theme.surfaceBorder
    property color light: 'transparent'
    // How much of the width each end takes to fade in.
    readonly property real fade: 0.2

    implicitHeight: 2

    Repeater {
        model: [root.dark, root.light]

        Rectangle {
            id: line

            required property color modelData
            required property int index

            y: index
            width: root.width
            height: 1

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop { position: 0.0; color: Qt.alpha(line.modelData, 0) }
                GradientStop { position: root.fade; color: line.modelData }
                GradientStop { position: 1 - root.fade; color: line.modelData }
                GradientStop { position: 1.0; color: Qt.alpha(line.modelData, 0) }
            }
        }
    }
}
