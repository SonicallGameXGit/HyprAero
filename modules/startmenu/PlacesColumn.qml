pragma ComponentBehavior: Bound

import QtQuick
import qs.design
import qs.services

// The right column of the start menu, on the glass: the user's picture, their name (home), the personal
// folders, the system places, and the shut down button with its menu at the bottom. Pointing at a place
// shows its icon in the picture frame, as in Windows 7. While an app's actions are shown in their place
// (`placesShown` off) only the shut down button stays.
Item {
    id: root

    property Tooltip tooltip: null
    // The icon of the place under the pointer ('' shows the user's picture).
    property string pointedIcon: ''
    property bool placesShown: true
    // The picture, which rises over the glass: the menu's window takes the pointer there too.
    readonly property Item pictureItem: picture
    // Where the shut down button's top is, for what is put above it.
    readonly property real powerTop: powerRow.y

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

    // A place: a glass tool button with its name on the left.
    component Place: ControlButton {
        id: place

        property string label: ''
        property string iconName: ''
        property bool bold: false

        width: parent.width
        kind: 'glassTool'
        Accessible.name: label
        onHoveredChanged: {
            if (hovered) {
                root.pointedIcon = iconName
            } else if (root.pointedIcon === iconName) {
                root.pointedIcon = ''
            }
        }

        GlassText {
            anchors.verticalCenter: parent.verticalCenter
            x: Theme.space2
            width: parent.width - Theme.space2 * 2
            text: place.label
            elide: Text.ElideRight
            font.bold: place.bold
        }
    }

    // Shows or hides the menu's tooltip for one of the controls here.
    function showTooltip(control: Item, hovered: bool): void {
        if (root.tooltip === null) {
            return
        }

        if (hovered) {
            root.tooltip.target = control
            root.tooltip.text = control.Accessible.name
        }

        root.tooltip.shown = hovered
    }

    function changePicture(): void {
        if (Session.canChoosePicture === false) {
            return
        }

        Session.choosePicture()
        root.opened()
    }

    // A click on the picture changes it, as in Windows 7; the chooser is a window of its own, so the menu
    // closes. Without a chooser the tooltip says how to change it by hand.
    UserPicture {
        id: picture

        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        opacity: root.placesShown ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
        }

        iconPath: AppIcons.forName(root.pointedIcon)
        Accessible.role: Accessible.Button
        Accessible.name: Session.canChoosePicture
            ? qsTr('Change your picture')
            : qsTr('To change your picture, save it as ~/.face (or install zenity to choose one here)')
        Accessible.onPressAction: root.changePicture()

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Session.canChoosePicture ? Qt.PointingHandCursor : Qt.ArrowCursor
            onContainsMouseChanged: root.showTooltip(picture, containsMouse)
            onClicked: root.changePicture()
        }
    }

    Column {
        anchors.top: picture.bottom
        anchors.topMargin: Theme.space3
        width: parent.width
        spacing: 2
        opacity: root.placesShown ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
        }

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

        // A thin etched line, like the glass edge, fading out at both ends.
        Item {
            width: parent.width
            height: Theme.space3

            EtchedLine {
                anchors.verticalCenter: parent.verticalCenter
                x: Theme.space2
                width: parent.width - Theme.space2 * 2
                dark: Theme.taskbarGlassBorderOuter
                light: Theme.taskbarGlassBorderInner
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

    // Shut down, and the arrow for the other ways of leaving; joined like one split button of glass, as in
    // Windows 7.
    Row {
        id: powerRow

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: -1

        ControlButton {
            kind: 'glass'
            width: Math.max(implicitWidth, 84)
            text: qsTr('Shut down')
            onClicked: root.powerRequested('powerOff')
        }

        ControlButton {
            id: arrow

            kind: 'glass'
            width: 24
            Accessible.name: qsTr('More ways to leave')
            onClicked: root.powerMenuRequested(arrow.mapToItem(root, arrow.width, 0))
            onHoveredChanged: root.showTooltip(arrow, hovered)

            ChevronGlyph {
                anchors.centerIn: parent
                size: 8
                color: Theme.taskbarGlassText
            }
        }
    }
}
