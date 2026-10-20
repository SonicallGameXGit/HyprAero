import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.design
import qs.services
import '../../services/peek.js' as PeekLogic

// The peek (`Peek`): while the pointer rests on a window's preview card, or on a workspace's button for
// longer, this covers the screen above the bar with what that would show (`PeekScene`): the workspace as if
// it was shown, live, with the hovered window lit and everything else darker; or, for a window that fills
// the screen anyway, that window alone, almost full screen. The layer lets the pointer through, so the bar
// and its previews stay as they are and the pointer stays on the card or button that asked for it.
//
// The bar is at the bottom edge, so the layer stops one bar's height above the screen's bottom.
PanelWindow {
    id: root

    // The bar's height, kept free at the bottom.
    property int barHeight: 0

    readonly property var target: ({
        kind: Peek.kind,
        address: Peek.address,
        workspaceId: Peek.workspaceId,
    })
    readonly property var scene: Peek.active && Peek.screenName === screen.name
        ? PeekLogic.peekScene(target, Workspaces.windows, Workspaces.shownIds)
        : null
    // Only a change of what is drawn counts, not every refresh of the window list.
    readonly property string key: PeekLogic.sceneKey(scene)
    readonly property bool wanted: scene !== null
    // Hyprland's numbers are in layout pixels and this layer's in Qt units, which differ when the shell runs
    // with a QT_SCALE_FACTOR: one unit is the monitor's layout width over this layer's width.
    readonly property var screenRect: Workspaces.monitorRectNamed(screen.name)
    readonly property real unit: screenRect === null || width <= 0 ? 1 : screenRect.width / width
    // Two scenes: the shown one, and the other, which loads the next one behind it and then fades in over
    // it, so moving between windows never shows empty places or a sudden change.
    property PeekScene front: firstScene
    property PeekScene old: null
    property bool loading: false
    // How long a scene may load before it is shown anyway (a picture that never arrives must not block it).
    readonly property int loadTimeout: 500

    WlrLayershell.namespace: 'hypraero-peek'
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    margins {
        bottom: barHeight
    }

    color: 'transparent'
    visible: wanted || content.opacity > 0
    // No input at all: the pointer belongs to the bar's popup under it.
    mask: Region {}

    onKeyChanged: route()
    onWantedChanged: route()

    // Once fully hidden nothing is kept: the next peek starts fresh.
    onVisibleChanged: {
        if (visible) {
            return
        }

        loading = false
        old = null
        firstScene.scene = null
        secondScene.scene = null
    }

    function route(): void {
        if (wanted === false) {
            loading = false
            return
        }

        const other = front === firstScene ? secondScene : firstScene
        if (front.scene === null) {
            front.scene = scene
            return
        }

        if (front.key === key) {
            // Refreshed, nothing changed, or came back to what is shown.
            front.scene = scene
            loading = false
            loadTimer.stop()
            return
        }

        if (old === other) {
            old = null
        }

        other.scene = scene
        loading = true
        loadTimer.restart()
        Qt.callLater(showLoaded, false)
    }

    function showLoaded(force: bool): void {
        const other = front === firstScene ? secondScene : firstScene
        if (loading === false || (force === false && other.ready === false)) {
            return
        }

        loading = false
        loadTimer.stop()
        old = front
        front = other
        clearTimer.restart()
    }

    Timer {
        id: loadTimer

        interval: root.loadTimeout
        onTriggered: root.showLoaded(true)
    }

    // Empties the scene that was faded over, so its captures stop.
    Timer {
        id: clearTimer

        interval: Theme.motionSoft
        onTriggered: {
            if (root.old !== null) {
                root.old.scene = null
                root.old = null
            }
        }
    }

    Item {
        id: content

        anchors.fill: parent
        opacity: root.wanted ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionSoft; easing.type: Easing.OutCubic }
        }

        PeekScene {
            id: firstScene

            anchors.fill: parent
            z: root.front === firstScene ? 2 : 1
            unit: root.unit
            active: root.visible
            opacity: root.front === firstScene || root.old === firstScene ? 1 : 0
            onReadyChanged: root.showLoaded(false)

            Behavior on opacity {
                NumberAnimation { duration: Theme.motionSoft; easing.type: Easing.OutCubic }
            }
        }

        PeekScene {
            id: secondScene

            anchors.fill: parent
            z: root.front === secondScene ? 2 : 1
            unit: root.unit
            active: root.visible
            opacity: root.front === secondScene || root.old === secondScene ? 1 : 0
            onReadyChanged: root.showLoaded(false)

            Behavior on opacity {
                NumberAnimation { duration: Theme.motionSoft; easing.type: Easing.OutCubic }
            }
        }
    }
}
