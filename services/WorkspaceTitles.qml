pragma Singleton

import Quickshell
import QtQuick
import 'iconOverrides.js' as IconList
import 'workspaceTitles.js' as TitleList

// The titles of the workspaces (`bar.workspaceTitles` in `config.json`, `services/workspaceTitles.js`), and
// whether the dialog that sets one is open and for which workspace. Only the user sets a title: nothing here
// reads a window's or an app's name.
Singleton {
    id: root

    readonly property var titles: Config.bar.workspaceTitles
    readonly property int maxLength: TitleList.maxLength

    // The "Set title..." dialog is open for workspace `dialogId`.
    property bool dialogOpen: false
    property int dialogId: 0

    function titleOf(id: int): string {
        return TitleList.titleOf(titles, id)
    }

    // Titles workspace `id`; empty text takes its title away. Written to the config file at once.
    function set(id: int, text: string): void {
        const next = TitleList.withTitle(titles, id, text)
        if (next !== titles) {
            Config.set('bar', 'workspaceTitles', next)
        }
    }

    function openDialog(id: int): void {
        dialogId = id
        dialogOpen = true
    }

    function closeDialog(): void {
        dialogOpen = false
    }

    // The bar's workspace buttons were reordered (slot `from` to slot `to`): the titles go with them, as the
    // icons do.
    function reorder(ids: var, from: int, to: int): void {
        const moved = IconList.reorderedWorkspaces(titles, ids, from, to)
        if (JSON.stringify(moved) !== JSON.stringify(titles)) {
            Config.set('bar', 'workspaceTitles', moved)
        }
    }
}
