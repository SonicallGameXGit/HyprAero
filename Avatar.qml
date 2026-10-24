import QtQuick
import 'avatar.js' as AvatarText

// A person without a picture: their initial on a colour chosen by their name (avatar-1..6), under the
// avatar glass.
Item {
    id: root

    property string name: ''
    property int radius: Theme.radiusControl

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.avatarColors[AvatarText.avatarIndex(root.name, Theme.avatarColors.length)]
    }

    Text {
        anchors.centerIn: parent
        text: AvatarText.initial(root.name)
        color: Theme.avatarText
        font.family: Theme.fontUi
        font.pixelSize: root.height * 0.5
        font.bold: true
    }

    // The shade along the bottom and the white inner ring.
    Rectangle {
        anchors.fill: parent
        radius: root.radius

        gradient: Gradient {
            GradientStop { position: 0.7; color: 'transparent' }
            GradientStop { position: 1.0; color: Theme.avatarGlassShade }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: 'transparent'
        border.width: 1
        border.color: Theme.avatarGlassRing
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius

        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.avatarShineTop }
            GradientStop { position: 0.49; color: Theme.avatarShineMiddle }
            GradientStop { position: 0.5; color: 'transparent' }
            GradientStop { position: 1.0; color: 'transparent' }
        }
    }
}
