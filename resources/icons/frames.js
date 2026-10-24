.pragma library

// The frames kept in this folder for each icon (`<name>-<size>.png`): the 32-bit sizes the original `.ico`
// has, up to 48 px. Written again whenever an icon is added (`resources/README.md`); every frame listed here
// must exist (`tests/resources.test.mjs`).
const frames = {
    'error': [16, 24, 32, 48],
    'information': [16, 32, 48],
    'question': [16, 32, 48],
    'warning': [16, 32, 48],
}

// The frame to draw an icon from at `screenSize` pixels: the one made for that size, else the next bigger
// one (shrunk), else the biggest kept; 0 for an icon not kept here.
function frameFor(name, screenSize) {
    const kept = frames[name]
    if (kept === undefined) {
        return 0
    }

    const bigger = kept.find(size => size >= screenSize)
    return bigger === undefined ? kept[kept.length - 1] : bigger
}
