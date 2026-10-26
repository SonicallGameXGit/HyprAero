pragma Singleton

import Quickshell
import QtQuick

// Resolves a window's class (its Wayland app id) to an icon: the desktop entry's icon first, then an icon named like
// the class, or '' when the theme has none (the frame then keeps Windows 7's generic application icon). The same
// lookup as the bar's `services/AppIcons.qml`; modules share no code but the design's.
Singleton {
    // Whether the desktop entries have been read; asked before that, every lookup finds nothing.
    readonly property bool ready: DesktopEntries.applications.values.length > 0

    function pathFor(appId: string): string {
        if (ready === false) {
            return ''
        }

        const entry = DesktopEntries.heuristicLookup(appId)
        if (entry !== null && entry !== undefined) {
            const fromEntry = Quickshell.iconPath(entry.icon, true)
            if (fromEntry !== '') {
                return fromEntry
            }
        }

        return Quickshell.iconPath(appId, true)
    }
}
