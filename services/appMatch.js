.pragma library

// Which app (desktop entry) a window belongs to when Quickshell's own lookup finds none. Plain JS, no
// Quickshell imports, so node can test it.
//
// Quickshell matches a window's class only with an entry's id and `StartupWMClass`. That misses apps whose
// window is not the program the entry starts: a Wine app's entry names its launcher
// (`google_ads_editor_launcher.exe`), its window is the program (`google_ads_editor.exe`). Such a class is
// still the app's name written another way, so the class, the entry's name, id and startup class are
// compared with case, punctuation and a Windows `.exe` left out.

// `Google Ads Editor`, `google_ads_editor.exe` and `Google-Ads-Editor.desktop` are all `googleadseditor`.
// Letters beyond ASCII are kept as they are: Qt's JS engine ignores `\p{L}` without a word.
function matchKey(text) {
    if (typeof text !== 'string') {
        return ''
    }

    return text.toLowerCase()
        .replace(/\.(exe|desktop)$/, '')
        .replace(/[^a-z0-9\u0080-\uffff]/g, '')
}

// `{ key: id }` for `entries` (`[{ id, name, startupClass }]`), each entry under the keys of its name, its
// id (and the id's last part, for Wine's `wine-Programs-<folder>-<name>.desktop`) and its startup class. A
// key two apps share names neither ('' then). A plain object, not Map: it is read on the shell's thread
// for every window (`iconOverrides.js` says why).
function classIndex(entries) {
    const index = Object.create(null)
    for (const entry of entries) {
        const keys = [
            matchKey(entry.name),
            matchKey(entry.id),
            matchKey(entry.id.slice(entry.id.lastIndexOf('-') + 1)),
            matchKey(entry.startupClass),
        ]
        const seen = []
        for (const key of keys) {
            if (key.length < 3 || seen.includes(key)) {
                continue
            }

            seen.push(key)
            const known = index[key]
            index[key] = known === undefined || known === entry.id ? entry.id : ''
        }
    }

    return index
}

// The app id of a window's class in the index, '' when none or more than one app fits.
function appForClass(index, appClass) {
    const id = index[matchKey(appClass)]
    return id === undefined ? '' : id
}
