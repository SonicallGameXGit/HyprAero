pragma Singleton

import Quickshell
import QtQuick
import 'calendar.js' as CalendarMath

// The time for the whole shell (one system clock, ticking each second) and the words the bar shows for
// it, in the system's locale: the time and the short date on the bar, the long date in the flyout and the
// tooltip. Also which screen's calendar flyout is open (one at a time).
Singleton {
    id: root

    readonly property var now: systemClock.date
    readonly property var locale: Qt.locale()
    readonly property string timeText: Qt.formatTime(now, locale.timeFormat(Locale.ShortFormat))
    readonly property string dateText: Qt.formatDate(now, CalendarMath.fullYearFormat(locale.dateFormat(Locale.ShortFormat)))
    readonly property string longDateText: Qt.formatDate(now, locale.dateFormat(Locale.LongFormat))
    // The time with its seconds, under the analog clock.
    readonly property string preciseTimeText: Qt.formatTime(now, CalendarMath.withSeconds(locale.timeFormat(Locale.ShortFormat)))
    readonly property int firstDay: locale.firstDayOfWeek % 7

    // The screen whose flyout is open ('' when none).
    property string flyoutScreen: ''
    property real flyoutClosedAt: 0
    // A click outside the flyout closes it before the click arrives, so a click on the clock itself would
    // open it again at once; within this long after closing, it does not.
    readonly property int reopenGuard: 300

    function toggleFlyout(screenName: string): void {
        if (flyoutScreen !== '') {
            closeFlyout()
            return
        }

        if (Date.now() - flyoutClosedAt < reopenGuard) {
            return
        }

        flyoutScreen = screenName
    }

    function closeFlyout(): void {
        if (flyoutScreen === '') {
            return
        }

        flyoutScreen = ''
        flyoutClosedAt = Date.now()
    }

    SystemClock {
        id: systemClock

        precision: SystemClock.Seconds
    }
}
