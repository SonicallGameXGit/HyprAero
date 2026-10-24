.pragma library

// The words a balloon shows from a notification. Plain JS, no Quickshell imports, so node can test it.
//
// Windows 7's balloons show plain text: a title of at most 63 characters and words of at most 255 (the room
// Windows gives them). The server tells apps it takes no markup, but some send it anyway, so tags are taken
// out and entities turned back into characters rather than shown as they are.

const titleLength = 63
const textLength = 255

const entities = {
    amp: '&',
    lt: '<',
    gt: '>',
    quot: '"',
    apos: '\'',
    nbsp: ' ',
}

// `markup` without its tags and with its entities as characters; a line break tag stays a line break.
function plainText(markup) {
    const withoutTags = markup.replace(/<br\s*\/?>/gi, '\n').replace(/<[^>]*>/g, '')
    return withoutTags.replace(/&(#x[0-9a-f]+|#[0-9]+|[a-z]+);/gi, (whole, name) => {
        if (name[0] === '#') {
            const code = name[1] === 'x' || name[1] === 'X' ? parseInt(name.slice(2), 16) : parseInt(name.slice(1), 10)
            return code > 0 && code <= 0x10ffff ? String.fromCodePoint(code) : whole
        }

        const character = entities[name.toLowerCase()]
        return character === undefined ? whole : character
    })
}

// `text` split into its characters (code points): an emoji is two UTF-16 units, kept together. Done by hand
// because Quickshell's JavaScript engine splits a string into units in `Array.from` and spreads.
function characters(text) {
    const found = []
    for (let i = 0; i < text.length; i++) {
        const unit = text.charCodeAt(i)
        const next = i + 1 < text.length ? text.charCodeAt(i + 1) : 0
        if (unit >= 0xd800 && unit <= 0xdbff && next >= 0xdc00 && next <= 0xdfff) {
            found.push(text.slice(i, i + 2))
            i++
            continue
        }

        found.push(text[i])
    }

    return found
}

// `text` cut to `length` characters, the last one an ellipsis when something was cut. A cut never splits an
// emoji. (No `trimEnd`: Quickshell's engine does not have it.)
function cut(text, length) {
    const all = characters(text)
    if (all.length <= length) {
        return text
    }

    return all.slice(0, length - 1).join('').replace(/\s+$/, '') + '…'
}

// `{ title, text }` for a notification's summary and body.
function words(summary, body) {
    return {
        title: cut(plainText(summary).trim(), titleLength),
        text: cut(plainText(body).trim(), textLength),
    }
}
