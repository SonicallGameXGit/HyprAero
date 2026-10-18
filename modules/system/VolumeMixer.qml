pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.design
import qs.services

// The Volume Mixer, after Windows 7's, opened from the volume flyout ("Mixer") or the volume icon's menu: a
// window opening against the bottom right corner of the work area (`Workspaces.placeNextInCorner`), with
// the "Device" group (the output device's column; its drop-down list chooses the device, as Windows' Sound
// settings do) and the "Applications" group, one column per app playing sound, each with its own volume and
// mute; the apps scroll sideways when there are many. Changes apply at once. The window's frame is the
// compositor's, not drawn here.
FloatingWindow {
    id: root

    readonly property int columnWidth: 112

    function openOutputs(box: Item): void {
        const items = Volume.outputs.map(output => ({
            text: output.name,
            check: 'radio',
            checked: Volume.sink !== null && Volume.sink.id === output.id,
        }))
        outputList.items = items
        outputList.at = box.mapToItem(page, 0, box.height)
        outputList.current = Math.max(0, items.findIndex(item => item.checked))
        outputList.open = true
        page.forceActiveFocus()
    }

    title: Volume.deviceName === '' ? qsTr('Volume Mixer') : qsTr('Volume Mixer - %1').arg(Volume.deviceName)
    implicitWidth: 472
    implicitHeight: 311
    minimumSize: Qt.size(300, 311)
    color: Theme.surface
    visible: false

    // `visible` is set here and not bound: the compositor closes the window too (its close button, a key).
    Connections {
        target: Volume

        function onMixerOpenChanged(): void {
            if (Volume.mixerOpen && root.visible === false) {
                // Windows 7 opens it against the bottom right corner of the work area.
                Workspaces.placeNextInCorner('Volume Mixer')
            }

            root.visible = Volume.mixerOpen
        }
    }

    onClosed: {
        visible = false
        Volume.mixerOpen = false
    }

    onVisibleChanged: {
        if (visible === false) {
            Volume.mixerOpen = false
            outputList.close()
            return
        }

        // The first trackbar has the keyboard, as in Windows 7's mixer (its aqua thumb).
        deviceColumn.slider.forceActiveFocus()
    }

    Item {
        id: page

        anchors.fill: parent
        Keys.onPressed: event => {
            if (outputList.open) {
                if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                    outputList.step(event.key === Qt.Key_Up ? -1 : 1)
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    outputList.choose(outputList.current)
                } else if (event.key === Qt.Key_Escape) {
                    outputList.close()
                } else {
                    return
                }

                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Escape) {
                Volume.mixerOpen = false
                event.accepted = true
            }
        }

        // Windows 7's two groups, measured on its screenshot: "Device" with the output device's column, and
        // "Applications" with one column per app playing sound, side by side with their frames touching. The
        // device's drop-down list takes the place of its name (only when there is a choice), so the columns
        // line up either way.
        // The device's level, drawn across the other columns from its thumb to the last app's trackbar: a thin
        // line with a light edge on each side, under the columns' own drawing.
        Item {
            readonly property real start: deviceGroup.x + deviceColumn.slider.x + deviceColumn.slider.width
            readonly property real end: appsGroup.x + 4 + (Volume.streams.length - 1) * root.columnWidth + 40 + 21

            x: start
            y: deviceGroup.y + deviceColumn.thumbY - 1
            width: Math.max(0, Math.min(end, appsGroup.x + appsGroup.width - 2) - start)
            height: 3
            visible: Volume.present && Volume.streams.length > 0

            Rectangle {
                anchors.fill: parent
                color: Theme.groupBorder
            }

            Rectangle {
                y: 1
                width: parent.width
                height: 1
                color: Theme.trackbarRamp
            }
        }

        GroupFrame {
            id: deviceGroup

            x: 10
            y: 19
            width: 113
            height: page.height - y - 13
            title: qsTr('Device')
            accelerator: true

            MixerColumn {
                id: deviceColumn

                width: parent.width
                height: parent.height
                speaker: true
                showName: outputBox.visible === false
                name: Volume.present ? Volume.deviceName : qsTr('No device')
                enabled: Volume.present
                volume: Volume.volume
                muted: Volume.muted
                onMoved: value => Volume.setVolume(value)
                onMuteToggled: Volume.toggleMute()
            }
        }

        GroupFrame {
            id: appsGroup

            x: deviceGroup.x + deviceGroup.width
            y: deviceGroup.y
            width: page.width - x - 10
            height: deviceGroup.height
            title: qsTr('Applications')
            accelerator: true

            Text {
                x: Theme.space4
                y: 38
                width: parent.width - x * 2
                visible: Volume.streams.length === 0
                wrapMode: Text.Wrap
                text: qsTr('No app is playing sound.')
                color: Theme.textMuted
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontSizeBody
            }

            Flickable {
                x: 4
                width: parent.width - x - 2
                height: parent.height
                contentWidth: apps.implicitWidth
                contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick

                Row {
                    id: apps

                    height: parent.height

                    Repeater {
                        model: Volume.streams

                        MixerColumn {
                            required property var modelData

                            width: root.columnWidth
                            height: apps.height
                            name: modelData.name
                            iconName: modelData.icon
                            volume: modelData.node !== null && modelData.node.audio !== null ? modelData.node.audio.volume : 0
                            muted: modelData.node !== null && modelData.node.audio !== null && modelData.node.audio.muted
                            onMoved: value => Volume.setNodeVolume(modelData.node, value)
                            onMuteToggled: Volume.toggleNodeMute(modelData.node)
                        }
                    }
                }
            }
        }

        ChoiceBox {
            id: outputBox

            x: deviceGroup.x + 6
            y: deviceGroup.y + 54
            width: root.columnWidth - 12
            // Only when there is a choice; the column's own name says the device otherwise.
            visible: Volume.outputs.length > 1
            choice: Volume.present ? Volume.deviceName : qsTr('No device')
            onListRequested: root.openOutputs(outputBox)
        }

        MenuPanel {
            id: outputList

            anchors.fill: parent
            onChosen: index => Volume.setOutput(Volume.outputs[index].node)
            onOpenChanged: {
                if (open === false) {
                    page.forceActiveFocus()
                }
            }
        }
    }
}
