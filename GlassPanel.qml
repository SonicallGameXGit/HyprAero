import QtQuick

// Glass chrome: tint, outer and inner border, shine on the upper part. kind: 'window' (a window's pale
// glass) or 'taskbar' (the shell's own chrome, Windows 7's darker taskbar glass).
// Real compositor blur is added by Hyprland layer rules (see README.md); this works without it.
Rectangle {
    id: root

    property int cornerRadius: 0
    property string kind: 'window'

    readonly property bool taskbar: kind === 'taskbar'

    radius: cornerRadius
    color: taskbar ? Theme.taskbarGlassTint : Theme.glassTint
    border.width: 1
    border.color: taskbar ? Theme.taskbarGlassBorderOuter : Theme.glassBorderOuter

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(root.cornerRadius - 1, 0)
        color: 'transparent'
        border.width: 1
        border.color: root.taskbar ? Theme.taskbarGlassBorderInner : Theme.glassBorderInner
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(root.cornerRadius - 1, 0)

        gradient: Gradient {
            GradientStop { position: 0.0; color: root.taskbar ? Theme.taskbarGlassShineTop : Theme.glassShineTop }
            GradientStop { position: 0.42; color: root.taskbar ? Theme.taskbarGlassShineMiddle : Theme.glassShineMiddle }
            GradientStop { position: 0.43; color: 'transparent' }
            GradientStop { position: 1.0; color: 'transparent' }
        }
    }
}
