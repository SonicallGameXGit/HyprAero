import QtQuick
import qs.design
import qs.services

// The picture at the top of the right column: the user's picture (or a drawn avatar) in the Windows 7
// user tile, or the icon of the place under the pointer, fading between them; as in Windows 7, the icon
// stands on the glass without the frame.
Item {
    id: root

    // The pointed place's icon, '' for the user.
    property string iconPath: ''

    readonly property int pictureSize: 48
    // The last icon shown, kept while it fades out.
    property string fadingIcon: ''

    onIconPathChanged: {
        if (iconPath !== '') {
            fadingIcon = iconPath
        }
    }

    implicitWidth: user.implicitWidth
    implicitHeight: user.implicitHeight

    PictureFrame {
        id: user

        anchors.centerIn: parent
        pictureSize: root.pictureSize
        opacity: root.iconPath === '' ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionSoft; easing.type: Easing.OutCubic }
        }

        // Only when the user has no picture of their own (or it cannot be read). While theirs loads the frame
        // stays empty, so the avatar never shows first.
        Avatar {
            anchors.fill: parent
            visible: Session.picturePath === '' || face.status === Image.Error
            name: Session.displayName
        }

        Image {
            id: face

            anchors.fill: parent
            visible: Session.picturePath !== '' && face.status !== Image.Error
            // The stamp changes with the file, so a new picture is another address and is read again, while
            // an unchanged one comes from Qt's cache (a local file is read without the part after `?`).
            source: Session.picturePath === '' ? '' : `file://${Session.picturePath}?${Session.pictureStamp}`
            // Qt loads it again each time the menu's window comes back (seen in the log: one load per
            // opening); the picture shown stays until that load is done, so it never blinks.
            retainWhileLoading: true
            sourceSize: Qt.size(root.pictureSize * 2, root.pictureSize * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            mipmap: true
        }
    }

    AppIconImage {
        anchors.centerIn: parent
        width: root.pictureSize
        height: root.pictureSize
        source: root.fadingIcon
        opacity: root.iconPath === '' ? 0 : 1

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionSoft; easing.type: Easing.OutCubic }
        }
    }
}
