import QtQuick
import QtQuick.Effects

// A question laid out like a Windows 7 task dialog, drawn inside a window over a dimmed backdrop: a big
// glossy picture at the top left, one blue line saying what it is about, the explanation under it, and
// the buttons on a grey strip along the bottom. The first button has focus; Escape and a press outside
// give the safe answer (`cancelled`).
Item {
    id: root

    property bool open: false
    property string heading: ''
    property string text: ''
    // The action button's words and kind ('danger' for what destroys something); the second button
    // always cancels.
    property string actionText: ''
    property string actionKind: 'normal'
    property string cancelText: qsTr('Cancel')
    property Component picture: null

    signal accepted()
    signal cancelled()

    function cancel(): void {
        open = false
        cancelled()
    }

    visible: open
    z: 60

    onOpenChanged: {
        if (open) {
            actionButton.forceActiveFocus()
        }
    }

    Keys.onEscapePressed: cancel()

    Rectangle {
        anchors.fill: parent
        color: Theme.overlay

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: root.cancel()
        }
    }

    Item {
        anchors.centerIn: parent
        width: Math.min(300, root.width - Theme.space4 * 2)
        height: body.implicitHeight + strip.height

        // Swallows presses on the dialog itself, so only the backdrop cancels.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        RectangularShadow {
            anchors.fill: parent
            radius: Theme.radiusPanel
            offset.y: Theme.menuShadowOffset
            blur: Theme.menuShadowBlur
            color: Theme.menuShadowColor
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusPanel
            color: Theme.surface
            border.width: 1
            border.color: Theme.surfaceBorder
        }

        Item {
            id: body

            width: parent.width
            implicitHeight: Math.max(pictureLoader.height, texts.implicitHeight) + Theme.space4 * 2

            Loader {
                id: pictureLoader

                x: Theme.space4
                y: Theme.space4
                sourceComponent: root.picture
            }

            Column {
                id: texts

                x: pictureLoader.x + pictureLoader.width + (root.picture === null ? 0 : Theme.space3)
                y: Theme.space4
                width: parent.width - x - Theme.space4
                spacing: Theme.space2

                Text {
                    width: parent.width
                    text: root.heading
                    wrapMode: Text.Wrap
                    color: Theme.headingText
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fontSizeHeading
                }

                Text {
                    width: parent.width
                    visible: root.text !== ''
                    text: root.text
                    wrapMode: Text.Wrap
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fontSizeBody
                }
            }
        }

        Rectangle {
            id: strip

            anchors.bottom: parent.bottom
            x: 1
            width: parent.width - 2
            height: buttons.height + Theme.space3 * 2
            radius: Theme.radiusPanel - 1
            color: Theme.surfaceSunken

            // Square top corners: only the dialog's bottom corners are round.
            Rectangle {
                width: parent.width
                height: parent.radius
                color: parent.color
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.rowSeparator
            }

            Row {
                id: buttons

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: Theme.space3
                spacing: Theme.space2

                ControlButton {
                    id: actionButton

                    width: Math.max(implicitWidth, 80)
                    kind: root.actionKind
                    text: root.actionText
                    activeFocusOnTab: true
                    onClicked: {
                        root.open = false
                        root.accepted()
                    }
                }

                ControlButton {
                    width: Math.max(implicitWidth, 80)
                    text: root.cancelText
                    activeFocusOnTab: true
                    onClicked: root.cancel()
                }
            }
        }
    }
}
