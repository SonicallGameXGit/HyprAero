.pragma library

// The flashing of a taskbar button whose app asks for attention (`TaskbarButton.qml`), as Windows 7 flashes
// one: orange, plain, orange, ... `flashes` times, then orange until the app has the user's attention. Plain
// JS, no Quickshell imports, so node can test it.
//
// `step` counts the flash intervals since the app asked (0: the moment it asked). `flashes` 0 flashes for as
// long as it asks, as Windows' ForegroundFlashCount 0 does.

// Whether the button is orange at `step`.
function flashLit(step, flashes) {
    if (flashDone(step, flashes)) {
        return true
    }

    return step % 2 === 0
}

// Whether the flashing is over at `step`, the button staying orange from then on.
function flashDone(step, flashes) {
    return flashes > 0 && step >= 2 * (flashes - 1)
}
