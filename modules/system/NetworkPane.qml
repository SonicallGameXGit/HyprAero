pragma ComponentBehavior: Bound

import QtQuick
import qs.design
import qs.services
import '../../services/network.js' as NetworkLogic

// The network flyout, after Windows 7's "View Available Networks" (287 x 402, measured; wider for long
// names, `widthFor`): "Currently connected to:" with Windows 7's picture of the network's location, its
// name and whether it reaches the internet, a refresh button; a line, then the "Wireless Network Connection" group (its heading folds it, as the blue chevron
// says) with the Wi-Fi networks around (`NetworkRow`). All of it scrolls above the band, which holds
// "Open network connections" (nm-connection-editor, Windows' "Network and Sharing Center"). While it is open
// the Wi-Fi device keeps looking for networks.
//
// While a row is open the list is held still: the networks are read again whenever a signal changes, and
// rebuilding the rows would lose what is being typed in one.
Item {
    id: root

    // The network whose row is open ('' when none), whether it is asking for a key, and the
    // "Connect automatically" choice for it.
    property string openName: ''
    property bool askingKey: false
    property bool autoconnect: true
    property bool wifiFolded: false
    property var rows: []
    property int openWidth: 287

    // Wide enough for the longest network name known when it opens, so names are not cut: Windows 7's 287 at
    // least, 520 at most. A row holds the name (measured bold, as the connected one is), what is happening
    // ("Connected", "Connecting..."), the bars (24, `NetworkRow`) and room for the scrollbar. The width stays
    // while shown (`SystemFlyout`), so a longer name found later is cut.
    function widthFor(names: var): int {
        const words = [qsTr('Connected'), qsTr('Connecting...'), qsTr('Disconnecting...')]
        const stateWidth = Math.max(...words.map(word => nameMetrics.advanceWidth(word)))
        const nameWidth = Math.max(0, ...names.map(name => nameMetrics.advanceWidth(name)))
        const row = Theme.space3 + nameWidth + Theme.space2 + stateWidth + Theme.space2 + 24 + Theme.space2
        const flyout = row + scrollBar.implicitWidth + 2 + frame.frameWidth * 2
        return Math.ceil(Math.min(520, Math.max(287, flyout)))
    }

    function toggle(name: string): void {
        askingKey = false
        autoconnect = true
        openName = openName === name ? '' : name
    }

    function connect(row: var): void {
        if (row.action === 'disconnect') {
            Network.disconnectFrom(row.network)
            return
        }

        if (row.action === 'askKey' && askingKey === false) {
            askingKey = true
            return
        }

        if (row.action === 'askKey') {
            Network.connectWithKey(row.network, row.key, autoconnect)
            return
        }

        if (row.action === 'connect') {
            Network.connectTo(row.network, autoconnect)
        }
    }

    Binding on rows {
        value: Network.networks
        when: root.openName === ''
        restoreMode: Binding.RestoreNone
    }

    implicitWidth: openWidth
    implicitHeight: 402

    Component.onCompleted: {
        openWidth = widthFor(Network.networks.map(entry => entry.name).concat([Network.currentName]))
        Network.scanning = true
    }
    Component.onDestruction: Network.scanning = false

    FontMetrics {
        id: nameMetrics

        font.family: Theme.fontUi
        font.pixelSize: Theme.fontSizeBody
        font.bold: true
    }

    FlyoutFrame {
        id: frame

        anchors.fill: parent
        bandHeight: Network.hasSettingsProgram ? 50 : 0
        band: LinkText {
            anchors.centerIn: parent
            text: qsTr('Open network connections')
            activeFocusOnTab: true
            onClicked: {
                SystemIcons.closeFlyout()
                Network.openSettings()
            }
        }

        Flickable {
            id: view

            x: 1
            y: 1
            width: parent.width - 2 - (scrollBar.visible ? scrollBar.width : 0)
            height: parent.height - 2 - frame.bandHeight
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: content

                width: view.width

                Item {
                    width: parent.width
                    height: 76

                    Text {
                        id: currentHeading

                        x: Theme.space3
                        y: Theme.space3
                        text: Network.currentName === '' ? qsTr('Not connected') : qsTr('Currently connected to:')
                        color: Theme.text
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fontSizeBody
                    }

                    // Windows 7's refresh button: its own icon on a tool button, there while Wi-Fi can look.
                    ControlButton {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space2
                        y: Theme.space1
                        width: 26
                        height: 26
                        kind: 'tool'
                        visible: Network.wifiDevice !== null && Network.wifiEnabled
                        Accessible.name: qsTr('Refresh network list')
                        onClicked: Network.rescan()

                        WindowsIcon {
                            anchors.centerIn: parent
                            name: 'refresh'
                        }
                    }

                    // Windows 7's own pictures: the network's location, or what there is to connect to.
                    WindowsIcon {
                        id: currentPicture

                        x: Theme.space3
                        y: currentHeading.y + currentHeading.height + Theme.space2
                        name: NetworkLogic.currentPicture(Network.currentName !== '', Network.icon)
                        size: 32
                    }

                    Column {
                        x: currentPicture.x + currentPicture.width + Theme.space3
                        width: parent.width - x - Theme.space3
                        anchors.verticalCenter: currentPicture.verticalCenter

                        Text {
                            width: parent.width
                            text: {
                                if (Network.currentName !== '') {
                                    return Network.currentName
                                }

                                return Network.icon.badge === 'available' ? qsTr('Connections are available') : qsTr('No connections are available')
                            }
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fontSizeBody
                            font.bold: Network.currentName !== ''
                        }

                        Text {
                            visible: Network.currentName !== ''
                            text: Network.accessText
                            color: Theme.text
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fontSizeBody
                        }
                    }
                }

                // The group's heading under a line across the flyout; a click on it folds the group.
                Item {
                    width: parent.width
                    height: 34
                    visible: Network.wifiDevice !== null

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.toolbarBorder
                    }

                    Text {
                        x: Theme.space3
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr('Wireless Network Connection')
                        color: Theme.textMuted
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fontSizeBody
                    }

                    CaretGlyph {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space4
                        anchors.verticalCenter: parent.verticalCenter
                        folded: root.wifiFolded
                    }

                    MouseArea {
                        anchors.fill: parent
                        Accessible.role: Accessible.Button
                        Accessible.name: root.wifiFolded ? qsTr('Show the wireless networks') : qsTr('Hide the wireless networks')
                        onClicked: root.wifiFolded = root.wifiFolded === false
                    }
                }

                Column {
                    width: parent.width
                    visible: Network.wifiDevice !== null && root.wifiFolded === false

                    Item {
                        width: parent.width
                        height: 60
                        visible: Network.wifiEnabled === false || root.rows.length === 0

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Theme.space2
                            text: Network.wifiEnabled ? qsTr('Looking for networks...') : qsTr('Wi-Fi is turned off.')
                            color: Theme.textMuted
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fontSizeBody
                        }

                        LinkText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Theme.space2 + Theme.space5
                            visible: Network.wifiEnabled === false
                            text: qsTr('Turn on Wi-Fi')
                            activeFocusOnTab: true
                            onClicked: Network.setWifiEnabled(true)
                        }
                    }

                    Repeater {
                        model: Network.wifiEnabled ? root.rows : []

                        NetworkRow {
                            id: row

                            required property var modelData

                            width: content.width
                            network: modelData.network
                            open: root.openName === modelData.name
                            askingKey: open && root.askingKey
                            autoconnect: root.autoconnect
                            onToggled: root.toggle(row.modelData.name)
                            onAutoconnectToggled: on => root.autoconnect = on
                            onConnectRequested: root.connect(row)
                            onKeyCancelled: root.askingKey = false
                        }
                    }
                }
            }
        }

        ScrollBar {
            id: scrollBar

            view: view
            x: parent.width - width - 1
            y: 1
            height: view.height
        }
    }
}
