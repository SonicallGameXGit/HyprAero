import QtQuick

// The taskbar strip's glass (.aero/STYLE.md, "Taskbar glass"), Windows 7's taskbar: a see-through tint,
// a dark line along the top with a light one under it, and a faint sheen; no line along the bottom or
// the ends, so the strip reads as running on past the screen's edges. Compositor blur comes from
// Hyprland's layer rules.
Rectangle {
    id: root

    color: Theme.taskbarBarTint

    Rectangle {
        anchors.fill: parent

        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.taskbarBarShineTop }
            GradientStop { position: 0.5; color: 'transparent' }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.taskbarBarEdge
    }

    Rectangle {
        y: 1
        width: parent.width
        height: 1
        color: Theme.taskbarGlassBorderInner
    }
}
