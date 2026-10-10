import QtQuick

// Stand-in for an app whose icon cannot be found: a small paper window with a blue title strip.
Item {
    Rectangle {
        anchors.fill: parent
        anchors.margins: parent.width * 0.1
        radius: Theme.radiusControl
        border.width: 1
        border.color: Theme.iconPaperEdge

        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.iconPaperLight }
            GradientStop { position: 1.0; color: Theme.iconPaperDark }
        }

        Rectangle {
            x: 1
            y: 1
            width: parent.width - 2
            height: parent.height * 0.28
            radius: Math.max(Theme.radiusControl - 1, 0)

            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.iconBlueLight }
                GradientStop { position: 1.0; color: Theme.iconBlueDark }
            }
        }
    }
}
