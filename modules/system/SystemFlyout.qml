import Quickshell
import QtQuick
import qs.design
import qs.services

// The flyout of one of the shell's own icons in the notification area (power, network or volume), after
// Windows 7's: its pane, framed as Windows 7's flyouts are (`FlyoutFrame`), over the icon. Like the clock's flyout it takes the keyboard,
// and Escape or a click outside close it. Each pane keeps one size while shown (a popup that changes size
// after it is shown is placed badly): what grows inside it scrolls.
PopupWindow {
    id: root

    property bool shown: false
    // Which pane ('power', 'network', 'volume'), the bar's width, and the middle of its icon in the bar's
    // coordinates.
    property string name: ''
    property real barWidth: 0
    property real iconX: 0

    // Above the icon, kept on the bar (so on the screen); placed here and not slid by the compositor.
    anchor.rect: Qt.rect(Math.max(2, Math.min(iconX - width / 2, barWidth - width - 2)), -Theme.space1, 1, 1)
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Top | Edges.Right
    anchor.adjustment: PopupAdjustment.None
    implicitWidth: Math.max(1, pane.implicitWidth)
    implicitHeight: Math.max(1, pane.implicitHeight)
    color: 'transparent'
    grabFocus: true
    visible: false

    // `visible` is set here and not bound: the popup also hides itself on a click outside. The pane is
    // chosen before the window is shown, so it is shown at the pane's size.
    onShownChanged: {
        if (shown) {
            pane.sourceComponent = name === 'power' ? powerPane : (name === 'network' ? networkPane : volumePane)
            visible = true
            return
        }

        visible = false
    }

    // The pane takes the keyboard (the volume slider: the arrows change the volume at once, as on Windows 7).
    onVisibleChanged: {
        if (visible) {
            if (pane.item !== null) {
                pane.item.forceActiveFocus()
            }

            return
        }

        SystemIcons.closeFlyout()
        pane.sourceComponent = null
    }

    // Escape comes up here from whatever in the pane has the keyboard.
    Item {
        anchors.fill: parent
        opacity: root.visible ? 1 : 0
        Keys.onEscapePressed: SystemIcons.closeFlyout()

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
        }

        Loader {
            id: pane

            anchors.fill: parent
        }
    }

    Component {
        id: powerPane

        PowerPane {
        }
    }

    Component {
        id: networkPane

        NetworkPane {
        }
    }

    Component {
        id: volumePane

        VolumePane {
        }
    }
}
