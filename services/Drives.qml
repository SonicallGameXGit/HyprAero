pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import 'drives.js' as DriveList

// The plugged-in drives that can be ejected, for the notification area's "Safely Remove Hardware and Eject
// Media" icon (Windows 7's): listed with lsblk (`services/drives.js`), listed again whenever UDisks says
// something changed (`udisksctl monitor`), ejected with udisksctl. Without udisksctl nothing can be
// ejected, so the icon is not shown (`available`).
//
// A drive that was ejected but cannot be powered off (a card reader) is still listed by lsblk; it is left
// out of the list until it is taken out, as Windows 7 drops it once it is safe to remove.
Singleton {
    id: root

    property bool available: false
    // `{ path, title, labels, partitions }` per drive.
    property var all: []
    property var ejected: []
    readonly property var drives: all.filter(drive => ejected.includes(drive.path) === false)
    // The drive being ejected ('' when none), and the last one that could not be (for its dialog).
    property string ejecting: ''
    property string problemName: ''
    property bool problemOpen: false

    function nameOf(drive: var): string {
        return DriveList.driveName(drive)
    }

    function list(): void {
        lister.running = true
    }

    function eject(drive: var): void {
        if (ejecting !== '') {
            return
        }

        ejecting = drive.path
        ejector.drive = drive
        ejector.command = DriveList.ejectCommand(drive)
        ejector.running = true
    }

    function listed(text: string): void {
        all = DriveList.removableDrives(text)
        // A drive that is gone may come back (plugged in again) and be ejected again.
        ejected = ejected.filter(path => all.some(drive => drive.path === path))
    }

    Process {
        id: lister

        command: DriveList.listCommand
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.listed(text)
        }
    }

    // Prints a few lines for every change; one listing after they stop is enough.
    Process {
        id: monitor

        command: ['udisksctl', 'monitor']
        running: true
        stdout: SplitParser {
            onRead: listTimer.restart()
        }
        onStarted: root.available = true
        onExited: (code, status) => {
            root.available = false
            restartTimer.start()
        }
    }

    Timer {
        id: listTimer

        interval: 300
        onTriggered: root.list()
    }

    // UDisks restarted (or udisksctl is missing): tried again now and then, quietly.
    Timer {
        id: restartTimer

        interval: 10000
        onTriggered: monitor.running = true
    }

    Process {
        id: ejector

        property var drive: null

        onExited: (code, status) => {
            if (code === 0 || code === 3) {
                root.ejected = root.ejected.concat([drive.path])
            } else {
                root.problemName = DriveList.driveName(drive)
                root.problemOpen = true
                console.warn(`Drives: ejecting ${drive.path} failed (exit ${code})`)
            }

            root.ejecting = ''
            root.list()
        }
    }
}
