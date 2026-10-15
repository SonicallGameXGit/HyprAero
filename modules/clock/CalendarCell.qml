import QtQuick
import qs.design

// One day, month or year of the calendar. Light under the pointer like a list row; `today` is the blue
// glossy tile of Windows 7; `muted` is a day of the neighbouring month (or a year outside the decade).
Item {
    id: root

    property string text: ''
    property bool today: false
    property bool muted: false

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: mouseArea.pressed

    signal clicked()

    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: clicked()

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Theme.radiusControl
        opacity: root.today || root.hovered ? 1 : 0
        border.width: 1
        border.color: root.today ? Theme.accentBorder : Theme.rowHoverBorder

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
        }

        gradient: Gradient {
            GradientStop { position: 0.0; color: root.today ? Theme.accentFace[0] : Theme.rowHoverFace[0] }
            GradientStop { position: 0.49; color: root.today ? Theme.accentFace[1] : Theme.rowHoverFace[0] }
            GradientStop { position: 0.5; color: root.today ? Theme.accentFace[2] : Theme.rowHoverFace[1] }
            GradientStop { position: 1.0; color: root.today ? Theme.accentFace[3] : Theme.rowHoverFace[1] }
        }
    }

    GlassText {
        anchors.centerIn: parent
        kind: 'window'
        text: root.text
        font.pixelSize: Theme.fontSizeBody
        color: {
            if (root.today) {
                return Theme.accentText
            }

            return root.muted ? Theme.textMuted : Theme.text
        }
    }

    HoverHandler {
        id: hoverHandler
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        onClicked: root.clicked()
    }
}
