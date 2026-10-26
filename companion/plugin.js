.pragma library

// The companion's side of the plugin's one door, `hyprctl hypraero-frames ...` (plugin/src/core/command.hpp,
// version 1). Plain JS, no Quickshell imports, so node can test it.

const digits = '0123456789abcdef'

// Bytes (an array, or the Uint8ClampedArray a canvas gives) as hexadecimal, two digits a byte.
function toHex(bytes) {
    const parts = new Array(bytes.length)
    for (let index = 0; index < bytes.length; index++) {
        const byte = bytes[index] & 0xff
        parts[index] = digits[byte >> 4] + digits[byte & 0x0f]
    }

    return parts.join('')
}

// A class the plugin sent in hexadecimal, as text; null when it is not hexadecimal or not UTF-8.
function hexToText(hex) {
    if (typeof hex !== 'string' || hex.length === 0 || hex.length % 2 !== 0 || /^[0-9a-fA-F]+$/.test(hex) === false) {
        return null
    }

    let escaped = ''
    for (let index = 0; index < hex.length; index += 2) {
        escaped += '%' + hex.substring(index, index + 2)
    }

    try {
        return decodeURIComponent(escaped)
    } catch (error) {
        return null
    }
}

// The plugin's answer to `missing`: its theme and the classes (in hexadecimal) of the framed windows without an
// icon. null when the answer is not the plugin's (it is not loaded: hyprctl says "unknown request").
function parseMissing(reply) {
    if (typeof reply !== 'string') {
        return null
    }

    const lines = reply.split('\n').filter(line => line !== '')
    if (lines.length === 0 || (lines[0] !== 'theme aero' && lines[0] !== 'theme slate')) {
        return null
    }

    const classes = []
    for (const line of lines.slice(1)) {
        if (/^[0-9a-f]+$/.test(line) && line.length % 2 === 0) {
            classes.push(line)
        }
    }

    return {
        theme: lines[0].substring('theme '.length),
        classes: classes,
    }
}

function themeName(slate) {
    return slate ? 'slate' : 'aero'
}

function themeCommand(slate) {
    return ['hyprctl', 'hypraero-frames', 'theme', themeName(slate)]
}

function missingCommand() {
    return ['hyprctl', 'hypraero-frames', 'missing']
}

// `pixels` are the icon's rows of red, green, blue and alpha, size x size of them.
function iconCommand(size, classHex, pixels) {
    return ['hyprctl', 'hypraero-frames', 'icon', String(size), classHex, toHex(pixels)]
}
