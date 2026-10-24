.pragma library

// The angles of the analog clock's hands (`AnalogClock.qml`). Plain JS, no Quickshell imports, so node can
// test it.

// The hands' angles in degrees, clockwise from 12. The minute and hour hands creep between marks, the second
// hand ticks (as the analog clock of Windows 7 does).
function handAngles(date) {
    const seconds = date.getSeconds()
    const minutes = date.getMinutes()
    return {
        second: seconds * 6,
        minute: (minutes + seconds / 60) * 6,
        hour: ((date.getHours() % 12) + minutes / 60) * 30,
    }
}
