import Quickshell
import QtQuick
import qs.design
import qs.services

// The flyout of the bar's clock, after Windows 7's: the long date over a calendar on a white pane, the
// analog clock and the time with its seconds beside it, all on the taskbar glass. It sits above the clock
// and takes the keyboard; Escape or a click outside closes it. Opening it shows today's month.
PopupWindow {
    id: root

    property bool shown: false
    // The bar's width, and the middle of the clock in the bar's coordinates.
    property real barWidth: 0
    property real clockX: 0

    readonly property int clockSize: 132

    // Above the clock, kept on the bar (so on the screen); placed here and not slid by the compositor.
    anchor.rect: Qt.rect(Math.max(2, Math.min(clockX - width / 2, barWidth - width - 2)), -Theme.space1, 1, 1)
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Top | Edges.Right
    anchor.adjustment: PopupAdjustment.None
    implicitWidth: Theme.space3 * 3 + pane.width + clockSize
    implicitHeight: Theme.space3 * 2 + dateLine.height + Theme.space2 + pane.height
    color: 'transparent'
    grabFocus: true
    visible: false

    // `visible` is set here and not bound: the popup also hides itself on a click outside.
    onShownChanged: {
        if (shown) {
            calendar.reset()
            visible = true
            return
        }

        visible = false
    }

    onVisibleChanged: {
        if (visible) {
            keyHandler.forceActiveFocus()
            return
        }

        Clock.closeFlyout()
    }

    Item {
        anchors.fill: parent
        opacity: root.visible ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
        }

        Item {
            id: keyHandler

            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Clock.closeFlyout()
        }

        GlassPanel {
            anchors.fill: parent
            cornerRadius: Theme.radiusPanel
            kind: 'taskbar'
        }

        GlassText {
            id: dateLine

            x: Theme.space3
            y: Theme.space3
            text: Clock.longDateText
            font.pixelSize: Theme.fontSizeHeading
        }

        // The pane's etched edge, as the start menu's: a light line around its dark border.
        Rectangle {
            x: pane.x - 1
            y: pane.y - 1
            width: pane.width + 2
            height: pane.height + 2
            radius: pane.radius + 1
            color: 'transparent'
            border.width: 1
            border.color: Theme.taskbarGlassBorderInner
        }

        Rectangle {
            id: pane

            x: Theme.space3
            y: dateLine.y + dateLine.height + Theme.space2
            width: calendar.implicitWidth
            height: calendar.implicitHeight
            radius: Theme.radiusControl
            color: Theme.surface
            border.width: 1
            border.color: Theme.taskbarGlassBorderOuter

            CalendarPane {
                id: calendar

                anchors.fill: parent
            }
        }

        AnalogClock {
            id: face

            x: pane.x + pane.width + Theme.space3
            y: pane.y
            diameter: root.clockSize
            date: Clock.now
        }

        GlassText {
            anchors.horizontalCenter: face.horizontalCenter
            y: face.y + face.height + Theme.space2
            text: Clock.preciseTimeText
            font.pixelSize: Theme.fontSizeHeading
        }
    }
}
