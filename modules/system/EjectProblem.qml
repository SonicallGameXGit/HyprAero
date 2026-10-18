import Quickshell
import QtQuick
import qs.design
import qs.services

// Windows 7's "Problem Ejecting" message, shown when a drive could not be ejected: a narrow window with the
// warning picture, one blue line saying what happened, what to do about it, and OK on the grey strip.
FloatingWindow {
    id: root

    title: qsTr('Problem Ejecting %1').arg(Drives.problemName)
    implicitWidth: 420
    implicitHeight: body.implicitHeight + strip.height
    color: Theme.surface
    visible: false

    // `visible` is set here and not bound: the compositor closes the window too (its close button, a key).
    Connections {
        target: Drives

        function onProblemOpenChanged(): void {
            root.visible = Drives.problemOpen
            if (Drives.problemOpen) {
                okButton.forceActiveFocus()
            }
        }
    }

    onClosed: {
        visible = false
        Drives.problemOpen = false
    }

    onVisibleChanged: {
        if (visible === false) {
            Drives.problemOpen = false
        }
    }

    Item {
        id: body

        width: parent.width
        implicitHeight: Math.max(picture.height, words.implicitHeight) + Theme.space5 * 2

        StatusBadge {
            id: picture

            x: Theme.space5
            y: Theme.space5
            size: 32
            kind: 'warning'
        }

        Column {
            id: words

            x: picture.x + picture.width + Theme.space4
            y: Theme.space5
            width: parent.width - x - Theme.space5
            spacing: Theme.space2

            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: qsTr('This device is currently in use.')
                color: Theme.headingText
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontSizeHeading
            }

            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: qsTr('Close any programs or windows that might be using %1, and then try again.').arg(Drives.problemName)
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontSizeBody
            }
        }
    }

    Rectangle {
        id: strip

        anchors.bottom: parent.bottom
        width: parent.width
        height: okButton.height + Theme.space3 * 2
        color: Theme.surfaceSunken

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.rowSeparator
        }

        ControlButton {
            id: okButton

            anchors.right: parent.right
            anchors.rightMargin: Theme.space3
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(implicitWidth, 80)
            text: qsTr('OK')
            activeFocusOnTab: true
            onClicked: Drives.problemOpen = false
            Keys.onEscapePressed: Drives.problemOpen = false
        }
    }
}
