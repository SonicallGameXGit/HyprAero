pragma Singleton

import QtQuick

// Stand-in for services/Apps.qml in QML tests: the drag format and the featured list, nothing started.
QtObject {
    readonly property string appDragFormat: 'application/x-hypraero-app'
    property var featured: []

    function isFeatured(id: string): bool {
        return featured.includes(id)
    }

    function setFeatured(id: string, on: bool): void {
        featured = on ? featured.concat([id]) : featured.filter(item => item !== id)
    }
}
