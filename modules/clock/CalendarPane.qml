import QtQuick
import qs.design
import qs.services
import '../../services/calendar.js' as CalendarMath

// The calendar of the time flyout, Windows 7's: a white pane with the month's name and an arrow on each
// side, the weekdays and six weeks of days, today as a blue tile. The name zooms out (months of the year,
// then years of the decade) and a click on a month or a year zooms back in; the arrows and the wheel move
// by a month, a year or a decade. `reset()` goes back to today's month.
Item {
    id: root

    property string view: 'days'
    property int year: Clock.now.getFullYear()
    property int month: Clock.now.getMonth()

    readonly property int cellWidth: 32
    readonly property int cellHeight: 28
    readonly property int headerHeight: 32
    readonly property int weekdayHeight: 24
    readonly property int gridHeight: cellHeight * 6
    readonly property var days: CalendarMath.monthGrid(year, month, Clock.firstDay)
    readonly property string title: {
        if (view === 'days') {
            return Clock.locale.monthName(month, Locale.LongFormat) + ', ' + year
        }

        if (view === 'months') {
            return String(year)
        }

        const start = CalendarMath.decadeStart(year)
        return start + '-' + (start + 9)
    }

    implicitWidth: cellWidth * 7 + Theme.space2 * 2
    implicitHeight: headerHeight + weekdayHeight + gridHeight + Theme.space2

    function reset(): void {
        view = 'days'
        year = Clock.now.getFullYear()
        month = Clock.now.getMonth()
    }

    function step(delta: int): void {
        const moved = CalendarMath.step(view, year, month, delta)
        year = moved.year
        month = moved.month
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.step(event.angleDelta.y > 0 ? -1 : 1)
    }

    Item {
        id: header

        x: Theme.space2
        width: parent.width - Theme.space2 * 2
        height: root.headerHeight

        ControlButton {
            id: previous

            kind: 'tool'
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 24
            Accessible.name: qsTr('Previous')
            onClicked: root.step(-1)

            ChevronGlyph {
                anchors.centerIn: parent
                rotation: 180
                color: Theme.controlText
            }
        }

        ControlButton {
            kind: 'tool'
            anchors.left: previous.right
            anchors.right: next.left
            anchors.verticalCenter: parent.verticalCenter
            height: 24
            Accessible.name: root.title
            onClicked: root.view = CalendarMath.zoomedOut(root.view)

            GlassText {
                anchors.centerIn: parent
                kind: 'window'
                text: root.title
                font.pixelSize: Theme.fontSizeHeading
                color: Theme.headingText
            }
        }

        ControlButton {
            id: next

            kind: 'tool'
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 24
            Accessible.name: qsTr('Next')
            onClicked: root.step(1)

            ChevronGlyph {
                anchors.centerIn: parent
                color: Theme.controlText
            }
        }
    }

    // The days: weekdays over six weeks.
    Item {
        x: Theme.space2
        y: root.headerHeight
        width: root.cellWidth * 7
        height: root.weekdayHeight + root.gridHeight
        visible: root.view === 'days'

        Row {
            Repeater {
                model: CalendarMath.weekdayOrder(Clock.firstDay)

                GlassText {
                    required property int modelData

                    width: root.cellWidth
                    height: root.weekdayHeight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    kind: 'window'
                    text: Clock.locale.dayName(modelData, Locale.ShortFormat).substring(0, 2)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }
            }
        }

        EtchedLine {
            y: root.weekdayHeight - 2
            width: parent.width
            dark: Theme.rowSeparator
        }

        Grid {
            y: root.weekdayHeight
            columns: 7

            Repeater {
                model: root.days

                CalendarCell {
                    required property var modelData

                    width: root.cellWidth
                    height: root.cellHeight
                    text: String(modelData.day)
                    muted: modelData.inMonth === false
                    today: CalendarMath.sameDay(new Date(modelData.year, modelData.month, modelData.day), Clock.now)
                    onClicked: {
                        // A day of the next or the last month goes there, as in Windows 7.
                        root.year = modelData.year
                        root.month = modelData.month
                    }
                }
            }
        }
    }

    // The months of a year, or the years of a decade: four columns, three rows.
    Grid {
        x: Theme.space2
        y: root.headerHeight
        width: root.cellWidth * 7
        columns: 4
        visible: root.view !== 'days'

        Repeater {
            model: root.view === 'months' ? CalendarMath.monthCells(root.year) : (root.view === 'years' ? CalendarMath.yearCells(root.year) : [])

            CalendarCell {
                required property var modelData

                width: root.cellWidth * 7 / 4
                height: (root.weekdayHeight + root.gridHeight) / 3
                text: modelData.month === undefined
                    ? String(modelData.year)
                    : Clock.locale.monthName(modelData.month, Locale.ShortFormat)
                muted: modelData.inRange === false
                today: modelData.month === undefined
                    ? modelData.year === Clock.now.getFullYear()
                    : (modelData.year === Clock.now.getFullYear() && modelData.month === Clock.now.getMonth())
                onClicked: {
                    root.year = modelData.year
                    if (modelData.month !== undefined) {
                        root.month = modelData.month
                    }

                    root.view = CalendarMath.zoomedIn(root.view)
                }
            }
        }
    }
}
