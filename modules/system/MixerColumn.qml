import Quickshell
import Quickshell.Widgets
import QtQuick
import qs.design

// One column of the Volume Mixer, as Windows 7's (measured on its screenshot): a 32px picture, a name, a
// vertical volume trackbar and a mute button (Windows' blue speaker) under it. The device's column draws
// the sound device (Windows' own picture, `resources/icons/`); an app's its icon by its theme icon name, or
// a generic app picture. Only the column that has the keyboard has the aqua thumb.
Item {
    id: root

    property string name: ''
    // A theme icon name; '' draws the speakers (the device's column).
    property string iconName: ''
    property bool speaker: false
    // The name is left out where something else takes its place (the device's drop-down list).
    property bool showName: true
    property real volume: 0
    property bool muted: false

    readonly property string iconPath: iconName === '' ? '' : Quickshell.iconPath(iconName, true)
    // Where the trackbar's thumb rests on the screen, in this column's coordinates: the Volume Mixer draws
    // the device's level across the other columns from it.
    readonly property real thumbY: trackbar.y + trackbar.thumbCentre
    readonly property Item slider: trackbar
    // The middle line the picture, the name and the mute button stand on.
    readonly property real centre: 52

    signal moved(real value)
    signal muteToggled()

    implicitWidth: 112
    implicitHeight: 260

    WindowsIcon {
        x: root.centre - width / 2
        y: 18
        size: 32
        visible: root.speaker
        name: 'speakers'
    }

    IconImage {
        id: appPicture

        x: root.centre - width / 2
        y: 18
        implicitSize: 32
        visible: root.speaker === false && root.iconPath !== '' && status === Image.Ready
        source: root.iconPath
    }

    GenericAppIcon {
        x: root.centre - width / 2
        y: 18
        width: 32
        height: 32
        visible: root.speaker === false && appPicture.visible === false
    }

    Text {
        id: label

        x: root.centre - width / 2
        y: 56
        width: root.width - Theme.space2
        height: Theme.fontSizeBody * 3
        visible: root.showName
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
        text: root.name
        color: Theme.text
        font.family: Theme.fontUi
        font.pixelSize: Theme.fontSizeBody
    }

    // `thumbCentre`: the middle of the thumb along the trackbar (the thumb travels from half its width
    // below the top to half above the bottom).
    Slider {
        id: trackbar

        readonly property real thumbCentre: thumbShort / 2 + (height - thumbShort) * (1 - Math.min(1, Math.max(0, value)))

        x: 40
        y: 92
        height: 125
        quiet: true
        value: root.volume
        Accessible.name: qsTr('Volume of %1').arg(root.name)
        onMoved: value => root.moved(value)
    }

    ControlButton {
        id: muteButton

        x: root.centre + 1 - width / 2
        y: 233 + 8 - height / 2
        width: 28
        height: 26
        kind: 'tool'
        activeFocusOnTab: true
        Accessible.name: root.muted ? qsTr('Unmute %1').arg(root.name) : qsTr('Mute %1').arg(root.name)
        onClicked: root.muteToggled()

        WindowsIcon {
            anchors.centerIn: parent
            size: 16
            name: root.muted ? 'mute-button-muted' : 'mute-button'
        }
    }
}
