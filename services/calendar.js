.pragma library

// The maths of the clock flyout: the grids of its calendar (days of a month, months of a year, years of a
// decade) and moving between them (the analog clock's hands are `design/clockHands.js`). Plain JS, no
// Quickshell imports, so node can test it. Months are 0-11 and weekdays 0-6 from Sunday, as in `Date`.

// `new Date(year, ...)` turns the years 0-99 into 1900-1999; setting the year afterwards does not.
function dateOf(year, month, day) {
    const date = new Date(2000, 0, 1)
    date.setFullYear(year, month, day)
    return date
}

// The weekdays in the order a week is shown, starting on `firstDay`.
function weekdayOrder(firstDay) {
    const order = []
    for (let index = 0; index < 7; index++) {
        order.push((firstDay + index) % 7)
    }

    return order
}

// Six weeks of days, Windows 7's calendar always shows six rows: the days of the month and the ones of the
// months around it that fill the first and the last row (`inMonth` false).
function monthGrid(year, month, firstDay) {
    const lead = (dateOf(year, month, 1).getDay() - firstDay + 7) % 7
    const cells = []
    for (let index = 0; index < 42; index++) {
        const date = dateOf(year, month, 1 - lead + index)
        cells.push({
            year: date.getFullYear(),
            month: date.getMonth(),
            day: date.getDate(),
            inMonth: date.getMonth() === month,
        })
    }

    return cells
}

function shiftMonth(year, month, delta) {
    const date = dateOf(year, month + delta, 1)
    return { year: date.getFullYear(), month: date.getMonth() }
}

// The twelve months of a year, for the zoomed-out view.
function monthCells(year) {
    const cells = []
    for (let month = 0; month < 12; month++) {
        cells.push({ year: year, month: month })
    }

    return cells
}

// The first year of the decade a year belongs to.
function decadeStart(year) {
    return Math.floor(year / 10) * 10
}

// Twelve years: the decade and the last year before and the first after it (`inRange` false), as the
// zoomed-out view of Windows 7 shows them.
function yearCells(year) {
    const start = decadeStart(year)
    const cells = []
    for (let index = -1; index <= 10; index++) {
        cells.push({ year: start + index, inRange: index >= 0 && index <= 9 })
    }

    return cells
}

function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
}

// What the arrows of a view move by: a month, a year or a decade.
function step(view, year, month, delta) {
    if (view === 'days') {
        return shiftMonth(year, month, delta)
    }

    if (view === 'months') {
        return { year: year + delta, month: month }
    }

    return { year: year + delta * 10, month: month }
}

// Clicking the title zooms out one level; clicking a month or a year zooms back in. The ends stay.
function zoomedOut(view) {
    return view === 'days' ? 'months' : 'years'
}

function zoomedIn(view) {
    return view === 'years' ? 'months' : 'days'
}

// A locale's short date format with the year in full ("M/d/yy" to "M/d/yyyy"): Windows 7's taskbar shows
// "10/15/2026", not "10/15/26". A format that already has four year letters, or none, stays.
function fullYearFormat(format) {
    return format.replace(/(^|[^y])yy([^y]|$)/, '$1yyyy$2')
}

// A time format with seconds after its minutes ("h:mm AP" to "h:mm:ss AP"), for the time under the analog
// clock. One that has seconds already, or no minutes, stays.
function withSeconds(format) {
    if (format.includes('s')) {
        return format
    }

    return format.replace(/m+/, '$&:ss')
}
