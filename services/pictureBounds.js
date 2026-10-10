.pragma library

// The box around the drawn pixels of a captured window picture, as { x, y, width, height } fractions of the
// picture (0 to 1), or null when nothing is drawn. Hyprland leaves the part of a window it did not draw
// (off the monitor) transparent, and where that part lands does not follow the window's position, so the
// picture itself is read. `data` is RGBA bytes row by row; a pixel counts from an alpha of `threshold`.
function opaqueBounds(data, width, height, threshold) {
    let left = width
    let top = height
    let right = -1
    let bottom = -1
    for (let y = 0; y < height; y++) {
        for (let x = 0; x < width; x++) {
            if (data[(y * width + x) * 4 + 3] < threshold) {
                continue
            }

            left = Math.min(left, x)
            right = Math.max(right, x)
            top = Math.min(top, y)
            bottom = Math.max(bottom, y)
        }
    }

    if (right < 0) {
        return null
    }

    return {
        x: left / width,
        y: top / height,
        width: (right + 1 - left) / width,
        height: (bottom + 1 - top) / height,
    }
}
