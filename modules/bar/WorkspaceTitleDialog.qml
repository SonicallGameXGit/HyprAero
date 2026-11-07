import Quickshell
import QtQuick
import qs.design
import qs.services

// "Set title...": a narrow window with one field for a workspace's title, OK and Cancel on the grey strip.
// Enter is OK, Escape is Cancel; empty text takes the title away. One for the whole shell
// (`WorkspaceTitles.dialogOpen`).
FloatingWindow {
    id: root

    title: qsTr('Workspace %1').arg(WorkspaceTitles.dialogId)
    implicitWidth: 360
    implicitHeight: body.implicitHeight + strip.height
    color: Theme.surface
    visible: false

    function accept(): void {
        WorkspaceTitles.set(WorkspaceTitles.dialogId, field.text)
        WorkspaceTitles.closeDialog()
    }

    // `visible` is set here and not bound: the compositor closes the window too (its close button, a key).
    Connections {
        target: WorkspaceTitles

        function onDialogOpenChanged(): void {
            root.visible = WorkspaceTitles.dialogOpen
            if (WorkspaceTitles.dialogOpen) {
                field.text = WorkspaceTitles.titleOf(WorkspaceTitles.dialogId)
                field.input.forceActiveFocus()
                field.input.selectAll()
            }
        }
    }

    onClosed: {
        visible = false
        WorkspaceTitles.dialogOpen = false
    }

    Item {
        id: body

        width: parent.width
        implicitHeight: words.implicitHeight + Theme.space5 * 2

        Column {
            id: words

            x: Theme.space5
            y: Theme.space5
            width: parent.width - Theme.space5 * 2
            spacing: Theme.space3

            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: qsTr('Give workspace %1 a title').arg(WorkspaceTitles.dialogId)
                color: Theme.headingText
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontSizeHeading
            }

            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: qsTr('It is shown small on the workspace\'s button. Leave it empty for no title. Only you change it: apps cannot.')
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontSizeBody
            }

            TextField {
                id: field

                width: parent.width
                input.maximumLength: WorkspaceTitles.maxLength
                Accessible.name: qsTr('Title')
                onAccepted: root.accept()
                onEscaped: WorkspaceTitles.closeDialog()
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

            anchors.right: cancelButton.left
            anchors.rightMargin: Theme.space2
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(implicitWidth, 80)
            kind: 'accent'
            text: qsTr('OK')
            activeFocusOnTab: true
            onClicked: root.accept()
        }

        ControlButton {
            id: cancelButton

            anchors.right: parent.right
            anchors.rightMargin: Theme.space3
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(implicitWidth, 80)
            text: qsTr('Cancel')
            activeFocusOnTab: true
            onClicked: WorkspaceTitles.closeDialog()
            Keys.onEscapePressed: WorkspaceTitles.closeDialog()
        }
    }
}
