.pragma library

// The main colour of an app's icon, for the light that follows the pointer over its taskbar button, as Windows
// 7 lights a button in its icon's colour. Plain JS, no Quickshell imports, so node can test it.

// What was found for each icon (its path), for the session: a library script is shared by everything that
// imports it, so an icon is read once however many buttons show it.
const found = {}

// The colour found for `path` ('#rrggbb' or ''), undefined when it was not read yet.
function cached(path) {
    return Object.prototype.hasOwnProperty.call(found, path) ? found[path] : undefined
}

function remember(path, colour) {
    found[path] = colour
    return colour
}

// Hue buckets of 30 degrees each.
const bucketCount = 12
// A pixel counts as coloured from this saturation and brightness on; greys, white and black do not.
const minSaturation = 0.3
const minValue = 0.25
// Less coloured weight than this share of the icon's opaque pixels and the icon has no colour of its own
// (a white or grey icon): '' is returned, and the light is the neutral one.
const minColouredShare = 0.08

// Hue (0 to 1), saturation and value (0 to 1 each) of an RGB colour (0 to 255 each).
function toHsv(red, green, blue) {
    const max = Math.max(red, green, blue)
    const min = Math.min(red, green, blue)
    const delta = max - min
    let hue = 0
    if (delta > 0) {
        if (max === red) {
            hue = ((green - blue) / delta) % 6
        } else if (max === green) {
            hue = (blue - red) / delta + 2
        } else {
            hue = (red - green) / delta + 4
        }

        hue = hue / 6
        if (hue < 0) {
            hue += 1
        }
    }

    return { hue: hue, saturation: max === 0 ? 0 : delta / max, value: max / 255 }
}

function toRgb(hue, saturation, value) {
    const sector = Math.floor(hue * 6) % 6
    const fraction = hue * 6 - Math.floor(hue * 6)
    const low = value * (1 - saturation)
    const falling = value * (1 - fraction * saturation)
    const rising = value * (1 - (1 - fraction) * saturation)
    const sectors = [
        [value, rising, low],
        [falling, value, low],
        [low, value, rising],
        [low, falling, value],
        [rising, low, value],
        [value, low, falling],
    ]

    return sectors[sector].map(part => Math.round(part * 255))
}

function hex(part) {
    const text = part.toString(16)
    return text.length === 1 ? '0' + text : text
}

// The main colour of the pixels in `data` (RGBA, 0 to 255, four numbers a pixel, as a canvas's image data
// gives them) as '#rrggbb', or '' when the icon has no colour of its own. The most common hue wins, each
// pixel counting by how coloured and how opaque it is; the result is made bright, as a light is.
function dominantColor(data) {
    const weights = []
    const sums = []
    for (let index = 0; index < bucketCount; index++) {
        weights.push(0)
        sums.push([0, 0, 0])
    }

    let opaque = 0
    for (let at = 0; at + 3 < data.length; at += 4) {
        const alpha = data[at + 3] / 255
        if (alpha < 0.5) {
            continue
        }

        opaque++
        const hsv = toHsv(data[at], data[at + 1], data[at + 2])
        if (hsv.saturation < minSaturation || hsv.value < minValue) {
            continue
        }

        const bucket = Math.min(Math.floor(hsv.hue * bucketCount), bucketCount - 1)
        const weight = hsv.saturation * hsv.value * alpha
        weights[bucket] += weight
        sums[bucket][0] += data[at] * weight
        sums[bucket][1] += data[at + 1] * weight
        sums[bucket][2] += data[at + 2] * weight
    }

    // A hue on the border of two buckets is split between them, so each bucket counts with its neighbours.
    let best = -1
    let bestWeight = 0
    let total = 0
    for (let index = 0; index < bucketCount; index++) {
        total += weights[index]
        const around = weights[(index + bucketCount - 1) % bucketCount] + weights[index] + weights[(index + 1) % bucketCount]
        if (around > bestWeight) {
            best = index
            bestWeight = around
        }
    }

    if (opaque === 0 || best === -1 || total / opaque < minColouredShare) {
        return ''
    }

    const rgb = [0, 0, 0]
    for (const index of [(best + bucketCount - 1) % bucketCount, best, (best + 1) % bucketCount]) {
        rgb[0] += sums[index][0]
        rgb[1] += sums[index][1]
        rgb[2] += sums[index][2]
    }

    const average = toHsv(rgb[0] / bestWeight, rgb[1] / bestWeight, rgb[2] / bestWeight)
    const bright = toRgb(average.hue, Math.max(0.45, Math.min(average.saturation, 0.85)), 1)
    return '#' + hex(bright[0]) + hex(bright[1]) + hex(bright[2])
}
