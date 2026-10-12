pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import 'startMenu.js' as StartMenuList
import 'userInfo.js' as UserInfo

// The user and the session: name, picture, personal folders, and leaving (power, lock, log out).
// Folders and the terminal open in the user's own default apps.
Singleton {
    id: root

    readonly property string home: {
        const value = Quickshell.env('HOME')
        return typeof value === 'string' ? value : ''
    }
    readonly property string userName: {
        const value = Quickshell.env('USER')
        if (typeof value === 'string' && value !== '') {
            return value
        }

        return home.split('/').pop()
    }
    readonly property string displayName: {
        const full = UserInfo.fullName(passwd.text(), userName)
        return full === '' ? userName : full
    }
    // The picture desktops share for the user, '' while there is none (the menu draws an avatar then).
    // Looked for again with `findPicture`, so a picture set while the shell runs shows up.
    property string picturePath: ''
    // When the picture last changed and its size ('' without one), part of the picture's address: an
    // unchanged picture comes from Qt's cache at once, a new one at the same path is read again.
    property string pictureStamp: ''
    // Whether the picture can be changed from the start menu: zenity (GTK's file chooser) is installed.
    // Without it, a picture saved as `~/.face` by hand still shows.
    property bool canChoosePicture: false
    // `[{ key, path }]`: documents, pictures, music, videos, downloads, those the user did not turn off.
    readonly property var folders: UserInfo.userFolders(userDirs.text(), home)

    // Also looks again for zenity, so installing it while the shell runs is noticed.
    function findPicture(): void {
        pictureCheck.running = true
        chooserCheck.running = true
    }

    // Asks for a picture in a file chooser, then saves its middle, cut square and shrunk, as `~/.face`, the
    // picture desktops share for the user; cancelling changes nothing.
    function choosePicture(): void {
        if (canChoosePicture === false || pictureChooser.running || pictureSave.running) {
            return
        }

        pictureChooser.running = true
    }

    function pictureChosen(output: string): void {
        const path = UserInfo.chosenPicture(output)
        if (path === '') {
            if (output.trim() !== '') {
                console.warn('Session: not a picture, the old one stays: ' + output.trim())
            }

            return
        }

        pictureSave.command = UserInfo.savePictureCommand(Quickshell.shellPath('tools/shrinkPicture.qml'), path, pictureCheck.path)
        pictureSave.running = true
    }

    function openFolder(path: string): void {
        Quickshell.execDetached(['xdg-open', path])
    }

    function openTerminal(): void {
        Quickshell.execDetached({ command: StartMenuList.terminalCommand([]), workingDirectory: home })
    }

    function powerOff(): void {
        Quickshell.execDetached(['systemctl', 'poweroff'])
    }

    function reboot(): void {
        Quickshell.execDetached(['systemctl', 'reboot'])
    }

    function suspend(): void {
        Quickshell.execDetached(['systemctl', 'suspend'])
    }

    // hyprlock when it is installed; otherwise the session is asked to lock, which works when a locker
    // listens for it (hypridle, swayidle).
    function lock(): void {
        Quickshell.execDetached([
            'sh',
            '-c',
            'if command -v hyprlock >/dev/null 2>&1; then exec hyprlock; fi; exec loginctl lock-session',
        ])
    }

    function logOut(): void {
        Hyprland.dispatch('hl.dsp.exit()')
    }

    Process {
        id: pictureCheck

        readonly property string path: root.home + '/.face'

        // Nothing printed when there is none. The stamp is set first, so the picture's address is never
        // the new path with the old stamp.
        command: ['stat', '-L', '-c', '%Y-%s', '--', path]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const stamp = text.trim()
                root.pictureStamp = stamp
                root.picturePath = stamp === '' ? '' : pictureCheck.path
            }
        }
    }

    Process {
        id: chooserCheck

        command: ['sh', '-c', 'command -v zenity']
        running: true
        onExited: code => {
            root.canChoosePicture = code === 0
        }
    }

    // Opens in the pictures folder. zenity prints the chosen path, and nothing when cancelled.
    Process {
        id: pictureChooser

        command: {
            const pictures = root.folders.find(folder => folder.key === 'pictures')
            return [
                'zenity',
                '--file-selection',
                '--title=' + qsTr('Choose your picture'),
                '--filename=' + (pictures === undefined ? root.home : pictures.path) + '/',
                '--file-filter=' + UserInfo.pictureFilter(qsTr('Pictures')),
            ]
        }
        stdout: StdioCollector {
            onStreamFinished: root.pictureChosen(text)
        }
    }

    Process {
        id: pictureSave

        onExited: code => {
            if (code !== 0) {
                console.warn(`Session: cannot save the picture as ${pictureCheck.path} (exit code ${code}), the old one stays`)
                return
            }

            pictureCheck.running = true
        }
    }

    FileView {
        id: passwd

        path: '/etc/passwd'
        printErrors: false
    }

    FileView {
        id: userDirs

        path: {
            const xdg = Quickshell.env('XDG_CONFIG_HOME')
            const config = typeof xdg === 'string' && xdg.startsWith('/') ? xdg : root.home + '/.config'
            return config + '/user-dirs.dirs'
        }
        printErrors: false
    }
}
