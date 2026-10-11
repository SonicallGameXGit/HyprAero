pragma Singleton

import QtQuick

// Stand-in for services/AppIcons.qml in QML tests: no icon theme, so every app gets the generic picture.
QtObject {
    function forName(name: string): string {
        return ''
    }

    function pathFor(appId: string): string {
        return ''
    }
}
