pragma Singleton

import QtQuick

// Stand-in for services/WorkspaceTitles.qml in QML tests: the titles are set by the test (`{ id: text }`), and
// the last reorder the titles were asked to follow is recorded (`{ ids, from, to }`, null for none).
QtObject {
    property var titles: ({})
    property var reordered: null

    function titleOf(id: int): string {
        const title = titles[String(id)]
        return title === undefined ? '' : title
    }

    function reorder(ids: var, from: int, to: int): void {
        reordered = { ids: ids, from: from, to: to }
    }
}
