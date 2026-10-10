import Quickshell
import QtQuick
import qs.design

// The window previews of a workspace, shown above its button (the cards are `PreviewCards`).
//
// The popup window itself is created once, as wide as the bar, and never moves; only the glass panel
// inside it glides to the hovered button. Moving or resizing a popup window makes the compositor
// re-place it, which showed as a jump to the screen corner. The window passes the pointer through
// everywhere except on the panel.
PopupWindow {
    id: root

    // The workspace and windows to show, the x of the hovered button's center in the bar, and whether to
    // show at all.
    property int workspaceId: 0
    property var windows: []
    property real centerX: 0
    property bool shown: false

    readonly property int edgeMargin: Theme.space2
    // Room for the tallest list (three rows of cards) so the window never has to resize.
    readonly property int windowHeight: 520
    // The first placement after a pause snaps; only moves between buttons glide.
    property bool glide: false
    // Two card sets: the shown one, and the other one, which loads the next workspace behind it while
    // `loading` and then fades in, so moving between workspaces never shows empty cards.
    property PreviewCards front: firstCards
    property bool loading: false
    // How long a set may load before it is shown anyway (a picture that never arrives must not block it).
    readonly property int loadTimeout: 500

    signal hoverChanged(bool hovered)

    implicitWidth: anchor.rect.width
    implicitHeight: windowHeight
    color: 'transparent'
    visible: shown || panel.opacity > 0
    mask: Region {
        item: panel
    }

    onWorkspaceIdChanged: route()
    onWindowsChanged: route()

    // Once fully hidden, nothing is kept: the next opening starts fresh.
    onVisibleChanged: {
        if (visible) {
            return
        }

        loading = false
        firstCards.windows = []
        secondCards.windows = []
        firstCards.workspaceId = 0
        secondCards.workspaceId = 0
    }

    onShownChanged: {
        if (shown) {
            route()
            return
        }

        glide = false
    }

    // A refresh of the shown workspace updates its cards in place. Another workspace loads in the other set
    // and is shown once ready (`showLoaded`). With nothing shown yet there is nothing to keep, so it goes
    // straight to the front.
    function route(): void {
        const other = front === firstCards ? secondCards : firstCards
        if (front.windows.length === 0) {
            loading = false
            front.workspaceId = workspaceId
            front.windows = windows
            return
        }

        if (front.workspaceId === workspaceId) {
            front.windows = windows
            if (loading) {
                loading = false
                other.windows = []
                other.workspaceId = 0
            }

            return
        }

        other.workspaceId = workspaceId
        other.windows = windows
        loading = true
        loadTimer.restart()
        // Coming back to the set that is still fading out: it is already loaded.
        Qt.callLater(showLoaded, false)
    }

    function showLoaded(force: bool): void {
        const other = front === firstCards ? secondCards : firstCards
        if (loading === false || (force === false && other.ready === false)) {
            return
        }

        loading = false
        loadTimer.stop()
        front = other
        clearTimer.restart()
    }

    Timer {
        id: loadTimer

        interval: root.loadTimeout
        onTriggered: root.showLoaded(true)
    }

    // Empties the set that faded out, so its captures stop and the next load starts with fresh cards.
    Timer {
        id: clearTimer

        interval: Theme.motionSoft
        onTriggered: {
            if (root.loading) {
                return
            }

            const other = root.front === firstCards ? secondCards : firstCards
            other.windows = []
            other.workspaceId = 0
        }
    }

    // Once the panel has been placed, later moves animate.
    Timer {
        id: glideTimer

        interval: 30
        running: root.shown
        onTriggered: root.glide = true
    }

    GlassPanel {
        id: panel

        readonly property real wantedX: root.centerX - width / 2

        x: Math.max(root.edgeMargin, Math.min(wantedX, root.width - width - root.edgeMargin))
        y: root.height - height
        width: root.front.implicitWidth + Theme.space3 * 2
        height: root.front.implicitHeight + Theme.space3 * 2
        cornerRadius: Theme.radiusPanel
        opacity: root.shown && root.windows.length > 0 ? 1 : 0

        Behavior on x {
            enabled: root.glide
            NumberAnimation { duration: Theme.motionSoft; easing.type: Easing.OutCubic }
        }

        Behavior on width {
            enabled: root.glide
            NumberAnimation { duration: Theme.motionSoft; easing.type: Easing.OutCubic }
        }

        Behavior on height {
            enabled: root.glide
            NumberAnimation { duration: Theme.motionSoft; easing.type: Easing.OutCubic }
        }

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
        }

        // Lets the bar keep the popup open while the pointer is on it, not only on the button.
        HoverHandler {
            onHoveredChanged: root.hoverChanged(hovered)
        }


        // Both sets sit in the same place; the one fading out may be bigger than the panel for a moment.
        Item {
            anchors.fill: parent
            clip: true

            PreviewCards {
                id: firstCards

                property int workspaceId: 0

                x: Theme.space3
                y: Theme.space3
                active: root.visible && (root.front === firstCards || root.loading)
                opacity: root.front === firstCards ? 1 : 0
                onReadyChanged: root.showLoaded(false)

                Behavior on opacity {
                    NumberAnimation { duration: Theme.motionSoft; easing.type: Easing.OutCubic }
                }
            }

            PreviewCards {
                id: secondCards

                property int workspaceId: 0

                x: Theme.space3
                y: Theme.space3
                active: root.visible && (root.front === secondCards || root.loading)
                opacity: root.front === secondCards ? 1 : 0
                onReadyChanged: root.showLoaded(false)

                Behavior on opacity {
                    NumberAnimation { duration: Theme.motionSoft; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
