.pragma library

// Workspace titles: short names the user gives workspaces, kept in the config file (`bar.workspaceTitles`,
// `config/settings.js`) as `{ "<number>": "<title>" }`. Plain JS, no Quickshell imports, so node can test it.

// The most a title holds: the button is small, and a long one would only be cut off.
const maxLength = 24

// The title of workspace `id`, '' when it has none.
function titleOf(titles, id) {
    const title = titles[String(id)]
    return typeof title === 'string' ? title : ''
}

// The titles with workspace `id` titled `text` (trimmed and cut to `maxLength`); empty text takes the title
// away. The same object when nothing changes, so a caller can tell by `===`.
function withTitle(titles, id, text) {
    const title = text.trim().slice(0, maxLength).trim()
    if (titleOf(titles, id) === title) {
        return titles
    }

    const result = Object.assign({}, titles)
    if (title === '') {
        delete result[String(id)]
    } else {
        result[String(id)] = title
    }

    return result
}
