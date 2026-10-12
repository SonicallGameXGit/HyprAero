import Quickshell
import QtQuick

// A one-shot program, not a part of the shell: turns a picture into a square profile picture, its middle
// cut to a square (never stretched) and shrunk to `pictureSize`, and saves it. The shell has no image tool
// and Qt draws only in a window, so the shell runs this as a process of its own on Qt's offscreen platform
// (`savePictureCommand` in `services/userInfo.js`). Reads the picture from `HYPRAERO_PICTURE_SOURCE` and
// writes `HYPRAERO_PICTURE_TARGET`, the kind of file chosen by its extension. Exit code 0: saved; 1: not
// (not a picture, unreadable, cannot be written).
ShellRoot {
    id: root

    // Sharp in the start menu and on a login screen, small enough to load at once.
    readonly property int pictureSize: 256
    readonly property string source: variable('HYPRAERO_PICTURE_SOURCE')
    readonly property string target: variable('HYPRAERO_PICTURE_TARGET')

    function variable(name: string): string {
        const value = Quickshell.env(name)
        return typeof value === 'string' ? value : ''
    }

    Component.onCompleted: {
        if (source === '' || target === '') {
            Qt.exit(1)
        }
    }

    FloatingWindow {
        implicitWidth: root.pictureSize
        implicitHeight: root.pictureSize
        color: 'transparent'

        Image {
            id: picture

            width: root.pictureSize
            height: root.pictureSize
            source: root.source === '' ? '' : 'file://' + root.source
            // Decoded straight at about the size it is drawn, so a 4K photo is never held whole.
            sourceSize: Qt.size(root.pictureSize, root.pictureSize)
            fillMode: Image.PreserveAspectCrop
            smooth: true
        }

        // The picture can be ready before the window is, and only a picture in a window can be taken; so
        // this tries until both are.
        Timer {
            interval: 10
            running: true
            repeat: true
            onTriggered: {
                if (picture.status === Image.Error) {
                    Qt.exit(1)
                    return
                }

                if (picture.status !== Image.Ready) {
                    return
                }

                const taking = picture.grabToImage(result => {
                    Qt.exit(result.saveToFile(root.target) ? 0 : 1)
                })
                if (taking) {
                    stop()
                }
            }
        }

        // Never left running if something hangs.
        Timer {
            interval: 15000
            running: true
            onTriggered: Qt.exit(1)
        }
    }
}
