.pragma library

// The notification area (the system tray), after Windows 7. Plain JS, no Quickshell imports, so node can
// test it.
//
// Every icon ever seen is remembered, in the user's order, with what it should do (its "behavior", the
// words are Windows 7's):
//     'show'    Show icon and notifications: always on the bar.
//     'hide'    Hide icon and notifications: always behind the arrow, in the flyout.
//     'notify'  Only show notifications: in the flyout, but on the bar while it asks for attention.
// A new icon starts as 'notify', as on Windows 7. Icons are told apart by their key (`itemKey`).

const behaviors = ['show', 'hide', 'notify']
const defaultBehavior = 'notify'

// The answer of `gdbus call ... org.freedesktop.DBus.NameHasOwner <name>`: true or false, null when the
// text is not such an answer (gdbus missing or failing).
function nameHasOwner(output) {
    const answer = output.trim()
    if (answer === '(true,)') {
        return true
    }

    if (answer === '(false,)') {
        return false
    }

    return null
}

// What identifies an app's icon from one run to the next: its StatusNotifierItem id ('steam', 'nm-applet',
// 'discord_status_icon_1'), or its title when it has none.
function itemKey(id, title) {
    return id !== '' ? id : title
}

// The theme icon name of an icon given by name (`image://icon/<name>`), '' for any other picture (one the
// app draws itself, or a name with the app's own icon folder after it, which Quickshell looks up there).
function themeIconName(source) {
    const prefix = 'image://icon/'
    if (source.startsWith(prefix) === false || source.includes('?')) {
        return ''
    }

    return source.slice(prefix.length)
}

// The name a person knows the icon by: its tooltip's title, its title, then its id.
function displayName(id, title, tooltipTitle) {
    if (tooltipTitle !== '') {
        return tooltipTitle
    }

    return title !== '' ? title : id
}

// StatusNotifierItem descriptions may hold a little HTML; the tooltip shows plain text.
function plainText(text) {
    return text
        .replace(/<br\s*\/?>/gi, '\n')
        .replace(/<[^>]*>/g, '')
        .replace(/&nbsp;/g, ' ')
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, '\'')
        .replace(/&amp;/g, '&')
        .trim()
}

// The tooltip of an icon: its name, and the description on the lines under it when there is one that says
// more than the name.
function tooltipText(name, description) {
    const detail = plainText(description)
    if (detail === '' || detail === name) {
        return name
    }

    return name + '\n' + detail
}

// Reads the tray file: `{ "version": 1, "icons": [{ "key", "behavior", "name", "icon" }] }`. Whatever is
// wrong is left out and described in `problems`; an empty or missing file means no icon was seen yet.
function parseTray(text) {
    const result = { icons: [], problems: [] }
    if (text.trim() === '') {
        return result
    }

    let data = null
    try {
        data = JSON.parse(text)
    } catch (error) {
        result.problems.push('not valid JSON, starting fresh')
        return result
    }

    if (typeof data !== 'object' || data === null || Array.isArray(data)) {
        result.problems.push('not a JSON object, starting fresh')
        return result
    }

    if (data.icons === undefined) {
        return result
    }

    if (Array.isArray(data.icons) === false) {
        result.problems.push('icons: not a list, ignored')
        return result
    }

    for (const icon of data.icons) {
        const valid = typeof icon === 'object'
            && icon !== null
            && typeof icon.key === 'string'
            && icon.key !== ''
            && result.icons.some(known => known.key === icon.key) === false
        if (valid === false) {
            result.problems.push('icons: skipped ' + JSON.stringify(icon))
            continue
        }

        let behavior = icon.behavior
        if (behaviors.includes(behavior) === false) {
            result.problems.push(`icons: "${icon.key}" has an unknown behavior ${JSON.stringify(behavior)}, using "${defaultBehavior}"`)
            behavior = defaultBehavior
        }

        result.icons.push({
            key: icon.key,
            behavior: behavior,
            name: typeof icon.name === 'string' && icon.name !== '' ? icon.name : icon.key,
            icon: typeof icon.icon === 'string' ? icon.icon : '',
        })
    }

    return result
}

function serializeTray(icons) {
    return JSON.stringify({ version: 1, icons: icons }, null, 4) + '\n'
}

// The icons with the ones present now (`[{ key, name, icon }]`) remembered: a new one is added at the end
// as 'notify', a known one takes its current name and icon (an icon of '' keeps the last one, so an icon
// drawn by the app itself does not wipe a theme icon seen before). The same list when nothing changed.
function remember(icons, present) {
    let changed = false
    const result = icons.slice()
    for (const item of present) {
        const index = result.findIndex(icon => icon.key === item.key)
        if (index < 0) {
            result.push({ key: item.key, behavior: defaultBehavior, name: item.name, icon: item.icon })
            changed = true
            continue
        }

        const known = result[index]
        const icon = item.icon !== '' ? item.icon : known.icon
        if (known.name !== item.name || known.icon !== icon) {
            result[index] = { key: known.key, behavior: known.behavior, name: item.name, icon: icon }
            changed = true
        }
    }

    return changed ? result : icons
}

