import QtQuick

// The "empty" marker: a small glossy blue bead, drawn from the icon-blue material.
Item {
    id: root

    property int diameter: 8

    implicitWidth: diameter
    implicitHeight: diameter

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        border.width: 1
        border.color: Theme.iconBlueEdge

        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.iconBlueLight }
            GradientStop { position: 1.0; color: Theme.iconBlueDark }
        }
    }

    Rectangle {
        x: root.diameter * 0.2
        y: 1
        width: root.diameter * 0.6
        height: root.diameter * 0.4
        radius: height / 2

        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.iconGlossTop }
            GradientStop { position: 1.0; color: Theme.iconGlossBottom }
        }
    }
}
