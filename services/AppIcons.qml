pragma Singleton

import Quickshell
import QtQuick

// Resolves a window's app id (its Wayland class) to an icon file: the desktop entry's icon first,
// then an icon named like the app id, or '' when the theme has none (the bar then draws a generic window).
Singleton {
    function pathFor(appId: string): string {
        // Reading the list makes every binding that calls this re-run once the desktop entries
        // have finished loading; asked too early, the lookup finds nothing and never asks again.
        const loaded = DesktopEntries.applications.values.length
        if (loaded === 0) {
            return ''
        }

        // `Apps.appFor` also finds apps whose window is not the program their entry starts (Wine's).
        const app = Apps.appFor(appId)
        const entry = app === '' ? null : DesktopEntries.byId(app)
        if (entry !== null && entry !== undefined) {
            const fromEntry = Quickshell.iconPath(entry.icon, true)
            if (fromEntry !== '') {
                return fromEntry
            }
        }

        return Quickshell.iconPath(appId, true)
    }

    // An icon of the theme by name ('folder-documents', a desktop entry's icon), '' when it has none.
    function forName(name: string): string {
        if (name === '') {
            return ''
        }

        return Quickshell.iconPath(name, true)
    }
}
