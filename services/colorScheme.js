.pragma library

// Reads the freedesktop portal's `color-scheme` value out of a line printed by gdbus: either the
// reply of Settings.Read, `(<<uint32 1>>,)`, or a SettingChanged signal line. 1 is dark, 2 is light,
// 0 means "no preference". Returns 'dark', 'light' or 'unknown' (also for lines about other settings).
function parseColorScheme(line) {
    const isSignal = line.includes('SettingChanged')
    if (isSignal && !line.includes('color-scheme')) {
        return 'unknown'
    }

    const match = line.match(/uint32 (\d+)/)
    if (match === null) {
        return 'unknown'
    }

    if (match[1] === '1') {
        return 'dark'
    }
    if (match[1] === '2') {
        return 'light'
    }

    return 'unknown'
}
