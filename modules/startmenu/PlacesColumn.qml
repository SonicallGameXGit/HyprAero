pragma ComponentBehavior: Bound

import QtQuick
import qs.design
import qs.services

// The right column of the start menu, on the glass: the user's picture, their name (home), the personal
// folders, the system places, and the shut down button with its menu at the bottom. Pointing at a place
// shows its icon in the picture frame, as in Windows 7.
Item {
    id: root

    property Tooltip tooltip: null
    // The icon of the place under the pointer ('' shows the user's picture).
    property string pointedIcon: ''

    // Something was opened; the menu closes.
    signal opened()
    // 'powerOff' from the button; the arrow asks for the menu of the others, its top-right corner at `at`.
    signal powerRequested(string action)
    signal powerMenuRequested(point at)

    readonly property var folderNames: ({
        documents: qsTr('Documents'),
        pictures: qsTr('Pictures'),
        music: qsTr('Music'),
        videos: qsTr('Videos'),
        downloads: qsTr('Downloads'),
    })
    readonly property var folderIcons: ({
        documents: 'folder-documents',
        pictures: 'folder-pictures',
        music: 'folder-music',
        videos: 'folder-videos',
        downloads: 'folder-download',
    })

    // A place: a tool button with its name on the left.
    component Place: ControlButton {
        id: place

        property string label: ''
        property string iconName: ''
        property bool bold: false

        width: parent.width
        kind: 'tool'
        Accessible.name: label
        onHoveredChanged: {
            if (hovered) {
                root.pointedIcon = iconName
            } else if (root.pointedIcon === iconName) {
                root.pointedIcon = ''
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            x: Theme.space2
            width: parent.width - Theme.space2 * 2
            text: place.label
            elide: Text.ElideRight
            color: Theme.glassText
            font.family: Theme.fontUi
            font.pixelSize: Theme.fontSizeBody
            font.bold: place.bold
        }
    }

    UserPicture {
        id: picture

        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        iconPath: AppIcons.forName(root.pointedIcon)
    }

    Column {
        anchors.top: picture.bottom
        anchors.topMargin: Theme.space3
        width: parent.width
        spacing: 2

        Place {
            label: Session.displayName
            iconName: 'user-home'
            bold: true
            onClicked: {
                Session.openFolder(Session.home)
                root.opened()
            }
        }

        Repeater {
            model: Session.folders

            Place {
                required property var modelData

                label: root.folderNames[modelData.key]
                iconName: root.folderIcons[modelData.key]
                onClicked: {
                    Session.openFolder(modelData.path)
                    root.opened()
                }
            }
        }

        // A thin etched line, like the glass edge.
        Item {
            width: parent.width
            height: Theme.space3

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: Theme.space2
                width: parent.width - Theme.space2 * 2
                height: 1
                color: Theme.glassBorderOuter
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 1
                x: Theme.space2
                width: parent.width - Theme.space2 * 2
                height: 1
                color: Theme.glassBorderInner
            }
        }

        Place {
            label: qsTr('Computer')
            iconName: 'computer'
            onClicked: {
                Session.openFolder('/')
                root.opened()
            }
        }

        Place {
            label: qsTr('Terminal')
            iconName: 'utilities-terminal'
            onClicked: {
                Session.openTerminal()
                root.opened()
            }
        }
    }

    // Shut down, and the arrow for the other ways of leaving; joined like one split button.
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: -1

        ControlButton {
            width: Math.max(implicitWidth, 84)
            text: qsTr('Shut down')
            onClicked: root.powerRequested('powerOff')
        }

        ControlButton {
            id: arrow

            width: 24
            Accessible.name: qsTr('More ways to leave')
            onClicked: root.powerMenuRequested(arrow.mapToItem(root, arrow.width, 0))
            onHoveredChanged: {
                if (root.tooltip === null) {
                    return
                }

                if (hovered) {
                    root.tooltip.target = arrow
                    root.tooltip.text = arrow.Accessible.name
                }

                root.tooltip.shown = hovered
            }

            ChevronGlyph {
                anchors.centerIn: parent
                size: 8
            }
        }
    }
}
