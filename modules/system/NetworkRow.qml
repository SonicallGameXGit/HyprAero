import QtQuick
import qs.design
import qs.services
import '../../services/network.js' as NetworkLogic

// One Wi-Fi network in the network flyout's list, after Windows 7's: its name in link blue (bold, and
// "Connected" beside it, for the connected one), its signal bars, and Windows' warning shield over them when
// it is open to anyone. A click opens it under the name: "Disconnect" for the connected one; otherwise
// "Connect automatically" (for a network not saved yet) and "Connect", which asks for the security key in
// place when one is needed, or sends to the network settings when a key is not enough. What went wrong last time is said in red. The pane keeps which row is open and what is typed, so
// they survive the list being read again.
Item {
    id: root

    // The Quickshell network (it stays the same object while the list is held still).
    required property var network
    property bool open: false
    property bool askingKey: false
    property bool autoconnect: true
    property string failure: ''
    property alias key: keyField.text

    readonly property bool connected: network !== null && network.connected
    readonly property bool busy: network !== null && network.stateChanging
    readonly property string action: network === null ? 'connect' : NetworkLogic.connectAction({
        connected: network.connected,
        known: network.known,
        security: network.security,
    })
    readonly property bool secured: network !== null && NetworkLogic.securityGroup(network.security) !== 'open'
    readonly property string failureText: {
        if (failure === 'key') {
            return qsTr('The network security key is not correct.')
        }

        if (failure === 'lost') {
            return qsTr('The network is out of range.')
        }

        return failure === '' ? '' : qsTr('Could not connect to this network.')
    }

    signal toggled()
    signal autoconnectToggled(bool on)
    // Connect was pressed (`key` holds the typed key when one was asked for); Cancel took the key away.
    signal connectRequested()
    signal keyCancelled()

    implicitHeight: header.height + (open ? details.implicitHeight + Theme.space2 : 0)
    clip: true

    // Lit under the pointer, selected while open, as rows of Windows 7's lists.
    Rectangle {
        x: 2
        width: parent.width - 4
        height: parent.height
        radius: Theme.radiusControl
        visible: root.open || headerHover.hovered
        border.width: 1
        border.color: root.open ? Theme.rowSelectedBorder : Theme.rowHoverBorder

        gradient: Gradient {
            GradientStop { position: 0.0; color: root.open ? Theme.rowSelectedFace[0] : Theme.rowHoverFace[0] }
            GradientStop { position: 1.0; color: root.open ? Theme.rowSelectedFace[1] : Theme.rowHoverFace[1] }
        }
    }

    Item {
        id: header

        width: parent.width
        height: 30

        HoverHandler {
            id: headerHover
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.toggled()
        }

        Text {
            id: nameLabel

            x: Theme.space3
            width: Math.min(implicitWidth, stateLabel.x - x - Theme.space2)
            anchors.verticalCenter: parent.verticalCenter
            text: root.network === null ? '' : root.network.name
            elide: Text.ElideRight
            color: Theme.textLink
            font.family: Theme.fontUi
            font.pixelSize: Theme.fontSizeBody
            font.bold: root.connected
        }

        // "Connected", or what is happening, right of the name as Windows 7 puts it.
        Text {
            id: stateLabel

            anchors.right: bars.left
            anchors.rightMargin: Theme.space2
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (root.busy) {
                    return root.connected ? qsTr('Disconnecting...') : qsTr('Connecting...')
                }

                return root.connected ? qsTr('Connected') : ''
            }
            color: Theme.text
            font.family: Theme.fontUi
            font.pixelSize: Theme.fontSizeBody
            font.bold: true
        }

        // Windows 7's green bars, its 32px picture drawn at 24 as the flyout does (Slate: the copy with a dark
        // outline).
        WindowsIcon {
            id: bars

            anchors.right: parent.right
            anchors.rightMargin: Theme.space2
            anchors.verticalCenter: parent.verticalCenter
            size: 24
            name: NetworkLogic.barsPicture(root.network === null ? 0 : root.network.signalStrength, Theme.slate)
        }

        // Windows 7 marks a network anyone can listen to with its warning shield over the bars' upper left
        // corner (measured on Windows 7's flyout).
        WindowsIcon {
            id: openSign

            x: bars.x - 2
            y: bars.y - 3
            name: 'shield-warning'
            visible: root.secured === false
        }
    }

    Column {
        id: details

        x: Theme.space3
        y: header.height
        width: parent.width - Theme.space3 * 2
        spacing: Theme.space2
        visible: root.open

        Text {
            width: parent.width
            visible: root.failureText !== ''
            wrapMode: Text.Wrap
            text: root.failureText
            color: Theme.dangerText
            font.family: Theme.fontUi
            font.pixelSize: Theme.fontSizeSmall
        }

        // A key is not enough for this one (a user name, certificates): the network settings can.
        Text {
            width: parent.width
            visible: root.action === 'settings'
            wrapMode: Text.Wrap
            text: Network.hasSettingsProgram
                ? qsTr('This network needs more than a security key. Connect to it from the network connections.')
                : qsTr('This network needs more than a security key, and no program to set it up was found (nm-connection-editor).')
            color: Theme.text
            font.family: Theme.fontUi
            font.pixelSize: Theme.fontSizeSmall
        }

        Text {
            visible: root.askingKey
            text: qsTr('Type the network security key')
            color: Theme.headingText
            font.family: Theme.fontUi
            font.pixelSize: Theme.fontSizeBody
        }

        TextField {
            id: keyField

            width: parent.width
            visible: root.askingKey
            hidden: hideBox.checked
            Accessible.name: qsTr('Security key')
            onAccepted: {
                if (NetworkLogic.validKey(text) && root.busy === false) {
                    root.failure = ''
                    root.connectRequested()
                }
            }
            onEscaped: root.keyCancelled()
            onVisibleChanged: {
                if (visible) {
                    input.forceActiveFocus()
                }
            }
        }

        CheckBox {
            id: hideBox

            visible: root.askingKey
            checked: true
            text: qsTr('Hide characters')
            onToggled: on => hideBox.checked = on
        }

        CheckBox {
            visible: root.askingKey === false && root.action !== 'disconnect' && root.network !== null && root.network.known === false && Network.hasNmcli
            checked: root.autoconnect
            text: qsTr('Connect automatically')
            onToggled: on => root.autoconnectToggled(on)
        }

        Row {
            anchors.right: parent.right
            spacing: Theme.space2
            layoutDirection: Qt.RightToLeft

            ControlButton {
                width: Math.max(implicitWidth, 80)
                visible: root.action === 'disconnect'
                text: qsTr('Disconnect')
                activeFocusOnTab: true
                enabled: root.busy === false
                onClicked: Network.disconnectFrom(root.network)
            }

            ControlButton {
                width: Math.max(implicitWidth, 80)
                visible: root.action === 'connect' || (root.action === 'askKey' && root.askingKey === false)
                text: qsTr('Connect')
                activeFocusOnTab: true
                enabled: root.busy === false
                onClicked: {
                    root.failure = ''
                    root.connectRequested()
                }
            }

            ControlButton {
                width: Math.max(implicitWidth, 80)
                visible: root.askingKey
                text: qsTr('Cancel')
                activeFocusOnTab: true
                onClicked: root.keyCancelled()
            }

            ControlButton {
                width: Math.max(implicitWidth, 80)
                visible: root.askingKey
                kind: 'accent'
                text: qsTr('OK')
                activeFocusOnTab: true
                enabled: NetworkLogic.validKey(keyField.text) && root.busy === false
                onClicked: {
                    root.failure = ''
                    root.connectRequested()
                }
            }

            ControlButton {
                width: Math.max(implicitWidth, 80)
                visible: root.action === 'settings' && Network.hasSettingsProgram
                text: qsTr('Open network connections')
                activeFocusOnTab: true
                onClicked: {
                    SystemIcons.closeFlyout()
                    Network.openSettings()
                }
            }
        }
    }

    Connections {
        target: root.network

        function onConnectionFailed(reason: int): void {
            root.failure = NetworkLogic.failureKind(reason)
        }
    }
}
