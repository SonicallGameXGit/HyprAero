import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import qs.design
import qs.companion
import 'companion/plugin.js' as Plugin

// The companion: tells the plugin which theme to draw with and sends it the apps' icons, through its one door
// (`hyprctl hypraero-frames ...`, AGENTS.md section 4.2). Without it the plugin draws Aero frames with Windows 7's
// generic application icon.
ShellRoot {
    id: root

    // Classes (in hexadecimal, as the plugin names them) waiting for their icon, the one being read, and those
    // whose icon could not be found or read, not asked for again this session
    property var waiting: []
    property string reading: ''
    property string readingPath: ''
    property int readingSize: 16
    property var givenUp: ({})
    property bool themeAgain: false

    function sendTheme(): void {
        if (themeSender.running) {
            themeAgain = true
            return
        }

        themeSender.command = Plugin.themeCommand(Theme.slate)
        themeSender.running = true
    }

    function ask(): void {
        if (asker.running === false) {
            asker.running = true
        }
    }

    function answered(reply: string): void {
        const missing = Plugin.parseMissing(reply)
        // Not loaded (yet): asked again at the next window event
        if (missing === null) {
            return
        }

        // The plugin starts in Aero each time it is loaded
        if (missing.theme !== (Theme.slate ? 'slate' : 'aero')) {
            sendTheme()
        }

        for (const classHex of missing.classes) {
            const known = givenUp[classHex] === true || waiting.includes(classHex) || reading === classHex
            if (known === false) {
                waiting.push(classHex)
            }
        }

        next()
    }

    function next(): void {
        if (reading !== '' || waiting.length === 0) {
            return
        }

        // The desktop entries are read at start; until then every lookup would fail
        if (AppIcons.ready === false) {
            return
        }

        const classHex = waiting.shift()
        const name = Plugin.hexToText(classHex)
        const path = name === null ? '' : AppIcons.pathFor(name)
        if (path === '') {
            givenUp[classHex] = true
            next()
            return
        }

        reading = classHex
        readingPath = path
        read(16)
    }

    function read(size: int): void {
        readingSize = size
        readerLoader.active = true
        if (readerLoader.item === null) {
            givenUp[reading] = true
            finishReading()
            return
        }

        readerLoader.item.start(readingPath, size)
    }

    function finishReading(): void {
        readerLoader.active = false
        reading = ''
        readingPath = ''
        next()
    }

    Component.onCompleted: {
        console.info('Frames: companion started, theme ' + (Theme.slate ? 'Slate' : 'Aero'))
        sendTheme()
        ask()
    }

    Connections {
        target: Theme

        function onSlateChanged(): void {
            root.sendTheme()
        }
    }

    Connections {
        target: AppIcons

        function onReadyChanged(): void {
            root.next()
        }
    }

    // A new window may need an icon; a window becoming active is the first sign of a plugin loaded after the companion
    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === 'openwindow' || event.name === 'activewindowv2') {
                askTimer.restart()
            }
        }
    }

    Timer {
        id: askTimer

        interval: 500
        onTriggered: root.ask()
    }

    Process {
        id: asker

        command: Plugin.missingCommand()
        stdout: StdioCollector {
            onStreamFinished: root.answered(text)
        }
    }

    Process {
        id: themeSender

        onExited: (code, status) => {
            if (root.themeAgain) {
                root.themeAgain = false
                root.sendTheme()
            }
        }
    }

    Process {
        id: iconSender

        onExited: (code, status) => {
            if (code !== 0) {
                root.givenUp[root.reading] = true
                root.finishReading()
                return
            }

            if (root.readingSize === 16) {
                root.read(32)
                return
            }

            root.finishReading()
        }
    }

    // Made only while an icon is read: a window that is not needed is not kept. Named by its file, so the companion
    // still starts where there is no layer shell (offscreen, in its check).
    LazyLoader {
        id: readerLoader

        source: Qt.resolvedUrl('companion/IconReader.qml')
    }

    Connections {
        target: readerLoader.item

        function onRead(pixels: var): void {
            iconSender.command = Plugin.iconCommand(root.readingSize, root.reading, pixels)
            iconSender.running = true
        }

        function onFailed(): void {
            root.givenUp[root.reading] = true
            root.finishReading()
        }
    }
}
