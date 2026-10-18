.pragma library

// The notification area's system icons as Windows 7 draws them: 16 x 16 pixel pictures, white shapes with
// grey shading and a dark edge, sharp on every pixel, and a small sign (a "badge") over the lower right
// corner. Redrawn here from measurements of Windows 7 screenshots (no Windows picture is copied). Plain JS,
// no QML, so node can test it; `PixelGlyph` draws the result.
//
// A picture is a list of 16 strings of 16 letters, each letter a colour of `PixelGlyph`'s palette:
//     '.' nothing        '#' edge (dark, see-through)   'W' ink (white)     'g' shade    'l' light shade
//     's' dark glass (see-through)
//     'r' 'p' 'R' red (fill, light, edge)       'y' 'Y' 'o' gold (light, dark, edge)    'k' dark ink
//     'v' 'V' 'n' green (light, dark, edge)     'b' 'B' 'e' blue (light, dark, edge)
//     'm' 'M' 't' steel (light, dark, edge)

const size = 16

function blank(width, height) {
    const rows = []
    for (let y = 0; y < height; y++) {
        rows.push('.'.repeat(width))
    }

    return rows
}

function put(rows, x, y, letter) {
    if (y < 0 || y >= rows.length || x < 0 || x >= rows[y].length) {
        return
    }

    rows[y] = rows[y].slice(0, x) + letter + rows[y].slice(x + 1)
}

function at(rows, x, y) {
    if (y < 0 || y >= rows.length || x < 0 || x >= rows[y].length) {
        return '.'
    }

    return rows[y][x]
}

// Every empty pixel beside (not only diagonally) a pixel that is drawn becomes edge, as Windows 7 rings its
// white shapes.
function outline(rows, letter) {
    const result = rows.slice()
    for (let y = 0; y < rows.length; y++) {
        for (let x = 0; x < rows[y].length; x++) {
            if (at(rows, x, y) !== '.') {
                continue
            }

            const touches = [[1, 0], [-1, 0], [0, 1], [0, -1]].some(step => at(rows, x + step[0], y + step[1]) !== '.')
            if (touches) {
                put(result, x, y, letter)
            }
        }
    }

    return result
}

// `top` laid over `rows` with its top-left corner at `x`, `y`; its empty pixels let `rows` show through.
function overlay(rows, top, x, y) {
    const result = rows.slice()
    for (let row = 0; row < top.length; row++) {
        for (let column = 0; column < top[row].length; column++) {
            const letter = top[row][column]
            if (letter !== '.') {
                put(result, x + column, y + row, letter)
            }
        }
    }

    return result
}

// The badges, 9 x 9, from the icon materials: a red disc with a white cross ('error'), a red no-entry disc
// ('muted'), a gold triangle with "!" ('warning'), a gold star ('available'), a green disc with a tick
// ('check'), a blue disc with a white dot going round it ('busy', `frame` 0 to 7). 'none' is nothing.
const disc = [
    '..RRRRR..',
    '.RpppppR.',
    'RpppppppR',
    'RrrrrrrrR',
    'RrrrrrrrR',
    'RrrrrrrrR',
    'RrrrrrrrR',
    '.RrrrrrR.',
    '..RRRRR..',
]

function tinted(rows, from, to) {
    return rows.map(row => row.split('').map(letter => {
        const index = from.indexOf(letter)
        return index < 0 ? letter : to[index]
    }).join(''))
}

const busyDots = [[4, 2], [5, 2], [6, 4], [5, 6], [4, 6], [3, 6], [2, 4], [3, 2]]

function badge(kind, frame) {
    if (kind === 'error') {
        return overlay(disc, ['W...W', '.W.W.', '..W..', '.W.W.', 'W...W'], 2, 2)
    }

    if (kind === 'muted') {
        return overlay(disc, ['WW....', '.WW...', '..WW..', '...WW.', '....WW'], 2, 2)
    }

    if (kind === 'warning') {
        return [
            '....o....',
            '...oyo...',
            '...oyo...',
            '..oykyo..',
            '..oYkYo..',
            '.oYYkYYo.',
            '.oYYYYYo.',
            'oYYYkYYYo',
            'ooooooooo',
        ]
    }

    if (kind === 'available') {
        return [
            '....o....',
            '...oyo...',
            'ooooyoooo',
            'oyyyyyyyo',
            '.oyyYyyo.',
            '..oYYYo..',
            '.oYYoYYo.',
            '.oYo.oYo.',
            '.oo...oo.',
        ]
    }

    if (kind === 'check') {
        return overlay(tinted(disc, 'Rpr', 'nvV'), ['.....W', '....WW', 'W..WW.', 'WWWW..', '.WW...'], 2, 2)
    }

    if (kind === 'busy') {
        const dot = busyDots[((frame % busyDots.length) + busyDots.length) % busyDots.length]
        const ring = tinted(disc, 'Rpr', 'ebB')
        return overlay(ring, ['W'], dot[0], dot[1])
    }

    return blank(9, 9)
}

