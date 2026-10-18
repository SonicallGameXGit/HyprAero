.pragma library

// The frames kept in this folder for each icon (`<name>-<size>.png`): the 32-bit sizes the original `.ico`
// has, up to 48 px. Written again whenever an icon is added (`resources/README.md`); every frame listed here
// is loaded by `tests/qml/tst_WindowsIcon.qml`.
const frames = {
    'flyout-wifi-available': [32, 48],
    'flyout-wifi-none': [32, 48],
    'flyout-wired-none': [32, 48],
    'mute-button': [16, 20, 24, 32],
    'mute-button-muted': [16, 20, 24, 32],
    'network-public': [16, 24, 32, 48],
    'network-wifi-0': [16, 20, 24, 32],
    'network-wifi-1': [16, 20, 24, 32],
    'network-wifi-2': [16, 20, 24, 32],
    'network-wifi-3': [16, 20, 24, 32],
    'network-wifi-4': [16, 20, 24, 32],
    'network-wifi-5': [16, 20, 24, 32],
    'network-wifi-available': [16, 20, 24, 32],
    'network-wifi-connecting-1': [16, 20, 24, 32],
    'network-wifi-connecting-2': [16, 20, 24, 32],
    'network-wifi-connecting-3': [16, 20, 24, 32],
    'network-wifi-connecting-4': [16, 20, 24, 32],
    'network-wifi-connecting-5': [16, 20, 24, 32],
    'network-wifi-connecting-6': [16, 20, 24, 32],
    'network-wifi-connecting-7': [16, 20, 24, 32],
    'network-wifi-connecting-8': [16, 20, 24, 32],
    'network-wifi-connecting-9': [16, 20, 24, 32],
    'network-wifi-limited-0': [16, 20, 24, 32],
    'network-wifi-limited-1': [16, 20, 24, 32],
    'network-wifi-limited-2': [16, 20, 24, 32],
    'network-wifi-limited-3': [16, 20, 24, 32],
    'network-wifi-limited-4': [16, 20, 24, 32],
    'network-wifi-limited-5': [16, 20, 24, 32],
    'network-wifi-none': [16, 20, 24, 32],
    'network-wired': [16, 20, 24, 32],
    'network-wired-connecting-1': [16, 20, 24, 32],
    'network-wired-connecting-2': [16, 20, 24, 32],
    'network-wired-connecting-3': [16, 20, 24, 32],
    'network-wired-connecting-4': [16, 20, 24, 32],
    'network-wired-connecting-5': [16, 20, 24, 32],
    'network-wired-connecting-6': [16, 20, 24, 32],
    'network-wired-connecting-7': [16, 20, 24, 32],
    'network-wired-connecting-8': [16, 20, 24, 32],
    'network-wired-connecting-9': [16, 20, 24, 32],
    'network-wired-limited': [16, 20, 24, 32],
    'network-wired-none': [16, 20, 24, 32],
    'refresh': [16, 20, 24, 32],
    'shield-warning': [16, 24, 32, 48],
    'signal-bars-0': [32, 48],
    'signal-bars-1': [32, 48],
    'signal-bars-2': [32, 48],
    'signal-bars-3': [32, 48],
    'signal-bars-4': [32, 48],
    'signal-bars-5': [32, 48],
    'signal-bars-slate-0': [32, 48],
    'signal-bars-slate-1': [32, 48],
    'signal-bars-slate-2': [32, 48],
    'signal-bars-slate-3': [32, 48],
    'signal-bars-slate-4': [32, 48],
    'signal-bars-slate-5': [32, 48],
    'speakers': [16, 32, 48],
    'volume-high': [16, 20, 24, 32],
    'volume-low': [16, 20, 24, 32],
    'volume-medium': [16, 20, 24, 32],
    'volume-muted': [16, 20, 24, 32],
    'volume-none': [16, 20, 24, 32],
    'volume-silent': [16, 20, 24, 32],
}

// The frame to draw `name` with on a screen where it takes `screenSize` pixels: the frame Windows drew for
// that size, else the next bigger one (shrunk), else the biggest there is; 0 for an icon not kept here.
function frameFor(name, screenSize) {
    const kept = frames[name]
    if (kept === undefined) {
        return 0
    }

    const bigger = kept.find(size => size >= screenSize)
    return bigger === undefined ? kept[kept.length - 1] : bigger
}
