import QtQuick
import qs.design
import qs.services

// The volume flyout, after Windows 7's (84 x 305, measured): the sound device's picture at the top (Windows'
// own, `resources/icons/`), a flat button that opens the Volume Mixer (Windows' opens the device's
// settings), the volume trackbar under it and the mute button (Windows' own blue speaker) at the bottom;
// "Mixer" in the band. Without an output device it
// says so instead. The trackbar has the keyboard.
FocusScope {
    id: root

    implicitWidth: 84
    implicitHeight: 305

    FlyoutFrame {
        id: frame

        anchors.fill: parent
        bandHeight: 42
        band: LinkText {
            anchors.centerIn: parent
            text: qsTr('Mixer')
            activeFocusOnTab: true
            onClicked: {
                SystemIcons.closeFlyout()
                Volume.openMixer()
            }
        }

        ControlButton {
            id: device

            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.space2
            width: 42
            height: 42
            kind: 'tool'
            enabled: Volume.present
            Accessible.name: qsTr('Open Volume Mixer')
            onClicked: {
                SystemIcons.closeFlyout()
                Volume.openMixer()
            }

            WindowsIcon {
                anchors.centerIn: parent
                size: 32
                name: 'speakers'
            }
        }

        Slider {
            id: slider

            x: (parent.width - width) / 2 + 2
            y: 63
            height: 122
            visible: Volume.present
            value: Volume.volume
            focus: true
            Accessible.name: qsTr('Volume')
            onMoved: value => Volume.setVolume(value)
        }

        Text {
            anchors.centerIn: slider
            width: parent.width - Theme.space2
            visible: Volume.present === false
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: qsTr('No audio output device is installed')
            color: Theme.textMuted
            font.family: Theme.fontUi
            font.pixelSize: Theme.fontSizeSmall
        }

        ControlButton {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 197
            width: 28
            height: 26
            kind: 'tool'
            enabled: Volume.present
            Accessible.name: Volume.muted ? qsTr('Unmute') : qsTr('Mute')
            onClicked: Volume.toggleMute()

            WindowsIcon {
                anchors.centerIn: parent
                size: 16
                name: Volume.muted ? 'mute-button-muted' : 'mute-button'
            }
        }
    }
}
