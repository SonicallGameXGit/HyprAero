pragma ComponentBehavior: Bound

import QtQuick
import qs.design
import qs.services
import '../../services/workspaceList.js' as WorkspaceList

// The workspace buttons, placed by hand so one can be dragged along the bar to reorder them, as Windows 7
// reorders its buttons: the held one follows the pointer sideways only and stops dead at `leftLimit` and
// `rightLimit` (the pins and the tray), the others glide aside to make room (`WorkspaceList.reorderSlot`),
// and let go it glides into its slot, past either end into the first or the last. Then Hyprland renumbers
// the workspaces (`Workspaces.reorder`). Covering another button by at least `joinShare` of it and resting
// there for `joinDelay`, as a browser tab dropped onto another, it joins it instead
// (`WorkspaceList.joinCandidate`; moving goes on as before meanwhile): that button lights up, the held one
// turns see-through over it, and let go its windows go to that workspace (`Workspaces.moveWorkspace`), the
// others gliding back. Until Hyprland has done either, the buttons keep showing what they showed when the drag
// started (`frozen`), so nothing flickers in between; the workspaces' own icons go with their buttons then
// (`IconOverrides.reorderWorkspaces`), a joined workspace keeping its own.
Item {
    id: root

    // How many buttons (held still by the bar while something is dragged).
    property int buttonCount: 0
    // The workspace a window dragged over the bar would go to; its button lights up.
    property int dropTarget: 0
    // How far the held button may go, in this item's parent.
    property real leftLimit: -Infinity
    property real rightLimit: Infinity

    readonly property int slotWidth: 72
    readonly property real pitch: slotWidth + Theme.taskbarItemGap
    readonly property alias count: buttons.count
    // The held button's index (-1: none), the slot it would go to, the button it would join instead (-1:
    // none), and where it is while held.
    property int dragFrom: -1
    property int dragTo: -1
    property int joinTarget: -1
    // The button the pointer rests by, waiting for `joinDelay` before it is joined (-1: none).
    property int joinWaiting: -1
    property real dragStart: 0
    property real dragX: 0
    property bool held: false
    // Set just before the held button is let go, so it glides from where it was dropped.
    property bool glideHeld: false
    property bool gliding: false
    // The buttons go to their own slots at once, not gliding: the reorder is done.
    property bool snapping: false
    // The entries when the drag started, and what each slot should show once Hyprland has caught up (an
    // address of one of its windows, '' for none, null when it does not matter).
    property var frozen: []
    property var expected: []
    // The reorder whose workspace icons still have to follow (`{ ids, from, to }`), null for none.
    property var iconMove: null
    readonly property bool reordering: dragFrom >= 0
    readonly property real minX: leftLimit - x
    readonly property real maxX: rightLimit - x - slotWidth
    // How long the bar waits for Hyprland before it shows the live entries anyway.
    readonly property int catchUpLimit: 1500
    // How much of another button the held one must cover to join it, and how long the pointer must rest.
    readonly property real joinShare: 1 / 3
    readonly property int joinDelay: 400

    signal buttonHovered(var button)
    // A button was taken: the bar closes what is open over the buttons.
    signal reorderBegan()
    // A right click on a button; `at` is in the window.
    signal menuRequested(var entry, point at)

    function buttonAt(index: int): var {
        return buttons.itemAt(index)
    }

    function slotOf(index: int): int {
        return reordering ? WorkspaceList.reorderSlot(index, dragFrom, dragTo) : index
    }

    function begin(index: int): void {
        if (reordering) {
            return
        }

        frozen = Workspaces.entries.slice(0, buttonCount)
        expected = []
        dragFrom = index
        dragTo = index
        joinTarget = -1
        joinWaiting = -1
        dragStart = index * pitch
        dragX = dragStart
        glideHeld = false
        held = true
        reorderBegan()
    }

    function move(offset: real): void {
        if (held === false) {
            return
        }

        dragX = Math.min(Math.max(dragStart + offset, minX), maxX)
        dragTo = WorkspaceList.reorderTarget(dragX + slotWidth / 2, slotWidth / 2, pitch, frozen.length)
        const join = WorkspaceList.joinCandidate(dragX, dragFrom, dragTo, frozen.length, pitch, slotWidth, joinShare)
        if (join === joinWaiting && join >= 0) {
            return
        }

        // Somewhere else: whatever was joined or waited for is let go, and a new wait starts.
        joinTarget = -1
        joinWaiting = join
        if (join >= 0) {
            joinTimer.restart()
        } else {
            joinTimer.stop()
        }
    }

    function end(): void {
        if (held === false) {
            return
        }

        joinTimer.stop()
        joinWaiting = -1
        glideHeld = true
        // Joining: the others glide back to their own slots, the held one onto the joined one.
        if (joinTarget >= 0) {
            dragTo = dragFrom
        }

        held = false
        gliding = true
        glideTimer.restart()
        if (joinTarget >= 0) {
            const next = frozen.map(() => null)
            const windows = frozen[dragFrom].windows
            next[dragFrom] = ''
            next[joinTarget] = windows.length > 0 ? windows[0].address : null
            expected = next
            caughtUpTimer.restart()
            Workspaces.moveWorkspace(frozen[dragFrom].id, frozen[joinTarget].id)
            return
        }

        if (dragTo === dragFrom) {
            return
        }

        const next = frozen.map(() => '')
        for (let index = 0; index < frozen.length; index++) {
            const windows = frozen[index].windows
            next[slotOf(index)] = windows.length > 0 ? windows[0].address : ''
        }

        expected = next
        caughtUpTimer.restart()
        const ids = frozen.map(entry => entry.id)
        if (Workspaces.reorder(ids, dragFrom, dragTo)) {
            iconMove = { ids: ids, from: dragFrom, to: dragTo }
        }
    }

    // Every slot shows what it should: Hyprland has done the renumbering.
    function caughtUp(): bool {
        const entries = Workspaces.entries
        for (let slot = 0; slot < expected.length; slot++) {
            if (slot >= entries.length) {
                return false
            }

            const windows = entries[slot].windows
            const wanted = expected[slot]
            if (wanted === null) {
                continue
            }

            if (wanted === '' ? windows.length > 0 : windows.every(window => window.address !== wanted)) {
                return false
            }
        }

        return true
    }

    // Back to the live entries once the glide is over and Hyprland has caught up (or `catchUpLimit` passed).
    function finishIfDone(): void {
        if (reordering === false || held || gliding) {
            return
        }

        if (expected.length > 0 && caughtUpTimer.running && caughtUp() === false) {
            return
        }

        caughtUpTimer.stop()
        if (iconMove !== null) {
            IconOverrides.reorderWorkspaces(iconMove.ids, iconMove.from, iconMove.to)
            iconMove = null
        }

        snapping = true
        dragFrom = -1
        dragTo = -1
        joinTarget = -1
        frozen = []
        expected = []
        snapping = false
    }

    width: Math.max(buttonCount * pitch - Theme.taskbarItemGap, 0)

    Timer {
        id: glideTimer

        interval: Theme.motionSoft
        onTriggered: {
            root.gliding = false
            root.finishIfDone()
        }
    }

    Timer {
        id: joinTimer

        interval: root.joinDelay
        onTriggered: {
            if (root.held) {
                root.joinTarget = root.joinWaiting
            }
        }
    }

    Timer {
        id: caughtUpTimer

        interval: root.catchUpLimit
        onTriggered: root.finishIfDone()
    }

    Connections {
        target: Workspaces

        function onEntriesChanged(): void {
            root.finishIfDone()
        }
    }

    Repeater {
        id: buttons

        // Counting only, so a change inside one entry (an icon) does not rebuild every button.
        model: root.buttonCount

        WorkspaceButton {
            id: button

            required property int index

            readonly property bool dragged: root.dragFrom === index

            x: {
                if (dragged && root.held) {
                    return root.dragX
                }

                if (dragged && root.joinTarget >= 0) {
                    return root.joinTarget * root.pitch
                }

                return root.slotOf(index) * root.pitch
            }
            z: dragged ? 1 : 0
            // Over a button it would join, see-through so that one shows; let go, it fades into it.
            opacity: {
                if (dragged === false || root.joinTarget < 0) {
                    return 1
                }

                return root.held ? Theme.dragImageOpacity : 0
            }
            width: root.slotWidth
            // The bar's full height, as Windows 7's buttons.
            height: root.height
            // The count can lag behind the list during a drag.
            entry: {
                if (root.reordering && index < root.frozen.length) {
                    return root.frozen[index]
                }

                return index < Workspaces.entries.length ? Workspaces.entries[index] : null
            }
            highlighted: (entry !== null && root.dropTarget === entry.id) || root.joinTarget === index
            onClicked: Workspaces.switchTo(entry.id)
            onHoveredChanged: root.buttonHovered(button)
            onReorderStarted: root.begin(index)
            onReorderMoved: offset => root.move(offset)
            onReorderEnded: root.end()
            onMenuRequested: at => {
                if (root.reordering === false && button.entry !== null) {
                    root.menuRequested(button.entry, button.mapToItem(null, at))
                }
            }

            Behavior on opacity {
                NumberAnimation { duration: Theme.motionSoft; easing.type: Easing.OutCubic }
            }

            // Nearly linear, so the farther it goes the faster: a spring without the wobble.
            Behavior on x {
                enabled: root.snapping === false && (button.dragged === false || root.glideHeld)

                NumberAnimation { duration: Theme.motionSoft; easing.type: Easing.OutSine }
            }
        }
    }
}
