pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick
import 'tray.js' as TrayList

// The notification area (the system tray), after Windows 7: the apps' StatusNotifierItem icons and the
// shell's own system icons (`SystemIcons`), which of them sit on the bar and which wait behind the arrow in the flyout, and what each should do
// (`services/tray.js`). Every icon ever seen is remembered in `$XDG_STATE_HOME/hypraero/tray.json`, so the
// "Customize" page can list it while its app is not running. Also which screen's flyout is open (one at a
// time) and whether the "Customize" page is.
//
// The tray's StatusNotifierWatcher (the D-Bus name apps register their icons with) is kept in a process of
// its own, `tools/trayWatcher.qml`, started here when no watcher is on the bus: Electron apps register
// their icon only once, so a watcher inside the shell lost their icons at every shell restart. The tray is
// read only once a watcher is there (or after `watcherWait`), otherwise this shell would take the name
// itself. Without gdbus the shell is its own watcher, as Quickshell does by default.
Singleton {
    id: root

    readonly property string trayDragFormat: 'application/x-hypraero-tray'

    // Every icon ever seen, in the user's order: `[{ key, behavior, name, icon }]`.
    property var icons: []
    // Nothing is written before the file has been read, so a slow read never overwrites it.
    property bool loaded: false

    // A watcher is on the bus (or the wait for one is over): the tray can be read.
    property bool hostReady: false
    readonly property int watcherWait: 3000
    property real watcherAskedAt: 0

    // The apps' icons now, as Quickshell's items, then the shell's own (`SystemIcons`, items shaped like
    // them). Quickshell starts its tray (and its own watcher when none is there) the first time `SystemTray`
    // is read. An applet that only does what one of the shell's icons does (nm-applet) is left out.
    readonly property var appItems: hostReady
        ? SystemTray.items.values.filter(item => SystemIcons.hiddenApps.includes(keyOf(item)) === false)
        : []
    readonly property var items: appItems.concat(SystemIcons.items)
    readonly property var present: items.map(item => ({
        key: keyOf(item),
        name: nameOf(item),
        // Only a theme icon is worth keeping for when the app is not running; a picture drawn by the app
        // lives only as long as the app.
        icon: item.icon.startsWith('image://icon/') ? item.icon : '',
        attention: item.system === undefined && item.status === Status.NeedsAttention,
    }))
    readonly property var layout: TrayList.arrange(icons, present, Config.tray.showAll)
    // The items on the bar and in the flyout, in order.
    readonly property var shown: itemsFor(layout.shown)
    readonly property var hidden: itemsFor(layout.hidden)

    // The screen whose flyout is open ('' when none). A flyout opened by dragging an icon over the arrow
    // does not take the keyboard (a popup cannot grab during a drag) and closes when the drag ends.
    property string flyoutScreen: ''
    property bool flyoutByDrag: false
    property real flyoutClosedAt: 0
    // A click outside the flyout closes it before the click arrives, so a click on the arrow itself would
    // open it again at once; within this long after closing, it does not.
    readonly property int reopenGuard: 300
    property bool customizeOpen: false

    onPresentChanged: {
        if (loaded) {
            update(TrayList.remember(icons, present))
        }
    }

    function keyOf(item: var): string {
        return TrayList.itemKey(item.id, item.title)
    }

    function nameOf(item: var): string {
        return TrayList.displayName(item.id, item.title, item.tooltipTitle)
    }

    // The picture to draw for an icon (an item's `icon`, or one remembered): '' when it names an icon the
    // theme does not have, so a generic picture is drawn instead of the theme's "missing" one.
    function pictureOf(source: string): string {
        const name = TrayList.themeIconName(source)
        if (name !== '' && Quickshell.iconPath(name, true) === '') {
            return ''
        }

        return source
    }

    function tooltipOf(item: var): string {
        if (item.system !== undefined) {
            return SystemIcons.tooltipOf(item.system)
        }

        return TrayList.tooltipText(nameOf(item), item.tooltipDescription)
    }

    // Whether a remembered icon belongs on the "Customize" page now: not an applet the shell's own icons
    // replace, and a system icon only while it is on and can show.
    function listed(key: string): bool {
        if (TrayList.isSystemKey(key)) {
            return SystemIcons.items.some(item => item.id === key)
        }

        return SystemIcons.hiddenApps.includes(key) === false
    }

    function itemsFor(keys: var): var {
        const byKey = new Map(items.map(item => [keyOf(item), item]))
        const result = []
        for (const key of keys) {
            const item = byKey.get(key)
            if (item !== undefined) {
                result.push(item)
            }
        }

        return result
    }

    function behaviorOf(key: string): string {
        const icon = icons.find(item => item.key === key)
        return icon === undefined ? TrayList.defaultBehaviorOf(key) : icon.behavior
    }

    // A dragged icon dropped in `gap` of the bar's icons (`toShown`) or of the flyout's, as shown during the
    // drag (`keys`).
    function place(key: string, toShown: bool, keys: var, gap: int): void {
        update(TrayList.placeIcon(icons, key, toShown, keys, gap))
    }

    function setBehavior(key: string, behavior: string): void {
        update(TrayList.setBehavior(icons, key, behavior))
    }

    function restoreDefaults(): void {
        update(TrayList.restoreDefaults(icons))
    }

    function setShowAll(on: bool): void {
        Config.set('tray', 'showAll', on)
    }

    function update(changed: var): void {
        if (TrayList.serializeTray(changed) === TrayList.serializeTray(icons)) {
            return
        }

        icons = changed
        if (loaded) {
            saveTimer.restart()
        }
    }

    // What a click, a middle click and the wheel do are the app's own; for the shell's own icons,
    // `SystemIcons` says (a click on one of them opens its flyout or menu instead, see `TrayIcon`).
    function activate(item: var): void {
        if (item.system === undefined) {
            item.activate()
        }
    }

    function secondaryActivate(item: var): void {
        if (item.system !== undefined) {
            SystemIcons.secondary(item.system)
            return
        }

        item.secondaryActivate()
    }

    function scroll(item: var, delta: int, horizontal: bool): void {
        if (item.system !== undefined) {
            if (horizontal === false) {
                SystemIcons.scroll(item.system, delta)
            }

            return
        }

        item.scroll(delta, horizontal)
    }

    // An entry of an app's menu was chosen.
    function trigger(entry: var): void {
        entry.triggered()
    }

    function openFlyout(screenName: string, byDrag: bool): void {
        if (flyoutScreen === screenName) {
            return
        }

        flyoutByDrag = byDrag
        flyoutScreen = screenName
    }

    function closeFlyout(): void {
        if (flyoutScreen === '') {
            return
        }

        flyoutScreen = ''
        flyoutByDrag = false
        flyoutClosedAt = Date.now()
    }

    // The arrow was clicked on this screen.
    function toggleFlyout(screenName: string): void {
        if (flyoutScreen !== '') {
            closeFlyout()
            return
        }

        if (Date.now() - flyoutClosedAt < reopenGuard) {
            return
        }

        openFlyout(screenName, false)
    }

    // Asked for while it is open (on another workspace, behind a window), it is shown again where the user
    // is.
    function openCustomize(): void {
        closeFlyout()
        customizeOpen = false
        customizeOpen = true
    }

    function apply(text: string): void {
        const parsed = TrayList.parseTray(text)
        for (const problem of parsed.problems) {
            console.warn('Tray: tray.json: ' + problem)
        }

        icons = parsed.icons
        loaded = true
        update(TrayList.remember(icons, present))
        if (parsed.problems.length > 0) {
            saveTimer.restart()
        }
    }

    // Whether some process holds the watcher's name; if none does, the watcher tool is started once and
    // asked again until it does.
    function watcherAnswered(output: string): void {
        if (hostReady) {
            return
        }

        const owned = TrayList.nameHasOwner(output)
        if (owned === null) {
            console.warn('Tray: cannot ask D-Bus for a tray watcher (is gdbus installed?), the shell keeps its own')
            hostReady = true
            return
        }

        if (owned) {
            hostReady = true
            return
        }

        if (watcherAskedAt === 0) {
            watcherAskedAt = Date.now()
            Quickshell.execDetached(['qs', '-n', '-p', Quickshell.shellPath('tools/trayWatcher.qml')])
        }

        if (Date.now() - watcherAskedAt >= watcherWait) {
            console.warn('Tray: the tray watcher did not start, the shell keeps its own (icons of Electron apps go at a restart)')
            hostReady = true
            return
        }

        watcherRetry.restart()
    }

    Process {
        id: watcherCheck

        command: [
            'gdbus',
            'call',
            '--session',
            '--dest',
            'org.freedesktop.DBus',
            '--object-path',
            '/org/freedesktop/DBus',
            '--method',
            'org.freedesktop.DBus.NameHasOwner',
            'org.kde.StatusNotifierWatcher',
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.watcherAnswered(text)
        }
    }

    // gdbus that never answers (or cannot start) never keeps the tray empty.
    Timer {
        interval: root.watcherWait + 1000
        running: root.hostReady === false
        onTriggered: {
            if (root.hostReady === false) {
                console.warn('Tray: no answer about a tray watcher, the shell keeps its own')
                root.hostReady = true
            }
        }
    }

    Timer {
        id: watcherRetry

        interval: 100
        onTriggered: watcherCheck.running = true
    }

    // A flyout opened by a drag over the arrow has done its job when the drag ends.
    Connections {
        target: BarDrag

        function onActiveChanged(): void {
            if (BarDrag.active === false && root.flyoutByDrag) {
                root.closeFlyout()
            }
        }
    }

    FileView {
        id: file

        path: Apps.stateFolder + '/tray.json'
        printErrors: false
        onLoaded: root.apply(text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound) {
                console.warn(`Tray: cannot read tray.json (${FileViewError.toString(error)}), starting fresh`)
            }

            root.apply('')
        }
    }

    Timer {
        id: saveTimer

        interval: 1000
        onTriggered: file.setText(TrayList.serializeTray(root.icons))
    }
}
