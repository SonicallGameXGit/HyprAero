pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import 'colorScheme.js' as ColorScheme

// Whether the system asks for a dark look, from the freedesktop portal (the same source GTK and
// browsers use). Qt's own colorScheme hint does not follow it on this setup. Without gdbus or a
// portal the value stays false (Aero light) and nothing else breaks.
Singleton {
    id: root

    property bool dark: false

    function apply(line: string): void {
        const scheme = ColorScheme.parseColorScheme(line)
        if (scheme === 'dark') {
            dark = true
        } else if (scheme === 'light') {
            dark = false
        }
    }

    Process {
        running: true
        command: [
            'gdbus',
            'call',
            '--session',
            '--dest', 'org.freedesktop.portal.Desktop',
            '--object-path', '/org/freedesktop/portal/desktop',
            '--method', 'org.freedesktop.portal.Settings.Read',
            'org.freedesktop.appearance',
            'color-scheme',
        ]

        stdout: SplitParser {
            onRead: line => root.apply(line)
        }
    }

    Process {
        running: true
        command: [
            'gdbus',
            'monitor',
            '--session',
            '--dest', 'org.freedesktop.portal.Desktop',
            '--object-path', '/org/freedesktop/portal/desktop',
        ]

        stdout: SplitParser {
            onRead: line => root.apply(line)
        }
    }
}
