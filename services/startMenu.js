.pragma library

// What the start menu lists and in which order. An app is a plain object:
// `{ id, name, genericName, comment, keywords, command }` (`keywords` and `command` are lists of text).

function scoreOf(scores, id) {
    const score = scores[id]
    return typeof score === 'number' ? score : 0
}

function compareNames(a, b) {
    const left = a.name.toLowerCase()
    const right = b.name.toLowerCase()
    if (left !== right) {
        return left < right ? -1 : 1
    }

    return a.id < b.id ? -1 : (a.id > b.id ? 1 : 0)
}

// Most used first; apps with the same score (all the unused ones) A to Z.
function compareByUse(a, b, scores) {
    const difference = scoreOf(scores, b.id) - scoreOf(scores, a.id)
    if (difference !== 0) {
        return difference
    }

    return compareNames(a, b)
}

// The two lists of the menu without a search: the featured apps, and every other app. Both by use, then
// A to Z. A featured id without an installed app is left out (the app may come back).
function buildSections(apps, scores, featuredIds) {
    const featured = []
    const others = []
    for (const app of apps) {
        if (featuredIds.includes(app.id)) {
            featured.push(app)
        } else {
            others.push(app)
        }
    }

    const byUse = (a, b) => compareByUse(a, b, scores)
    featured.sort(byUse)
    others.sort(byUse)

    return { featured: featured, others: others }
}

// Where `query` (lower case) is found in the app, as `{ tier, index }`, lower is better; null when it is
// not found. The name counts most, then a word of the name, then what the app is about.
function matchApp(app, query) {
    const name = app.name.toLowerCase()
    if (name.startsWith(query)) {
        return { tier: 0, index: 0 }
    }

    const words = name.split(/[\s\-_.]+/)
    let offset = 0
    for (const word of words) {
        const at = name.indexOf(word, offset)
        if (word !== '' && word.startsWith(query)) {
            return { tier: 1, index: at }
        }

        offset = at + word.length
    }

    const inName = name.indexOf(query)
    if (inName >= 0) {
        return { tier: 2, index: inName }
    }

    const about = [app.genericName].concat(app.keywords)
    for (const text of about) {
        const index = text.toLowerCase().indexOf(query)
        if (index >= 0) {
            return { tier: 3, index: index }
        }
    }

    const inComment = app.comment.toLowerCase().indexOf(query)
    if (inComment >= 0) {
        return { tier: 4, index: inComment }
    }

    // The program itself (`firefox`, `org.gnome.Nautilus`), for those who know it by that name.
    const program = app.command.length > 0 ? app.command[0].split('/').pop() : ''
    for (const text of [program, app.id]) {
        const index = text.toLowerCase().indexOf(query)
        if (index >= 0) {
            return { tier: 5, index: index }
        }
    }

    return null
}

// The apps matching the search, best first: by where the text was found, then by use, then by how early
// it was found, then A to Z. An empty search matches nothing (the menu shows its sections instead).
function searchApps(apps, queryText, scores) {
    const query = queryText.trim().toLowerCase()
    if (query === '') {
        return []
    }

    const found = []
    for (const app of apps) {
        const match = matchApp(app, query)
        if (match !== null) {
            found.push({ app: app, tier: match.tier, index: match.index })
        }
    }

    found.sort((a, b) => {
        if (a.tier !== b.tier) {
            return a.tier - b.tier
        }

        const difference = scoreOf(scores, b.app.id) - scoreOf(scores, a.app.id)
        if (difference !== 0) {
            return difference
        }

        if (a.index !== b.index) {
            return a.index - b.index
        }

        return compareNames(a.app, b.app)
    })

    return found.map(item => item.app)
}

// Runs the arguments in a terminal: the user's choice of `xdg-terminal-exec` when installed, then
// $TERMINAL, then the first common terminal found. No arguments opens a plain terminal. The arguments are
// handed to `sh` as its own parameters, so nothing in them is ever read as shell code.
const terminalScript = [
    'if command -v xdg-terminal-exec >/dev/null 2>&1; then exec xdg-terminal-exec "$@"; fi',
    'if [ -n "$TERMINAL" ]; then if [ $# -eq 0 ]; then exec "$TERMINAL"; fi; exec "$TERMINAL" -e "$@"; fi',
    'for terminal in kitty foot alacritty wezterm konsole xterm; do',
    '    if command -v "$terminal" >/dev/null 2>&1; then',
    '        if [ $# -eq 0 ]; then exec "$terminal"; fi',
    '        case "$terminal" in',
    '            kitty|foot) exec "$terminal" "$@" ;;',
    '            wezterm) exec wezterm start -- "$@" ;;',
    '            *) exec "$terminal" -e "$@" ;;',
    '        esac',
    '    fi',
    'done',
    'echo "no terminal found" >&2',
    'exit 127',
].join('\n')

function terminalCommand(args) {
    return ['sh', '-c', terminalScript, 'sh'].concat(args)
}

// The command that starts an app (its desktop entry's command, already without field codes).
function launchCommand(command, inTerminal) {
    if (inTerminal) {
        return terminalCommand(command)
    }

    return command
}

// The rows of the list, top to bottom: `{ kind: 'header' | 'app' | 'separator' | 'hint', section, app }`.
// The menu is read from the search field upwards, so each section's header sits under its apps: from the
// bottom, "Featured" and the featured apps (a hint when none are featured yet), the dark line, "Most used"
// and every other app above it.
function menuRows(sections) {
    const rows = []
    for (const app of sections.others) {
        rows.push({ kind: 'app', section: 'others', app: app })
    }

    rows.push({ kind: 'header', section: 'others' })
    rows.push({ kind: 'separator', section: '' })
    if (sections.featured.length === 0) {
        rows.push({ kind: 'hint', section: 'featured' })
    }

    for (const app of sections.featured) {
        rows.push({ kind: 'app', section: 'featured', app: app })
    }

    rows.push({ kind: 'header', section: 'featured' })
    return rows
}

// The rows of a search: the results with their header under them, or a hint that nothing matched.
function searchRows(results) {
    if (results.length === 0) {
        return [{ kind: 'hint', section: 'search' }]
    }

    const rows = []
    for (const app of results) {
        rows.push({ kind: 'app', section: 'search', app: app })
    }

    rows.push({ kind: 'header', section: 'search' })
    return rows
}

// The second line of an app's row: its description, or the program it runs when it has none (as the old
// launcher did), '' when there is neither.
function appDetail(app) {
    if (app.comment.trim() !== '') {
        return app.comment.trim()
    }

    if (app.command.length > 0) {
        return app.command[0]
    }

    return ''
}

// The next app row from `from` going `step` (+1 or -1) through `rows`; `from` itself when there is none.
// `from` may be just outside the list (-1 or its length) to start at an end.
function nextAppRow(rows, from, step) {
    for (let index = from + step; index >= 0 && index < rows.length; index += step) {
        if (rows[index].kind === 'app') {
            return index
        }
    }

    return from
}
