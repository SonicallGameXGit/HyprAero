import QtQuick

// The battery as Windows 7's power flyout shows it: a steel battery standing up (icon-steel) filled with
// green (icon-green) as far as it is charged (`level` 0 to 1), gold when low and red when critical (the
// `badge` of the notification area's icon), the materials' gloss on its left half. Drawn in a 32 x 32 box.
Item {
    id: root

    property real level: 1
    property string badge: 'none'
    property real size: 32

    readonly property color fillLight: {
        if (badge === 'error') {
            return Theme.iconRedLight
        }

        return badge === 'warning' ? Theme.iconGoldLight : Theme.iconGreenLight
    }
    readonly property color fillDark: {
        if (badge === 'error') {
            return Theme.iconRedDark
        }

        return badge === 'warning' ? Theme.iconGoldDark : Theme.iconGreenDark
    }

    implicitWidth: size
    implicitHeight: size

    Item {
        width: 32
        height: 32
        scale: root.size / 32
        transformOrigin: Item.TopLeft

        Rectangle {
            x: 12
            y: 1
            width: 8
            height: 4
            radius: 1
            color: Theme.iconSteelDark
            border.width: 1
            border.color: Theme.iconSteelEdge
        }

        Rectangle {
            id: body

            x: 7
            y: 4
            width: 18
            height: 27
            radius: 2
            border.width: 1
            border.color: Theme.iconSteelEdge

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop { position: 0.0; color: Theme.iconSteelLight }
                GradientStop { position: 1.0; color: Theme.iconSteelDark }
            }

            Rectangle {
                x: 2
                width: parent.width - 4
                height: (parent.height - 4) * Math.min(1, Math.max(0, root.level))
                y: parent.height - 2 - height
                radius: 1

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop { position: 0.0; color: root.fillLight }
                    GradientStop { position: 1.0; color: root.fillDark }
                }
            }

            Rectangle {
                x: 1
                y: 1
                width: (parent.width - 2) / 2
                height: parent.height - 2
                radius: 1

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop { position: 0.0; color: Theme.iconGlossTop }
                    GradientStop { position: 1.0; color: Theme.iconGlossBottom }
                }
            }
        }
    }
}
