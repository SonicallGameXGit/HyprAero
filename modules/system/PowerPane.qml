pragma ComponentBehavior: Bound

import QtQuick
import qs.design
import qs.services

// The power flyout, after Windows 7's: the battery and what it has left at the top, a line, then "Select a
// power plan:" with the plans (power-profiles-daemon's), on the flyout's white body. Windows' "Adjust screen
// brightness" and "More power options" links are left out, and with them the band: the shell has no such
// pages yet.
Item {
    id: root

    implicitWidth: 300
    implicitHeight: column.y + column.implicitHeight + Theme.space4 + frame.frameWidth * 2

    FlyoutFrame {
        id: frame

        anchors.fill: parent

        BatteryPicture {
            id: picture

            x: Theme.space3
            y: Theme.space3
            level: Power.level
            badge: Power.badge
        }

        Text {
            x: picture.x + picture.width + Theme.space3
            width: parent.width - x - Theme.space3
            anchors.verticalCenter: picture.verticalCenter
            wrapMode: Text.Wrap
            text: Power.statusText
            color: Theme.text
            font.family: Theme.fontUi
            font.pixelSize: Theme.fontSizeBody
        }

        Rectangle {
            id: line

            x: Theme.space3
            y: picture.y + picture.height + Theme.space3
            width: parent.width - Theme.space3 * 2
            height: 1
            color: Theme.toolbarBorder
        }
    }

    Column {
        id: column

        x: frame.frameWidth + Theme.space3
        y: frame.frameWidth + line.y + Theme.space3
        width: parent.width - x * 2
        spacing: Theme.space2

        Text {
            text: qsTr('Select a power plan:')
            color: Theme.text
            font.family: Theme.fontUi
            font.pixelSize: Theme.fontSizeBody
        }

        Repeater {
            model: Power.plans

            RadioButton {
                required property int modelData

                x: Theme.space2
                text: Power.planName(modelData)
                checked: Power.plan === modelData
                onPicked: Power.setPlan(modelData)
            }
        }

        Text {
            width: parent.width
            visible: Power.plans.length === 0
            wrapMode: Text.Wrap
            text: qsTr('Power plans need power-profiles-daemon, which is not running.')
            color: Theme.textMuted
            font.family: Theme.fontUi
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