// Which present icons (`[{ key, attention }]`) go on the bar and which in the flyout, as two lists of keys
// in the user's order. An icon not remembered yet counts as new ('notify', after the others). With
// `showAll` ("Always show all icons and notifications on the taskbar") every icon is on the bar.
function arrange(icons, present, showAll) {
    const attention = new Map(present.map(item => [item.key, item.attention === true]))
    const ordered = icons.filter(icon => attention.has(icon.key))
    for (const item of present) {
        if (ordered.some(icon => icon.key === item.key) === false) {
            ordered.push({ key: item.key, behavior: defaultBehavior })
        }
    }

    const result = { shown: [], hidden: [] }
    for (const icon of ordered) {
        const onBar = showAll
            || icon.behavior === 'show'
            || (icon.behavior === 'notify' && attention.get(icon.key))
        if (onBar) {
            result.shown.push(icon.key)
        } else {
            result.hidden.push(icon.key)
        }
    }

    return result
}

// The icons after the one with `key` was dropped in a gap of the bar (`toShown`) or of the flyout. `keys`
// are that place's icons as shown during the drag (the dragged one keeps its place among them while it is
// out), `gap` the gap it was dropped in: 0 before the first, `keys.length` after the last. On the bar it
// becomes 'show'; into the flyout an icon that was always shown becomes 'notify' (Windows 7 does the same)
// and a 'hide' or 'notify' one stays as it was.
function placeIcon(icons, key, toShown, keys, gap) {
    const known = icons.find(icon => icon.key === key)
    const record = known === undefined
        ? { key: key, behavior: defaultBehavior, name: key, icon: '' }
        : known
    let behavior = record.behavior
    if (toShown) {
        behavior = 'show'
    } else if (behavior === 'show') {
        behavior = 'notify'
    }

    const others = keys.filter(item => item !== key)
    const from = keys.indexOf(key)
    const at = from >= 0 && gap > from ? gap - 1 : gap
    const rest = icons.filter(icon => icon.key !== key)
    let index = rest.length
    if (at < others.length) {
        index = rest.findIndex(icon => icon.key === others[at])
    } else if (others.length > 0) {
        const last = rest.findIndex(icon => icon.key === others[others.length - 1])
        index = last < 0 ? -1 : last + 1
    }

    if (index < 0) {
        index = rest.length
    }

    const placed = { key: record.key, behavior: behavior, name: record.name, icon: record.icon }
    return rest.slice(0, index).concat([placed], rest.slice(index))
}

function setBehavior(icons, key, behavior) {
    if (behaviors.includes(behavior) === false) {
        return icons
    }

    return icons.map(icon => icon.key === key
        ? { key: icon.key, behavior: behavior, name: icon.name, icon: icon.icon }
        : icon)
}

// "Restore default icon behaviors": every icon back to 'notify', the order and names kept.
function restoreDefaults(icons) {
    return icons.map(icon => ({ key: icon.key, behavior: defaultBehavior, name: icon.name, icon: icon.icon }))
}

// How many columns the flyout's grid has: as square as it can be, never empty.
function gridColumns(count) {
    return Math.max(1, Math.ceil(Math.sqrt(count)))
}

// Which gap of the flyout's grid the pointer at `x`, `y` is closest to, and where to draw its mark.
// `slots` are the icons in reading order as [{ left, top, right, bottom }], in the same coordinates. The
// row is the one the pointer is in (or the closest); in it, the gap before the first icon whose middle is
// right of the pointer, or after the row's last icon. Result: `{ gap, x, top, bottom }`, the mark a
// vertical line at `x`; null without slots.
function gridGapAt(x, y, slots) {
    if (slots.length === 0) {
        return null
    }

    let rowTop = slots[0].top
    let best = Infinity
    for (const slot of slots) {
        const distance = y < slot.top ? slot.top - y : (y > slot.bottom ? y - slot.bottom : 0)
        if (distance < best) {
            best = distance
            rowTop = slot.top
        }
    }

    const row = []
    for (let index = 0; index < slots.length; index++) {
        if (slots[index].top === rowTop) {
            row.push(index)
        }
    }

    for (const index of row) {
        const slot = slots[index]
        if (x < (slot.left + slot.right) / 2) {
            return { gap: index, x: slot.left, top: slot.top, bottom: slot.bottom }
        }
    }

    const last = slots[row[row.length - 1]]
    return { gap: row[row.length - 1] + 1, x: last.right, top: last.top, bottom: last.bottom }
}
