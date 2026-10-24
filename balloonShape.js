.pragma library

// The outline of Windows 7's notification balloon as an SVG path, for `Balloon.qml`'s `PathSvg`. Plain JS, no
// Quickshell imports, so node can test it.
//
// A rounded box with a stem (its pointed tail) on its top or bottom edge. Windows 7's stem stands against a
// "wall": one of its sides is upright, flush with the point, and the other slants back to the edge; the
// point is the end nearest the corner the balloon points at. A centred stem has two slanted sides.
//
// Every coordinate is moved in by half the stroke, so a 1px outline falls on whole pixels and stays sharp.

// `width`, `height`: the whole balloon, stem included. `stem`: { edge ('top', 'bottom' or 'none'), side
// ('left', 'center' or 'right'), width, height, inset (from the box's side to the stem's upright side) }.
function outline(width, height, radius, stroke, stem) {
    const half = stroke / 2
    const hasStem = stem.edge === 'top' || stem.edge === 'bottom'
    const left = half
    const right = width - half
    const top = (hasStem && stem.edge === 'top' ? stem.height : 0) + half
    const bottom = height - (hasStem && stem.edge === 'bottom' ? stem.height : 0) - half
    // The corners never grow past half the box, so a short balloon stays a box.
    const r = Math.max(0, Math.min(radius, (right - left) / 2, (bottom - top) / 2))

    // Where the stem leaves the edge (`near` is nearest the corner), and its point, before the stroke.
    const stemPoints = () => {
        if (stem.side === 'left') {
            const near = left + stem.inset
            return { near: near, far: near + stem.width, point: near }
        }

        if (stem.side === 'right') {
            const near = right - stem.inset
            return { near: near, far: near - stem.width, point: near }
        }

        const middle = width / 2
        return { near: middle - stem.width / 2, far: middle + stem.width / 2, point: middle }
    }

    const parts = [`M ${left + r} ${top}`]
    if (hasStem && stem.edge === 'top') {
        // Drawn left to right along the top edge.
        const points = stemPoints()
        const first = Math.min(points.near, points.far)
        const last = Math.max(points.near, points.far)
        parts.push(`L ${first} ${top}`, `L ${points.point} ${half}`, `L ${last} ${top}`)
    }

    parts.push(`L ${right - r} ${top}`)
    parts.push(`A ${r} ${r} 0 0 1 ${right} ${top + r}`)
    parts.push(`L ${right} ${bottom - r}`)
    parts.push(`A ${r} ${r} 0 0 1 ${right - r} ${bottom}`)
    if (hasStem && stem.edge === 'bottom') {
        // Drawn right to left along the bottom edge.
        const points = stemPoints()
        const first = Math.max(points.near, points.far)
        const last = Math.min(points.near, points.far)
        parts.push(`L ${first} ${bottom}`, `L ${points.point} ${height - half}`, `L ${last} ${bottom}`)
    }

    parts.push(`L ${left + r} ${bottom}`)
    parts.push(`A ${r} ${r} 0 0 1 ${left} ${bottom - r}`)
    parts.push(`L ${left} ${top + r}`)
    parts.push(`A ${r} ${r} 0 0 1 ${left + r} ${top}`)
    parts.push('Z')

    return parts.join(' ')
}
