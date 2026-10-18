pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Widgets
import QtQuick
import qs.design
import qs.services

// "Add a device", after Windows 7's wizard, opened from the Bluetooth icon's menu: the devices found nearby
// (the adapter keeps looking while the window is open), one chosen and added with Next (paired, trusted,
// connected), then whether it worked. A window of its own.
FloatingWindow {
    id: root

    // 'choose', 'adding', 'added' or 'failed', and the device chosen.
    property string phase: 'choose'
    property var chosen: null
    property string chosenName: ''

    function next(): void {
        if (chosen === null) {
            return
        }

        phase = 'adding'
        BluetoothDevices.add(chosen)
    }

    function restart(): void {
        phase = 'choose'
        chosen = null
        chosenName = ''
    }

    title: qsTr('Add a device')
    implicitWidth: 560
    implicitHeight: 440
    minimumSize: Qt.size(420, 360)
    color: Theme.surface
    visible: false

    // `visible` is set here and not bound: the compositor closes the window too (its close button, a key).
    Connections {
        target: BluetoothDevices

        function onAddOpenChanged(): void {
            if (BluetoothDevices.addOpen) {
                root.restart()
            }

            root.visible = BluetoothDevices.addOpen
        }
    }

    Connections {
        target: root.chosen

        function onPairedChanged(): void {
            if (root.phase === 'adding' && root.chosen.paired) {
                root.phase = 'added'
            }
        }

        function onPairingChanged(): void {
            if (root.phase === 'adding' && root.chosen.pairing === false && root.chosen.paired === false) {
                root.phase = 'failed'
            }
        }
    }

    onClosed: {
        visible = false
        BluetoothDevices.addOpen = false
    }

    onVisibleChanged: {
        if (visible === false) {
            BluetoothDevices.addOpen = false
        }
    }

    Item {
        anchors.fill: parent
        Keys.onEscapePressed: BluetoothDevices.addOpen = false

        Column {
            id: intro

            x: Theme.space5
            y: Theme.space5
            width: parent.width - Theme.space5 * 2
            spacing: Theme.space2

            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: {
                    if (root.phase === 'adding') {
                        return qsTr('Adding %1...').arg(root.chosenName)
                    }

                    if (root.phase === 'added') {
                        return qsTr('This device has been added to this computer')
                    }

                    if (root.phase === 'failed') {
                        return qsTr('%1 could not be added').arg(root.chosenName)
                    }

                    return qsTr('Select a device to add to this computer')
                }
                color: Theme.headingText
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontSizeHeading
            }

            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: {
                    if (BluetoothDevices.enabled === false) {
                        return qsTr('Bluetooth is turned off. Turn the adapter on from the Bluetooth icon\'s menu.')
                    }

                    if (root.phase === 'adding') {
                        return qsTr('If the device asks for a code, a Bluetooth agent must be running to answer it (one comes with blueman or bluetoothctl).')
                    }

                    if (root.phase === 'added') {
                        return qsTr('%1 is paired and connects by itself from now on.').arg(root.chosenName)
                    }

                    if (root.phase === 'failed') {
                        return qsTr('Make sure the device is turned on and can be found (most have a button to make them visible), then try again.')
                    }

                    return qsTr('The computer keeps looking for new devices and shows them here.')
                }
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontSizeBody
            }
        }

        Rectangle {
            id: frame

            x: Theme.space5
            y: intro.y + intro.height + Theme.space4
            width: parent.width - Theme.space5 * 2
            height: strip.y - Theme.space4 - y
            radius: Theme.radiusControl
            color: Theme.surface
            border.width: 1
            border.color: Theme.surfaceBorder
            visible: root.phase === 'choose'
            clip: true

            Text {
                anchors.centerIn: parent
                width: parent.width - Theme.space5 * 2
                visible: BluetoothDevices.found.length === 0 && BluetoothDevices.enabled
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: qsTr('Looking for devices...')
                color: Theme.textMuted
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontSizeBody
            }

            ListView {
                id: list

                x: 1
                y: 1
                width: parent.width - 2 - (scrollBar.visible ? scrollBar.width : 0)
                height: parent.height - 2
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: BluetoothDevices.found

                delegate: Item {
                    id: row

                    required property var modelData

                    readonly property bool selected: root.chosen === modelData.device

                    width: ListView.view.width
                    height: 48

                    Rectangle {
                        x: 2
                        y: 1
                        width: parent.width - 4
                        height: parent.height - 2
                        radius: Theme.radiusControl
                        visible: row.selected || rowHover.hovered
                        border.width: 1
                        border.color: row.selected ? Theme.rowSelectedBorder : Theme.rowHoverBorder

                        gradient: Gradient {
                            GradientStop { position: 0.0; color: row.selected ? Theme.rowSelectedFace[0] : Theme.rowHoverFace[0] }
                            GradientStop { position: 1.0; color: row.selected ? Theme.rowSelectedFace[1] : Theme.rowHoverFace[1] }
                        }
                    }

                    HoverHandler {
                        id: rowHover
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.chosen = row.modelData.device
                            root.chosenName = row.modelData.name
                        }
                        onDoubleClicked: root.next()
                    }

                    IconImage {
                        id: picture

                        x: Theme.space3
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 32
                        source: row.modelData.device.icon === '' ? '' : Quickshell.iconPath(row.modelData.device.icon, true)
                        visible: source !== '' && status === Image.Ready
                    }

                    BluetoothGlyph {
                        x: Theme.space3
                        anchors.verticalCenter: parent.verticalCenter
                        size: 32
                        visible: picture.visible === false
                    }

                    Text {
                        x: Theme.space3 + 32 + Theme.space3
                        width: parent.width - x - Theme.space3
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: row.modelData.name
                        color: Theme.text
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fontSizeBody
                    }
                }
            }

            ScrollBar {
                id: scrollBar

                view: list
                x: parent.width - width - 1
                y: 1
                height: parent.height - 2
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

            Row {
                anchors.right: parent.right
                anchors.rightMargin: Theme.space3
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space2

                ControlButton {
                    width: Math.max(implicitWidth, 80)
                    visible: root.phase === 'choose' || root.phase === 'failed'
                    kind: 'accent'
                    text: root.phase === 'failed' ? qsTr('Try again') : qsTr('Next')
                    enabled: root.phase === 'failed' || root.chosen !== null
                    activeFocusOnTab: true
                    onClicked: {
                        if (root.phase === 'failed') {
                            root.restart()
                            return
                        }

                        root.next()
                    }
                }

                ControlButton {
                    id: closeButton

                    width: Math.max(implicitWidth, 80)
                    text: root.phase === 'added' ? qsTr('Close') : qsTr('Cancel')
                    activeFocusOnTab: true
                    onClicked: BluetoothDevices.addOpen = false
                }
            }
        }
    }
}
