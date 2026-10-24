pragma ComponentBehavior: Bound

import QtQuick
import qs.design
import qs.modules.common
import qs.services
import '../../services/startMenu.js' as StartMenuList

// The left pane's list: rows from `startMenu.js`, top to bottom. One row is current (`selected`, an index
// into `rows`): the one under the pointer or the one the keyboard moved to. One app with actions of its own
// can have them open (`actionsApp`), shown by the menu in its right column (`ActionsPane`); then one of them
// can be the current one instead of the app (`selectedAction`).
//
// As in Windows 7, resting on an app's arrow for `hoverDelay` opens its actions, a click on it at once. They
// stay open while the pointer is on that app or on the actions (`paneHovered`, from the menu), go to another
// app with actions at once when the pointer moves onto it, and otherwise close `hoverDelay` after the pointer
// left.
Item {
    id: root

    // Top to bottom.
    property var rows: []
    property int selected: -1
    // Of the current app: -1 for the app itself, else the index of its action.
    property int selectedAction: -1
    // The id of the app whose actions are open ('' none).
    property string actionsApp: ''
    // The pointer is on the open actions (set by the menu that shows them).
    property bool paneHovered: false
    readonly property int hoverDelay: 400
    // The app under the pointer ('' none), and the one whose arrow it is on.
    property string pointedApp: ''
    property string arrowApp: ''
    property Tooltip tooltip: null
    // Passed to each row's `DragSource`: the bar's screen, the menu window's place in the bar, and where a
    // drop puts the app back (the whole menu).
    property var screen: null
    property point windowOffset: Qt.point(0, 0)
    property Item returnArea: null
    // Phone-like: dragging the list scrolls it and an app is picked up by holding it. Off: dragging an app
    // picks it up at once, and the list only scrolls with the wheel, the scrollbar or the keyboard.
    property bool touchControls: false

    // `actionIndex` is -1 for the app itself.
    signal launched(var app, int actionIndex)
    signal menuRequested(var app, point at)

    // Up is -1, down is +1, in reading order; on the open actions it walks through them and stays there.
    // The first step up from nothing lands on the lowest app. Going to another app closes the actions.
    function move(step: int): void {
        const app = selectedApp()
        if (app !== null && isExpanded(app.id) && selectedAction >= 0) {
            selectedAction = Math.max(0, Math.min(selectedAction + step, app.actions.length - 1))
            return
        }

        const from = selected === -1 && step < 0 ? rows.length : selected
        const index = StartMenuList.nextAppRow(rows, from, step)
        if (index === selected) {
            return
        }

        select(index)
        actionsApp = ''
    }

    function selectFirst(): void {
        select(StartMenuList.nextAppRow(rows, -1, 1))
    }

    function select(index: int): void {
        selected = index
        selectedAction = -1
        if (index >= 0) {
            view.positionViewAtIndex(index, ListView.Contain)
        }
    }

    function isExpanded(id: string): bool {
        return actionsApp !== '' && actionsApp === id
    }

    function setExpanded(app: var, on: bool): void {
        openTimer.stop()
        closeTimer.stop()
        if (on === isExpanded(app.id) || (on && app.actions.length === 0)) {
            return
        }

        actionsApp = on ? app.id : ''
        const current = selectedApp()
        if (current !== null && (on === false || current.id !== app.id)) {
            selectedAction = -1
        }
    }

    // Opens or closes the current app's actions (`on`: open, close, or -1: the other way). Opened by the
    // keyboard, the keyboard goes onto the first action.
    function expandSelected(on: int): void {
        const app = selectedApp()
        if (app === null) {
            return
        }

        const opening = on === -1 ? isExpanded(app.id) === false : on === 1
        setExpanded(app, opening)
        if (opening && isExpanded(app.id)) {
            selectedAction = 0
        }
    }

    // The app with this id among the rows, null when it is not there.
    function appWithId(id: string): var {
        const row = rows.find(item => item.kind === 'app' && item.app.id === id)
        return row === undefined ? null : row.app
    }

    // The pointer on action `index` of the open actions: their app becomes the current row, so Enter and the
    // keyboard go on from there.
    function pointAction(index: int): void {
        const at = rows.findIndex(item => item.kind === 'app' && item.app.id === actionsApp)
        if (at < 0) {
            return
        }

        selected = at
        selectedAction = index
    }

    // After the pointer moved: the open actions stay while it is on their app or on them, go to another app
    // with actions at once, and otherwise close after `hoverDelay`.
    function followPointer(): void {
        if (actionsApp === '') {
            return
        }

        if (paneHovered || pointedApp === actionsApp) {
            closeTimer.stop()
            return
        }

        const pointed = pointedApp === '' ? null : appWithId(pointedApp)
        if (pointed !== null && pointed.actions.length > 0) {
            setExpanded(pointed, true)
            return
        }

        if (closeTimer.running === false) {
            closeTimer.start()
        }
    }

    function rowHovered(app: var, hovered: bool): void {
        if (hovered) {
            pointedApp = app.id
        } else if (pointedApp === app.id) {
            pointedApp = ''
        }

        followPointer()
    }

    // With nothing open, resting on the arrow opens the actions; with another app's open, it goes there at
    // once (`followPointer`, the arrow being on its row).
    function arrowHovered(app: var, hovered: bool): void {
        if (hovered) {
            arrowApp = app.id
            if (actionsApp === '') {
                openTimer.restart()
            }

            return
        }

        if (arrowApp === app.id) {
            arrowApp = ''
            openTimer.stop()
        }
    }

    onPaneHoveredChanged: followPointer()

    function selectedApp(): var {
        if (selected < 0 || selected >= rows.length || rows[selected].kind !== 'app') {
            return null
        }

        return rows[selected].app
    }

    function scrollToTop(): void {
        view.positionViewAtBeginning()
    }

    onRowsChanged: {
        if (selected >= rows.length) {
            selected = -1
            selectedAction = -1
        }

        if (actionsApp !== '' && appWithId(actionsApp) === null) {
            actionsApp = ''
        }
    }

    Timer {
        id: openTimer

        interval: root.hoverDelay
        onTriggered: {
            const app = root.arrowApp === '' ? null : root.appWithId(root.arrowApp)
            if (app !== null) {
                root.setExpanded(app, true)
            }
        }
    }

    Timer {
        id: closeTimer

        interval: root.hoverDelay
        onTriggered: {
            if (root.paneHovered === false && root.pointedApp !== root.actionsApp) {
                root.actionsApp = ''
                root.selectedAction = -1
            }
        }
    }

    ListView {
        id: view

        anchors.fill: parent
        anchors.margins: 1
        // The rows stop where the scrollbar starts: a press on the scrollbar must never reach a row, whose drag
        // handler watches every press under it and could take the drag over.
        anchors.rightMargin: scrollBar.visible ? scrollBar.width : 1
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        acceptedButtons: root.touchControls ? Qt.LeftButton : Qt.NoButton
        // A picked up app belongs to the drag; the list must not go on following the press.
        interactive: BarDrag.active === false
        model: root.rows

        delegate: Loader {
            id: slot

            required property var modelData
            required property int index

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
                    lit: root.selected === slot.index
                    actionsShown: root.isExpanded(slot.modelData.app.id)
                    featured: Apps.isFeatured(slot.modelData.app.id)
                    tooltip: root.tooltip
                    screen: root.screen
                    windowOffset: root.windowOffset
                    returnArea: root.returnArea
                    holdToDrag: root.touchControls
                    onPointed: {
                        root.selected = slot.index
                        root.selectedAction = -1
                    }
                    onRowHovered: hovered => root.rowHovered(slot.modelData.app, hovered)
                    onArrowHovered: hovered => root.arrowHovered(slot.modelData.app, hovered)
                    onLaunched: root.launched(slot.modelData.app, -1)
                    onFeatureToggled: Apps.setFeatured(slot.modelData.app.id, featured === false)
                    onExpandToggled: root.setExpanded(slot.modelData.app, actionsShown === false)
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
                            visible: slot.modelData.section === 'used'
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

                                if (slot.modelData.section === 'used') {
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

            // The dark line between the sections, fading out at both ends as Windows 7's.
            Component {
                id: separatorRow

                Item {
                    implicitHeight: Theme.space3

                    EtchedLine {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Theme.space2
                        width: parent.width - Theme.space2 * 2
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
        // The view only estimates the height of rows it has not built yet, so its numbers shift while it
        // scrolls. While the thumb is held (`held`) it keeps the size it had when taken and stays where the
        // pointer puts it (`heldY`); the list follows it, not the other way round.
        property bool held: false
        property real heldHeight: 0
        property real heldY: 0
        readonly property real freeHeight: Math.max(height * shown, Theme.space4)
        readonly property real thumbHeight: held ? heldHeight : freeHeight
        // How far the thumb's top can move.
        readonly property real travel: height - thumbHeight

        // Scrolls so the thumb's top is at `thumbY`. The ends are asked for by name: a thumb at the bottom
        // must show the last row, whatever the estimate says.
        function scrollTo(thumbY: real): void {
            const y = Math.max(0, Math.min(thumbY, travel))
            heldY = y
            const ratio = travel > 0 ? y / travel : 0
            if (ratio === 0) {
                view.positionViewAtBeginning()
            } else if (ratio === 1) {
                view.positionViewAtEnd()
            } else {
                view.contentY = view.originY + ratio * (view.contentHeight - view.height)
            }
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
            height: scrollBar.thumbHeight
            y: scrollBar.held
                ? scrollBar.heldY
                : scrollBar.travel * (view.visibleArea.yPosition / Math.max(1 - scrollBar.shown, 0.0001))

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
            // Nothing else may take the press over once the thumb has it (the list itself with touch controls).
            preventStealing: true
            // A press takes the thumb at once, on it or beside it (then it jumps there), and every move until
            // the release belongs to it, wherever the pointer goes.
            onPressed: mouse => {
                const onThumb = mouse.y >= thumb.y && mouse.y <= thumb.y + thumb.height
                scrollBar.heldHeight = scrollBar.freeHeight
                scrollBar.heldY = thumb.y
                scrollBar.held = true
                grabOffset = onThumb ? mouse.y - thumb.y : scrollBar.heldHeight / 2
                if (onThumb === false) {
                    scrollBar.scrollTo(mouse.y - grabOffset)
                }
            }
            onReleased: scrollBar.held = false
            onCanceled: scrollBar.held = false
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
