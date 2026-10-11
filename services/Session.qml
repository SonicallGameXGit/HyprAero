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
    // `[{ key, path }]`: documents, pictures, music, videos, downloads, those the user did not turn off.
    readonly property var folders: UserInfo.userFolders(userDirs.text(), home)

    function findPicture(): void {
        pictureCheck.running = true
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

        command: ['test', '-f', path]
        running: true
        onExited: code => {
            root.picturePath = code === 0 ? path : ''
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
