pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Widgets
import QtQuick
import qs.design
import qs.services
import '../../services/tray.js' as TrayList

// The "Notification Area Icons" page, after Windows 7's, opened by "Customize..." in the tray's flyout:
// every icon the tray has seen (running apps first, then the ones that are not running) with what it should
// do, "Restore default icon behaviors" and "Always show all icons and notifications on the taskbar". A
// window of its own. Changes apply at once, as in every settings window of the family, so it has a Close
// button instead of Windows' OK and Cancel.
FloatingWindow {
    id: root

    // What each choice of the drop-down lists means, in their order.
    readonly property var behaviors: ['show', 'hide', 'notify']
    readonly property var behaviorNames: [
        qsTr('Show icon and notifications'),
        qsTr('Hide icon and notifications'),
        qsTr('Only show notifications'),
    ]
    // One row per icon ever seen: `{ key, name, behavior, item }`, `item` null when its app is not running.
    readonly property var rows: {
        const running = []
        const away = []
        for (const icon of Tray.icons) {
            const item = Tray.items.find(candidate => Tray.keyOf(candidate) === icon.key)
            const row = {
                key: icon.key,
                name: icon.name,
                icon: icon.icon,
                behavior: icon.behavior,
                item: item === undefined ? null : item,
            }
            if (row.item === null) {
                away.push(row)
            } else {
                running.push(row)
            }
        }

        return running.concat(away)
    }
    readonly property int choiceWidth: 220
    // The icon whose drop-down list is open.
    property string listKey: ''

    function openList(row: var, box: Item): void {
        listKey = row.key
        const items = []
        for (let index = 0; index < behaviors.length; index++) {
            items.push({ text: behaviorNames[index], check: 'radio', checked: behaviors[index] === row.behavior })
        }

        list.items = items
        list.at = box.mapToItem(page, 0, box.height)
        list.current = behaviors.indexOf(row.behavior)
        list.open = true
        // The keys go to the list now, not to the box (whose Down would ask for the list again).
        page.forceActiveFocus()
    }

    title: qsTr('Notification Area Icons')
    implicitWidth: 620
    implicitHeight: 540
    minimumSize: Qt.size(480, 400)
    color: Theme.surface
    visible: false

    // `visible` is set here and not bound: the compositor closes the window too (its close button, a key).
    Connections {
        target: Tray

        function onCustomizeOpenChanged(): void {
            root.visible = Tray.customizeOpen
        }
    }

    onClosed: {
        visible = false
        Tray.customizeOpen = false
    }

    onVisibleChanged: {
        if (visible) {
            list.close()
            closeButton.forceActiveFocus()
            return
        }

        Tray.customizeOpen = false
    }

    Item {
        id: page

        anchors.fill: parent
        Keys.onPressed: event => {
            if (list.open) {
                if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                    list.step(event.key === Qt.Key_Up ? -1 : 1)
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    list.choose(list.current)
                } else if (event.key === Qt.Key_Escape) {
                    list.close()
                } else {
                    return
                }

                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Escape) {
                Tray.customizeOpen = false
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
                text: qsTr('Select which icons and notifications appear on the bar')
                wrapMode: Text.Wrap
                color: Theme.headingText
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontSizeHeading
            }

            Text {
                width: parent.width
                text: qsTr('If you choose to hide icons and notifications, you won\'t be notified about changes or updates. To view hidden icons at any time, click the arrow next to the notification area on the bar.')
                wrapMode: Text.Wrap
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontSizeBody
            }
        }

        // The list of icons, solid, with Windows 7's two column headings.
        Rectangle {
            id: frame

            x: Theme.space5
            y: intro.y + intro.height + Theme.space4
            width: parent.width - Theme.space5 * 2
            height: links.y - Theme.space3 - y
            radius: Theme.radiusControl
            color: Theme.surface
            border.width: 1
            border.color: Theme.surfaceBorder
            clip: true

            Rectangle {
                id: headings

                x: 1
                y: 1
                width: parent.width - 2
                height: 25
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.toolbarFace[0] }
                    GradientStop { position: 1.0; color: Theme.toolbarFace[1] }
                }

                Text {
                    x: Theme.space3
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr('Icons')
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fontSizeSmall
                }

                // The line between the two column headings, as in a Windows 7 list.
                Rectangle {
                    id: columnLine

                    x: parent.width - root.choiceWidth - Theme.space3 * 2 - (scrollBar.visible ? scrollBar.width : 0)
                    width: 1
                    height: parent.height
                    color: Theme.toolbarBorder
                }

                Text {
                    x: columnLine.x + Theme.space3
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr('Behaviors')
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fontSizeSmall
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.toolbarBorder
                }
            }

            Text {
                visible: root.rows.length === 0
                anchors.centerIn: parent
                width: parent.width - Theme.space5 * 2
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: qsTr('No app has put an icon in the notification area yet.')
                color: Theme.textMuted
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontSizeBody
            }

            ListView {
                id: icons

                x: 1
                y: headings.y + headings.height
                width: parent.width - 2 - (scrollBar.visible ? scrollBar.width : 0)
                height: parent.height - y - 1
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.rows

                delegate: Item {
                    id: row

                    required property var modelData

                    readonly property string detail: {
                        if (modelData.item === null) {
                            return qsTr('Not running')
                        }

                        const description = TrayList.plainText(modelData.item.tooltipDescription)
                        return description === modelData.name ? '' : description
                    }

                    width: ListView.view.width
                    height: 44

                    // Lit under the pointer and while its list is open, as rows are in Windows 7's lists.
                    Rectangle {
                        x: 2
                        y: 1
                        width: parent.width - 4
                        height: parent.height - 2
                        radius: Theme.radiusControl
                        visible: rowHover.hovered || (list.open && root.listKey === row.modelData.key)
                        border.width: 1
                        border.color: Theme.rowHoverBorder
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.rowHoverFace[0] }
                            GradientStop { position: 1.0; color: Theme.rowHoverFace[1] }
                        }
                    }

                    HoverHandler {
                        id: rowHover
                    }

                    IconImage {
                        id: picture

                        x: Theme.space3
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 16
                        source: Tray.pictureOf(row.modelData.item === null ? row.modelData.icon : row.modelData.item.icon)
                        visible: source !== '' && status === Image.Ready
                    }

                    GenericAppIcon {
                        x: Theme.space3
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        visible: picture.visible === false
                    }

                    Column {
                        x: Theme.space3 + 16 + Theme.space3
                        width: choiceBox.x - x - Theme.space3
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            width: parent.width
                            text: row.modelData.name
                            elide: Text.ElideRight
                            color: row.modelData.item === null ? Theme.textMuted : Theme.text
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fontSizeBody
                        }

                        Text {
                            width: parent.width
                            visible: row.detail !== ''
                            text: row.detail
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            color: Theme.textMuted
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    ChoiceBox {
                        id: choiceBox

                        x: parent.width - width - Theme.space3
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.choiceWidth
                        // "Always show all" leaves nothing to choose, as on Windows 7.
                        enabled: Config.tray.showAll === false
                        choice: root.behaviorNames[Math.max(0, root.behaviors.indexOf(row.modelData.behavior))]
                        onListRequested: root.openList(row.modelData, choiceBox)
                    }
                }
            }

            ScrollBar {
                id: scrollBar

                view: icons
                x: parent.width - width - 1
                y: icons.y
                height: icons.height
            }
        }

        Column {
            id: links

            x: Theme.space5
            y: strip.y - height - Theme.space4
            width: parent.width - Theme.space5 * 2
            spacing: Theme.space3

            LinkText {
                text: qsTr('Restore default icon behaviors')
                activeFocusOnTab: true
                onClicked: Tray.restoreDefaults()
            }

            CheckBox {
                text: qsTr('Always show all icons and notifications on the bar')
                checked: Config.tray.showAll
                onToggled: on => Tray.setShowAll(on)
            }
        }

        // The buttons on a grey strip along the bottom, as in a Windows 7 dialog.
        Rectangle {
            id: strip

            anchors.bottom: parent.bottom
            width: parent.width
            height: closeButton.height + Theme.space3 * 2
            color: Theme.surfaceSunken

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.rowSeparator
            }

            ControlButton {
                id: closeButton

                anchors.right: parent.right
                anchors.rightMargin: Theme.space3
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(implicitWidth, 80)
                text: qsTr('Close')
                activeFocusOnTab: true
                onClicked: Tray.customizeOpen = false
            }
        }

        MenuPanel {
            id: list

            anchors.fill: parent
            onChosen: index => Tray.setBehavior(root.listKey, root.behaviors[index])
            onOpenChanged: {
                if (open === false) {
                    page.forceActiveFocus()
                }
            }
        }
    }
}