// Lays the badge of `kind` over the lower right corner of a 16 x 16 picture.
function withBadge(rows, kind, frame) {
    if (kind === 'none') {
        return rows
    }

    return overlay(rows, badge(kind, frame), 7, 7)
}

// Windows 7's battery standing up, filled white from the bottom as far as it is charged (`level` 0 to 1),
// the rest dark glass; plugged in, a plug stands in front of it on the right.
function battery(level, plugged, badgeKind) {
    let rows = blank(size, size)
    for (let x = 4; x <= 7; x++) {
        put(rows, x, 1, 'W')
    }

    for (let y = 2; y <= 14; y++) {
        for (let x = 2; x <= 9; x++) {
            const frame = y === 2 || y === 14 || x === 2 || x === 9
            put(rows, x, y, frame ? 'W' : 's')
        }
    }

    const filled = Math.round(Math.min(1, Math.max(0, level)) * 11)
    for (let y = 13; y > 13 - filled; y--) {
        for (let x = 3; x <= 8; x++) {
            put(rows, x, y, x === 3 ? 'l' : 'W')
        }
    }

    rows = outline(rows, '#')
    if (plugged) {
        // The plug is ringed on its own, then laid over the battery: its edge parts it from the battery.
        let plug = blank(8, 11)
        plug = overlay(plug, [
            '..W..W',
            '..W..W',
            '.WWWWWW',
            '.WWWWWg',
            '.WWWWWg',
            '..WWWg',
            '...Wg',
            '...Wg',
            '...Wg',
        ].map(row => row.padEnd(8, '.')), 0, 1)
        return overlay(rows, outline(plug, '#'), 8, 5)
    }

    return withBadge(rows, badgeKind, 0)
}

// Windows 7's "Safely Remove Hardware and Eject Media": a USB stick standing up (steel, its metal plug at
// the top with two windows) and a green tick on its corner, or the busy disc while a drive is ejected.
function drive(busy, frame) {
    const rows = [
        '.....ttttt......',
        '.....tmmmt......',
        '.....tmtmt......',
        '.....tmmmt......',
        '....ttttttt.....',
        '....tmMMMMt.....',
        '....tmMMMMt.....',
        '....tmMMMMt.....',
        '....tmMMMMt.....',
        '....tmMMMMt.....',
        '....tmMMMMt.....',
        '....tmMMMMt.....',
        '....tmMMMMt.....',
        '....tmMMMMt.....',
        '....tmMMMMt.....',
        '....ttttttt.....',
    ]
    return withBadge(rows, busy ? 'busy' : 'check', frame)
}

// Windows 7's Bluetooth icon: the white rune on a glossy blue rounded badge, steel grey while the adapter
// is off.
function bluetooth(active) {
    let rows = [
        '....eeeeeeee....',
        '...ebbbbbbbbe...',
        '..ebbbbbbbbbbe..',
        '..ebbbbbbbbbbe..',
        '..ebbbbbbbbbbe..',
        '..eBBBBBBBBBBe..',
        '..eBBBBBBBBBBe..',
        '..eBBBBBBBBBBe..',
        '..eBBBBBBBBBBe..',
        '..eBBBBBBBBBBe..',
        '..eBBBBBBBBBBe..',
        '..eBBBBBBBBBBe..',
        '..eBBBBBBBBBBe..',
        '..eBBBBBBBBBBe..',
        '...eBBBBBBBBe...',
        '....eeeeeeee....',
    ]
    // The upright, and the two arms: from its top down to the right and across to the lower left, from its
    // foot up to the right and across to the upper left.
    const rune = [
        [7, 2], [7, 3], [7, 4], [7, 5], [7, 6], [7, 7], [7, 8], [7, 9], [7, 10], [7, 11], [7, 12], [7, 13],
        [8, 3], [9, 4], [10, 5], [9, 6], [8, 7], [6, 9], [5, 10], [4, 11],
        [8, 12], [9, 11], [10, 10], [9, 9], [8, 8], [6, 6], [5, 5], [4, 4],
    ]
    for (const point of rune) {
        put(rows, point[0], point[1], 'W')
    }

    if (active === false) {
        rows = tinted(rows, 'ebB', 'tmM')
    }

    return rows
}
