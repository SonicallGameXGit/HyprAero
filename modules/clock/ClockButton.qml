import QtQuick
import qs.design
import qs.services

// The clock at the right end of the bar, Windows 7's: the time over the short date on a glass tool button.
// A click opens the calendar flyout (`current` while it is open); the tooltip says the long date.
ControlButton {
    id: root

    readonly property string tooltipText: Clock.longDateText

    kind: 'glassTool'
    implicitWidth: Math.max(timeLabel.implicitWidth, dateLabel.implicitWidth) + Theme.space3 * 2
    implicitHeight: 40
    Accessible.name: Clock.timeText + ', ' + Clock.longDateText

    Column {
        anchors.centerIn: parent

        GlassText {
            id: timeLabel

            anchors.horizontalCenter: parent.horizontalCenter
            text: Clock.timeText
            font.pixelSize: Theme.fontSizeSmall
        }

        GlassText {
            id: dateLabel

            anchors.horizontalCenter: parent.horizontalCenter
            text: Clock.dateText
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
