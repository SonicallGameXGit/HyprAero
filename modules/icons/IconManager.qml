pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.design
import qs.services

// The Icon Manager, after Windows 7's "Change Icon" window: the icon of an app (its windows, its pin, its start
// menu row), a window or a workspace, opened by "Change icon..." in its right-click menu. "Look for icons in"
// picks an icon theme (or all of them) as Windows 7 picks a file, the search field narrows the list by name,
// and "Browse..." picks a picture file of one's own, shown first in the list until OK copies it in
// (`IconOverrides.chooseFile`). Under the list it asks how far the icon goes: an app's only for the app (its
// pin, its start menu row) or everywhere, its windows too; a window's only for that window or for every window
// of its app, and for the app too or not. OK uses the selected icon (as does a double click or Enter), Cancel
// changes nothing, "Restore Defaults" gives back the own icons as far as the choice goes. A window of its own.
FloatingWindow {
    id: root

    // What the icon is for (`IconOverrides.target`), with nothing in it before the first opening.
    readonly property var target: IconOverrides.target === null
        ? ({ kind: '', key: '', name: '', app: '', appName: '' })
        : IconOverrides.target
    // A window of an app with a desktop entry, which can give its icon to the app's other windows and to it.
    readonly property bool hasApp: target.kind === 'windows' && target.app !== ''
    readonly property string appName: target.kind === 'apps' ? target.name : target.appName
    // How far the icon goes (`IconOverrides.choiceChanges`): an app's or a window's to every window of the
    // app, a window's to its app too.
    property bool allWindows: false
    property bool appIcon: false
    readonly property var choice: ({ allWindows: allWindows, appIcon: appIcon })
    // The icon chosen for it now ('' for its own).
    readonly property string currentPath: target.kind === '' ? '' : IconOverrides.chosenIcon(target, choice)
    // A picture just chosen in "Browse...", not copied in yet.
    property string chosenFile: ''
    // The picture of one's own shown first in the list: the one just chosen, else the copy in use now.
    readonly property string ownPicture: {
        if (chosenFile !== '') {
            return chosenFile
        }

        return IconOverrides.isCopy(currentPath) ? currentPath : ''
    }
    // '' for every theme.
    property string theme: ''
    property string selectedPath: ''
    readonly property var results: {
        const found = IconOverrides.search(search.text, theme)
        if (ownPicture === '') {
            return found
        }

        const fileName = ownPicture.slice(ownPicture.lastIndexOf('/') + 1)
        return [{ name: fileName, theme: '', path: ownPicture }].concat(found)
    }
    readonly property int cellWidth: 88
    readonly property int cellHeight: 76
    readonly property int iconSize: 32

    function indexOfSelected(): int {
        return results.findIndex(icon => icon.path === selectedPath)
    }

    function scrollToSelected(): void {
        const index = indexOfSelected()
        if (index >= 0) {
            grid.positionViewAtIndex(index, GridView.Center)
        } else {
            grid.positionViewAtBeginning()
        }
    }

    function select(index: int): void {
        if (index < 0 || index >= results.length) {
            return
        }

        selectedPath = results[index].path
        grid.currentIndex = index
        grid.positionViewAtIndex(index, GridView.Contain)
    }

    function accept(): void {
        if (selectedPath === '') {
            return
        }

        if (selectedPath === chosenFile) {
            IconOverrides.chooseFile(target, choice, chosenFile)
        } else {
            IconOverrides.choose(target, choice, selectedPath)
        }

        IconOverrides.closeManager()
    }

    function restoreDefaults(): void {
        IconOverrides.choose(target, choice, '')
        IconOverrides.closeManager()
    }

    function openThemeList(): void {
        const items = [{ text: qsTr('All icon themes'), check: 'radio', checked: theme === '' }]
        for (const name of IconOverrides.themes) {
            items.push({ text: name, check: 'radio', checked: theme === name })
        }

        themeList.items = items
        themeList.current = theme === '' ? 0 : IconOverrides.themes.indexOf(theme) + 1
        themeList.at = themeBox.mapToItem(pageItem, 0, themeBox.height)
        themeList.open = true
        // The keys go to the list now, not to the box (whose Down would ask for the list again).
        pageItem.forceActiveFocus()
    }

    function themeChosen(index: int): void {
        theme = index === 0 ? '' : IconOverrides.themes[index - 1]
        Qt.callLater(scrollToSelected)
    }

    // The grid's keys: the arrows move the selection, Enter takes it, anything else types into the search.
    function gridKey(event: var): void {
        const index = Math.max(indexOfSelected(), 0)
        const perRow = Math.max(1, Math.floor(grid.width / cellWidth))
        let next = -1
        if (event.key === Qt.Key_Left) {
            next = index - 1
        } else if (event.key === Qt.Key_Right) {
            next = index + 1
        } else if (event.key === Qt.Key_Up) {
            next = index - perRow
        } else if (event.key === Qt.Key_Down) {
            next = index + perRow
        } else if (event.key === Qt.Key_Home) {
            next = 0
        } else if (event.key === Qt.Key_End) {
            next = results.length - 1
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            accept()
            event.accepted = true
            return
        } else if (event.key === Qt.Key_Escape) {
            IconOverrides.closeManager()
            event.accepted = true
            return
        } else if (event.text !== '' && event.text.trim() !== '' && (event.modifiers & Qt.ControlModifier) === 0) {
            search.input.forceActiveFocus()
            search.text += event.text
            event.accepted = true
            return
        } else {
            return
        }

        if (indexOfSelected() < 0) {
            next = 0
        }

        select(Math.min(Math.max(next, 0), results.length - 1))
        event.accepted = true
    }

    title: qsTr('Change Icon')
    implicitWidth: 600
    implicitHeight: 560
    minimumSize: Qt.size(460, 420)
    color: Theme.surface
    visible: false

    onResultsChanged: grid.currentIndex = indexOfSelected()

    // `visible` is set here and not bound: the compositor closes the window too (its close button, a key).
    Connections {
        target: IconOverrides

        function onManagerOpenChanged(): void {
            if (IconOverrides.managerOpen) {
                // Opened on what is chosen now.
                const choice = IconOverrides.initialChoice(root.target)
                root.allWindows = choice.allWindows
                root.appIcon = choice.appIcon
                root.theme = ''
                root.chosenFile = ''
                search.text = ''
                root.selectedPath = root.currentPath
                themeList.close()
                Qt.callLater(root.scrollToSelected)
            }

            root.visible = IconOverrides.managerOpen
            if (IconOverrides.managerOpen) {
                search.input.forceActiveFocus()
            }
        }

        function onFileChosen(path: string): void {
            if (IconOverrides.managerOpen) {
                root.chosenFile = path
                root.selectedPath = path
                Qt.callLater(root.scrollToSelected)
            }
        }

        function onListedChanged(): void {
            Qt.callLater(root.scrollToSelected)
        }
    }

    onClosed: {
        visible = false
        IconOverrides.closeManager()
    }

    onVisibleChanged: {
        if (visible === false) {
            IconOverrides.closeManager()
        }
    }

    Item {
        id: pageItem

        anchors.fill: parent
        Keys.onPressed: event => {
            if (themeList.open) {
                if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                    themeList.step(event.key === Qt.Key_Up ? -1 : 1)
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    themeList.choose(themeList.current)
                } else if (event.key === Qt.Key_Escape) {
                    themeList.close()
                } else {
                    return
                }

                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Escape) {
                IconOverrides.closeManager()
                event.accepted = true
            }
        }

        Column {
            id: intro

            x: Theme.space5
            y: Theme.space5
            width: parent.width - Theme.space5 * 2
            spacing: Theme.space2

            Text {
                width: parent.width
                text: qsTr('Change the icon of %1').arg(root.target.name)
                elide: Text.ElideRight
                color: Theme.headingText
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontSizeHeading
            }

            Text {
                width: parent.width
                text: root.target.kind === 'workspaces'
                    ? qsTr('The workspace shows this icon on the bar whatever windows it has, also while it is empty.')
                    : qsTr('Choose an icon from the list, or browse for a picture of your own.')
                wrapMode: Text.Wrap
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontSizeBody
            }
        }

        Text {
            id: lookLabel

            x: Theme.space5
            y: intro.y + intro.height + Theme.space4
            text: qsTr('Look for icons in:')
            color: Theme.text
            font.family: Theme.fontUi
            font.pixelSize: Theme.fontSizeBody
        }

        Item {
            id: controls

            x: Theme.space5
            y: lookLabel.y + lookLabel.height + Theme.space1
            width: parent.width - Theme.space5 * 2
            height: Math.max(themeBox.height, search.height, browseButton.height)

            ChoiceBox {
                id: themeBox

                anchors.verticalCenter: parent.verticalCenter
                width: 180
                choice: root.theme === '' ? qsTr('All icon themes') : root.theme
                enabled: IconOverrides.themes.length > 0
                onListRequested: root.openThemeList()
            }

            SearchField {
                id: search

                x: themeBox.width + Theme.space2
                anchors.verticalCenter: parent.verticalCenter
                width: browseButton.x - x - Theme.space2
                placeholder: qsTr('Search icons')
                activeFocusOnTab: true
                onTextChanged: Qt.callLater(root.scrollToSelected)
                onKeyPressed: event => {
                    if (event.key === Qt.Key_Down) {
                        grid.forceActiveFocus()
                        if (root.indexOfSelected() < 0) {
                            root.select(0)
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.accept()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        IconOverrides.closeManager()
                        event.accepted = true
                    }
                }
            }

            ControlButton {
                id: browseButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(implicitWidth, 80)
                text: qsTr('Browse...')
                enabled: IconOverrides.canBrowse
                activeFocusOnTab: true
                Accessible.description: IconOverrides.canBrowse ? '' : qsTr('Install zenity to choose a picture of your own')
                onClicked: IconOverrides.browse()
            }
        }

        Text {
            id: listLabel

            x: Theme.space5
            y: controls.y + controls.height + Theme.space3
            width: parent.width - Theme.space5 * 2
            text: IconOverrides.canBrowse
                ? qsTr('Select an icon from the list below:')
                : qsTr('Select an icon from the list below (install zenity to browse for a picture of your own):')
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.fontUi
            font.pixelSize: Theme.fontSizeBody
        }

        // The icons, solid, as a Windows 7 list in its icons view.
        Rectangle {
            id: frame

            x: Theme.space5
            y: listLabel.y + listLabel.height + Theme.space1
            width: parent.width - Theme.space5 * 2
            height: details.y - Theme.space2 - y
            radius: Theme.radiusControl
            color: Theme.surface
            border.width: 1
            border.color: Theme.surfaceBorder
            clip: true

            Text {
                visible: grid.count === 0
                anchors.centerIn: parent
                width: parent.width - Theme.space5 * 2
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: IconOverrides.listing ? qsTr('Looking for icons...') : qsTr('No icon has that name.')
                color: Theme.textMuted
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontSizeBody
            }

            GridView {
                id: grid

                x: 1 + Theme.space1
                y: 1 + Theme.space1
                width: parent.width - 2 - Theme.space1 - (scrollBar.visible ? scrollBar.width : 0)
                height: parent.height - 2 - Theme.space1 * 2
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                cellWidth: root.cellWidth
                cellHeight: root.cellHeight
                keyNavigationEnabled: false
                activeFocusOnTab: true
                currentIndex: -1
                model: root.results
                Keys.onPressed: event => root.gridKey(event)

                delegate: Item {
                    id: cell

                    required property var modelData
                    required property int index

                    readonly property bool selected: modelData.path === root.selectedPath

                    width: root.cellWidth
                    height: root.cellHeight
                    Accessible.role: Accessible.ListItem
                    Accessible.name: modelData.name
                    Accessible.selected: selected

                    // Lit under the pointer, deeper when selected, as items are in Windows 7's lists.
                    Rectangle {
                        x: 2
                        y: 2
                        width: parent.width - 4
                        height: parent.height - 4
                        radius: Theme.radiusControl
                        visible: cell.selected || cellHover.hovered
                        border.width: 1
                        border.color: cell.selected ? Theme.rowSelectedBorder : Theme.rowHoverBorder
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: cell.selected ? Theme.rowSelectedFace[0] : Theme.rowHoverFace[0] }
                            GradientStop { position: 1.0; color: cell.selected ? Theme.rowSelectedFace[1] : Theme.rowHoverFace[1] }
                        }
                    }

                    AppIconImage {
                        id: picture

                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Theme.space2
                        width: root.iconSize
                        height: root.iconSize
                        loadSize: root.iconSize * 2
                        fillMode: Image.PreserveAspectFit
                        source: IconOverrides.sourceOf(cell.modelData.path)
                    }

                    GenericAppIcon {
                        anchors.centerIn: picture
                        width: root.iconSize
                        height: root.iconSize
                        visible: picture.status === Image.Error
                    }

                    Text {
                        x: Theme.space1
                        y: picture.y + picture.height + Theme.space1
                        width: parent.width - Theme.space1 * 2
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.name
                        elide: Text.ElideMiddle
                        color: Theme.text
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    HoverHandler {
                        id: cellHover
                    }

                    TapHandler {
                        onTapped: {
                            grid.forceActiveFocus()
                            root.select(cell.index)
                        }
                        onDoubleTapped: {
                            root.select(cell.index)
                            root.accept()
                        }
                    }
                }
            }

            ScrollBar {
                id: scrollBar

                view: grid
                x: parent.width - width - 1
                y: 1
                height: parent.height - 2
            }
        }

        // Where the selected icon comes from, as the list only names it.
        Text {
            id: details

            x: Theme.space5
            y: (options.visible ? options.y : strip.y) - Theme.space3 - height
            width: parent.width - Theme.space5 * 2
            text: root.selectedPath
            elide: Text.ElideMiddle
            color: Theme.textMuted
            font.family: Theme.fontUi
            font.pixelSize: Theme.fontSizeSmall
        }

        // How far the icon goes, asked rather than guessed.
        Column {
            id: options

            x: Theme.space5
            y: strip.y - Theme.space3 - height
            width: parent.width - Theme.space5 * 2
            spacing: Theme.space2
            visible: root.target.kind === 'apps' || root.target.kind === 'windows'

            // Said rather than leaving the choices out without a word.
            Text {
                width: parent.width
                visible: root.target.kind === 'windows' && root.hasApp === false
                text: qsTr('This window\'s app has no entry the shell can find, so the icon is for this window only.')
                wrapMode: Text.Wrap
                color: Theme.textMuted
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontSizeBody
            }

            RadioButton {
                visible: root.target.kind === 'apps' || root.hasApp
                text: root.target.kind === 'apps'
                    ? qsTr('Only for the app: its pin and its row in the start menu')
                    : qsTr('Only for this window')
                checked: root.allWindows === false
                onPicked: root.allWindows = false
            }

            RadioButton {
                visible: root.target.kind === 'apps' || root.hasApp
                text: root.target.kind === 'apps'
                    ? qsTr('Everywhere: also for every window of %1').arg(root.appName)
                    : qsTr('For every window of %1').arg(root.appName)
                checked: root.allWindows
                onPicked: root.allWindows = true
            }

            CheckBox {
                visible: root.hasApp
                text: qsTr('Also for the app: its pin and its row in the start menu')
                checked: root.appIcon
                onToggled: on => root.appIcon = on
            }
        }

        // The buttons on a grey strip along the bottom, as in a Windows 7 dialog.
        Rectangle {
            id: strip

            anchors.bottom: parent.bottom
            width: parent.width
            height: okButton.height + Theme.space3 * 2
            color: Theme.surfaceSunken

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.rowSeparator
            }

            ControlButton {
                anchors.left: parent.left
                anchors.leftMargin: Theme.space3
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(implicitWidth, 80)
                text: qsTr('Restore Defaults')
                enabled: root.target.kind !== '' && IconOverrides.canRestore(root.target, root.choice)
                activeFocusOnTab: true
                onClicked: root.restoreDefaults()
            }

            ControlButton {
                id: okButton

                anchors.right: cancelButton.left
                anchors.rightMargin: Theme.space2
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(implicitWidth, 80)
                kind: 'accent'
                text: qsTr('OK')
                enabled: root.selectedPath !== ''
                activeFocusOnTab: true
                onClicked: root.accept()
            }

            ControlButton {
                id: cancelButton

                anchors.right: parent.right
                anchors.rightMargin: Theme.space3
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(implicitWidth, 80)
                text: qsTr('Cancel')
                activeFocusOnTab: true
                onClicked: IconOverrides.closeManager()
            }
        }

        MenuPanel {
            id: themeList

            anchors.fill: parent
            onChosen: index => root.themeChosen(index)
            onOpenChanged: {
                if (open === false) {
                    themeBox.forceActiveFocus()
                }
            }
        }
    }
}
