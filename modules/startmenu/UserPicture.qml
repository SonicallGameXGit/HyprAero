import QtQuick
import qs.design
import qs.services

// The framed picture at the top of the right column: the user's picture (or a drawn avatar), or the
// icon of the place under the pointer, fading between them.
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

    implicitWidth: pictureSize + Theme.space2 * 2
    implicitHeight: implicitWidth

    GlassPanel {
        anchors.fill: parent
        cornerRadius: Theme.radiusPanel
    }

    Item {
        id: user

        anchors.centerIn: parent
        width: root.pictureSize
        height: root.pictureSize
        opacity: root.iconPath === '' ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionSoft; easing.type: Easing.OutCubic }
        }

        Avatar {
            anchors.fill: parent
            visible: face.status !== Image.Ready || Session.picturePath === ''
            name: Session.displayName
        }

        Image {
            id: face

            anchors.fill: parent
            visible: Session.picturePath !== ''
            source: Session.picturePath === '' ? '' : 'file://' + Session.picturePath
            // The same path may hold a new picture.
            cache: false
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
