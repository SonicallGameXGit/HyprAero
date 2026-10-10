import QtQuick

// Glass chrome: tint, outer and inner border, shine on the upper part.
// Real compositor blur is added by Hyprland layer rules (see README.md); this works without it.
Rectangle {
    id: root

    property int cornerRadius: 0

    radius: cornerRadius
    color: Theme.glassTint
    border.width: 1
    border.color: Theme.glassBorderOuter

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(root.cornerRadius - 1, 0)
        color: 'transparent'
        border.width: 1
        border.color: Theme.glassBorderInner
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(root.cornerRadius - 1, 0)

        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.glassShineTop }
            GradientStop { position: 0.42; color: Theme.glassShineMiddle }
            GradientStop { position: 0.43; color: 'transparent' }
            GradientStop { position: 1.0; color: 'transparent' }
        }
    }
}
