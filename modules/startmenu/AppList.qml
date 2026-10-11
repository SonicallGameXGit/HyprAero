pragma ComponentBehavior: Bound

import QtQuick
import qs.design
import qs.services
import '../../services/startMenu.js' as StartMenuList

// The left pane's list: rows from `startMenu.js`, stacked from the bottom up, so the featured section (or
// the search results) sits right above the search field and a short list hangs from there. Rows still
// read top to bottom. One row is current (`selected`, an index into `rows`): the one under the pointer or the one
// the keyboard moved to.
Item {
    id: root

    // Top to bottom.
    property var rows: []
    property int selected: -1
    property Tooltip tooltip: null
    // Passed to each row's `DragSource`: the bar's screen, the menu window's place in the bar, and where a
    // drop puts the app back (the whole menu).
    property var screen: null
    property point windowOffset: Qt.point(0, 0)
    property Item returnArea: null
    // Phone-like: dragging the list scrolls it and an app is picked up by holding it. Off: dragging an app
    // picks it up at once, and the list only scrolls with the wheel, the scrollbar or the keyboard.
    property bool touchControls: false

    signal launched(var app)
    signal menuRequested(var app, point at)

    // Up is -1, down is +1, in reading order; the first step up from nothing lands on the lowest app.
    function move(step: int): void {
        const from = selected === -1 && step < 0 ? rows.length : selected
        select(StartMenuList.nextAppRow(rows, from, step))
    }

    function selectFirst(): void {
        select(StartMenuList.nextAppRow(rows, -1, 1))
    }

    function select(index: int): void {
        selected = index
        if (index >= 0) {
            view.positionViewAtIndex(viewIndex(index), ListView.Contain)
        }
    }

    // The view holds the rows bottom first.
    function viewIndex(rowIndex: int): int {
        return rows.length - 1 - rowIndex
    }

    function selectedApp(): var {
        if (selected < 0 || selected >= rows.length || rows[selected].kind !== 'app') {
            return null
        }

        return rows[selected].app
    }

    function scrollToBottom(): void {
        view.positionViewAtBeginning()
    }

    onRowsChanged: {
        if (selected >= rows.length) {
            selected = -1
        }
    }

    ListView {
        id: view

        anchors.fill: parent
        anchors.margins: 1
        clip: true
        verticalLayoutDirection: ListView.BottomToTop
        boundsBehavior: Flickable.StopAtBounds
        acceptedButtons: root.touchControls ? Qt.LeftButton : Qt.NoButton
        // A picked up app belongs to the drag; the list must not go on following the press.
        interactive: BarDrag.active === false
        model: root.rows.slice().reverse()

        delegate: Loader {
            id: slot

            required property var modelData
            required property int index

            readonly property int rowIndex: root.rows.length - 1 - index

            width: ListView.view.width
            sourceComponent: {
                if (modelData.kind === 'app') {
                    return appRow
                }

                if (modelData.kind === 'header') {
                    return headerRow
                }

                if (modelData.kind === 'separator') {
                    return separatorRow
                }

                return hintRow
            }

            Component {
                id: appRow

                AppRow {
                    app: slot.modelData.app
                    big: slot.modelData.section === 'featured'
                    lit: root.selected === slot.rowIndex
                    featured: Apps.isFeatured(slot.modelData.app.id)
                    tooltip: root.tooltip
                    screen: root.screen
                    windowOffset: root.windowOffset
                    returnArea: root.returnArea
                    holdToDrag: root.touchControls
                    onPointed: root.selected = slot.rowIndex
                    onLaunched: root.launched(slot.modelData.app)
                    onFeatureToggled: Apps.setFeatured(slot.modelData.app.id, featured === false)
                    onMenuRequested: at => root.menuRequested(slot.modelData.app, mapToItem(root, at))
                }
            }

            Component {
                id: headerRow

                Item {
                    implicitHeight: 26

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Theme.space3
                        spacing: Theme.space2

                        StarGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: slot.modelData.section === 'featured'
                            size: 14
                            on: true
                        }

                        SortGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: slot.modelData.section === 'others'
                            size: 14
                            color: Theme.headingText
                        }

                        SearchGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: slot.modelData.section === 'search'
                            size: 14
                            color: Theme.headingText
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (slot.modelData.section === 'featured') {
                                    return qsTr('Featured')
                                }

                                if (slot.modelData.section === 'others') {
                                    return qsTr('Most used')
                                }

                                return qsTr('Apps (%1)').arg(root.rows.length - 1)
                            }
                            color: Theme.headingText
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fontSizeBody
                            font.bold: true
                        }
                    }
                }
            }

            // The dark line between the sections.
            Component {
                id: separatorRow

                Item {
                    implicitHeight: Theme.space3

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Theme.space2
                        width: parent.width - Theme.space2 * 2
                        height: 1
                        color: Theme.surfaceBorder
                    }
                }
            }

            Component {
                id: hintRow

                Item {
                    implicitHeight: hint.implicitHeight + Theme.space2 * 2

                    Text {
                        id: hint

                        anchors.verticalCenter: parent.verticalCenter
                        x: Theme.space3
                        width: parent.width - Theme.space3 * 2
                        wrapMode: Text.Wrap
                        text: slot.modelData.section === 'featured'
                            ? qsTr('Click the star next to an app to keep it here.')
                            : qsTr('No apps match your search.')
                        color: Theme.textMuted
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fontSizeBody
                        font.italic: true
                    }
                }
            }
        }
    }

    // Where the list is scrolled to; only while it is longer than the pane. It widens under the pointer;
    // drag it to scroll, press beside it to bring it there, or use the wheel on it.
    Item {
        id: scrollBar

        readonly property real shown: view.visibleArea.heightRatio
        readonly property bool active: barArea.containsMouse || barArea.pressed
        // How far the thumb's top can move.
        readonly property real travel: height - thumb.height

        // Scrolls so the thumb's top is at `thumbY`.
        function scrollTo(thumbY: real): void {
            const ratio = travel > 0 ? Math.max(0, Math.min(thumbY / travel, 1)) : 0
            view.contentY = view.originY + ratio * (view.contentHeight - view.height)
        }

        visible: shown < 1
        anchors.top: view.top
        anchors.bottom: view.bottom
        anchors.right: parent.right
        width: Theme.space3

        Rectangle {
            id: thumb

            anchors.right: parent.right
            anchors.rightMargin: 1
            width: scrollBar.active ? Theme.space2 : Theme.space1
            radius: width / 2
            color: scrollBar.active ? Theme.controlBorderHover : Theme.rowSelectedBorder
            height: Math.max(scrollBar.height * scrollBar.shown, Theme.space4)
            y: scrollBar.travel * (view.visibleArea.yPosition / Math.max(1 - scrollBar.shown, 0.0001))

            Behavior on width {
                NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
            }

            Behavior on color {
                ColorAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            id: barArea

            // Where on the thumb the pointer holds it.
            property real grabOffset: 0

            anchors.fill: parent
            hoverEnabled: true
            onPressed: mouse => {
                if (mouse.y >= thumb.y && mouse.y <= thumb.y + thumb.height) {
                    grabOffset = mouse.y - thumb.y
                    return
                }

                grabOffset = thumb.height / 2
                scrollBar.scrollTo(mouse.y - grabOffset)
            }
            onPositionChanged: mouse => {
                if (pressed) {
                    scrollBar.scrollTo(mouse.y - grabOffset)
                }
            }
            // The list is beside this strip, not under it, so the wheel is passed on by hand.
            onWheel: wheel => {
                const top = view.originY
                const bottom = view.originY + view.contentHeight - view.height
                view.contentY = Math.max(top, Math.min(view.contentY - wheel.angleDelta.y, bottom))
            }
        }
    }
}
