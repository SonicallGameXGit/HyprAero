import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

// The module is a QML library script; strip the pragma and evaluate it as plain JS.
const source = readFileSync(new URL('../services/calendar.js', import.meta.url), 'utf8').replace('.pragma library', '')
const calendar = new Function(source + '\nreturn { weekdayOrder, monthGrid, shiftMonth, monthCells, yearCells, sameDay, step, zoomedOut, zoomedIn, handAngles, fullYearFormat, withSeconds }')()

test('weekdays: start on the given day and wrap', () => {
    assert.deepEqual(calendar.weekdayOrder(0), [0, 1, 2, 3, 4, 5, 6])
    assert.deepEqual(calendar.weekdayOrder(1), [1, 2, 3, 4, 5, 6, 0])
    assert.deepEqual(calendar.weekdayOrder(6), [6, 0, 1, 2, 3, 4, 5])
})

test('month grid: always six weeks, the month in order, neighbours fill the ends', () => {
    // October 2026 starts on a Thursday.
    const grid = calendar.monthGrid(2026, 9, 0)
    assert.equal(grid.length, 42)
    assert.deepEqual(grid[0], { year: 2026, month: 8, day: 27, inMonth: false })
    assert.deepEqual(grid[4], { year: 2026, month: 9, day: 1, inMonth: true })
    assert.deepEqual(grid[34], { year: 2026, month: 9, day: 31, inMonth: true })
    assert.deepEqual(grid[41], { year: 2026, month: 10, day: 7, inMonth: false })
    assert.equal(grid.filter(cell => cell.inMonth).length, 31)
})

test('month grid: the first day of the week moves the first column', () => {
    // Monday first: October 1st 2026 (Thursday) is the fourth cell.
    const grid = calendar.monthGrid(2026, 9, 1)
    assert.deepEqual(grid[3], { year: 2026, month: 9, day: 1, inMonth: true })
    assert.deepEqual(grid[0], { year: 2026, month: 8, day: 28, inMonth: false })
})

test('month grid: a month starting on the first column has no lead', () => {
    // February 2026 starts on a Sunday and has 28 days.
    const grid = calendar.monthGrid(2026, 1, 0)
    assert.deepEqual(grid[0], { year: 2026, month: 1, day: 1, inMonth: true })
    assert.deepEqual(grid[28], { year: 2026, month: 2, day: 1, inMonth: false })
})

test('month grid: leap days and year ends', () => {
    const leap = calendar.monthGrid(2024, 1, 0).filter(cell => cell.inMonth)
    assert.equal(leap.length, 29)
    const december = calendar.monthGrid(2026, 11, 0)
    assert.deepEqual(december[41].year, 2027)
    assert.deepEqual(calendar.monthGrid(2026, 0, 0)[0].year, 2025)
})

test('month grid: years below 100 are not turned into 19xx', () => {
    assert.equal(calendar.monthGrid(50, 5, 0)[10].year, 50)
})

test('shiftMonth: wraps over the year edge both ways', () => {
    assert.deepEqual(calendar.shiftMonth(2026, 11, 1), { year: 2027, month: 0 })
    assert.deepEqual(calendar.shiftMonth(2026, 0, -1), { year: 2025, month: 11 })
    assert.deepEqual(calendar.shiftMonth(2026, 5, 0), { year: 2026, month: 5 })
})

test('month and year cells: twelve each, a decade with a year of each neighbour', () => {
    assert.equal(calendar.monthCells(2026).length, 12)
    assert.deepEqual(calendar.monthCells(2026)[11], { year: 2026, month: 11 })
    const years = calendar.yearCells(2026)
    assert.equal(years.length, 12)
    assert.deepEqual(years[0], { year: 2019, inRange: false })
    assert.deepEqual(years[1], { year: 2020, inRange: true })
    assert.deepEqual(years[10], { year: 2029, inRange: true })
    assert.deepEqual(years[11], { year: 2030, inRange: false })
    assert.deepEqual(calendar.yearCells(2030)[1], { year: 2030, inRange: true })
})

test('sameDay: compares the day, not the time', () => {
    assert.equal(calendar.sameDay(new Date(2026, 9, 15, 1), new Date(2026, 9, 15, 23)), true)
    assert.equal(calendar.sameDay(new Date(2026, 9, 15), new Date(2026, 9, 16)), false)
    assert.equal(calendar.sameDay(new Date(2026, 9, 15), new Date(2025, 9, 15)), false)
})

test('step: a month, a year or a decade per arrow', () => {
    assert.deepEqual(calendar.step('days', 2026, 11, 1), { year: 2027, month: 0 })
    assert.deepEqual(calendar.step('months', 2026, 4, -1), { year: 2025, month: 4 })
    assert.deepEqual(calendar.step('years', 2026, 4, 1), { year: 2036, month: 4 })
})

test('zoom: out to months then years and stops; in to months then days and stops', () => {
    assert.equal(calendar.zoomedOut('days'), 'months')
    assert.equal(calendar.zoomedOut('months'), 'years')
    assert.equal(calendar.zoomedOut('years'), 'years')
    assert.equal(calendar.zoomedIn('years'), 'months')
    assert.equal(calendar.zoomedIn('months'), 'days')
    assert.equal(calendar.zoomedIn('days'), 'days')
})

test('hands: noon, a quarter past three, and the creeping of the slower hands', () => {
    assert.deepEqual(calendar.handAngles(new Date(2026, 9, 15, 12, 0, 0)), { second: 0, minute: 0, hour: 0 })
    assert.deepEqual(calendar.handAngles(new Date(2026, 9, 15, 15, 15, 0)), { second: 0, minute: 90, hour: 97.5 })
    const half = calendar.handAngles(new Date(2026, 9, 15, 6, 30, 30))
    assert.equal(half.second, 180)
    assert.equal(half.minute, 183)
    assert.equal(half.hour, 195)
})

test('fullYearFormat: two year letters become four, anything else stays', () => {
    assert.equal(calendar.fullYearFormat('M/d/yy'), 'M/d/yyyy')
    assert.equal(calendar.fullYearFormat('dd.MM.yy'), 'dd.MM.yyyy')
    assert.equal(calendar.fullYearFormat('yy-MM-dd'), 'yyyy-MM-dd')
    assert.equal(calendar.fullYearFormat('M/d/yyyy'), 'M/d/yyyy')
    assert.equal(calendar.fullYearFormat('d. MMMM'), 'd. MMMM')
})

test('withSeconds: seconds follow the minutes, once', () => {
    assert.equal(calendar.withSeconds('h:mm AP'), 'h:mm:ss AP')
    assert.equal(calendar.withSeconds('HH:mm'), 'HH:mm:ss')
    assert.equal(calendar.withSeconds('HH:mm:ss'), 'HH:mm:ss')
    assert.equal(calendar.withSeconds('HH'), 'HH')
})
