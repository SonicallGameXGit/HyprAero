import QtQuick
import QtQuick.Shapes

// A slider, as Windows 7's trackbar (the volume): a narrow sunken channel, a pale ramp beside it widening
// towards the most, tick marks at both ends and the middle, and an aqua thumb pointing at the ramp
// (trackbar-*). Vertical (the most at the top, as the volume flyout) or horizontal (the most at the right,
// the same drawing turned). Drag the thumb, press the channel to bring it there, turn the wheel, or with
// keyboard focus (it glows, focus-glow) use the arrows, Page Up / Down, Home and End. It tells its new
// value (`moved`, 0 to 1); the owner sets `value`. With `quiet` set, the thumb is a plain grey one while the
// slider does not have the keyboard, as in the Volume Mixer where only one column is aqua.
Item {
    id: root

    property real value: 0
    property bool vertical: true
    // How much one arrow key or wheel notch moves it.
    property real step: 0.02
    property bool quiet: false

    readonly property int thumbLong: 21
    readonly property int thumbShort: 10
    readonly property real length: vertical ? height : width
    readonly property real travel: length - thumbShort
    readonly property bool held: mouseArea.pressed
    readonly property bool plain: quiet && activeFocus === false

    signal moved(real value)

    function valueAt(position: real): real {
        if (travel <= 0) {
            return 0
        }

        const part = Math.min(1, Math.max(0, (position - thumbShort / 2) / travel))
        return vertical ? 1 - part : part
    }

    function nudge(by: real): void {
        moved(Math.min(1, Math.max(0, Math.round((value + by) * 100) / 100)))
    }

    implicitWidth: vertical ? thumbLong : 120
    implicitHeight: vertical ? 120 : thumbLong
    activeFocusOnTab: true
    Accessible.role: Accessible.Slider
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Up || event.key === Qt.Key_Right) {
            nudge(step)
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Left) {
            nudge(-step)
        } else if (event.key === Qt.Key_PageUp) {
            nudge(step * 5)
        } else if (event.key === Qt.Key_PageDown) {
            nudge(-step * 5)
        } else if (event.key === Qt.Key_Home) {
            moved(vertical ? 1 : 0)
        } else if (event.key === Qt.Key_End) {
            moved(vertical ? 0 : 1)
        } else {
            return
        }

        event.accepted = true
    }

    // Drawn standing up, the most at the top; turned a quarter clockwise when horizontal (the most then at
    // the right, the thumb pointing down).
    Item {
        id: track

        readonly property real most: root.thumbShort / 2
        readonly property real least: height - root.thumbShort / 2

        anchors.centerIn: parent
        width: root.thumbLong
        height: root.length
        rotation: root.vertical ? 0 : 90

        // The channel: its edge on the left and top, its light line on the right.
        Rectangle {
            x: 2
            y: track.most - 1
            width: 6
            height: track.least - track.most + 2
            color: root.activeFocus ? Theme.focusGlowRing : Theme.trackbarChannelEdge

            Rectangle {
                x: 1
                y: 1
                width: 4
                height: parent.height - 1
                color: Theme.trackbarChannel
            }

            Rectangle {
                x: 5
                y: 1
                width: 1
                height: parent.height - 1
                color: Theme.trackbarChannelLight
            }
        }

        // The ramp, from nothing at the least to its full width at the most.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: 'transparent'
                fillColor: Theme.trackbarRamp
                startX: 8
                startY: track.most

                PathLine { x: 18; y: track.most }
                PathLine { x: 9; y: track.least }
                PathLine { x: 8; y: track.least }
                PathLine { x: 8; y: track.most }
            }
        }

        Repeater {
            model: [track.most, (track.most + track.least) / 2, track.least]

            Rectangle {
                required property real modelData

                x: 18
                y: modelData
                width: 3
                height: 1
                color: Theme.trackbarTick
            }
        }

        // The thumb, pointing at the ramp.
        Shape {
            id: thumb

            y: track.most + (track.least - track.most) * (1 - Math.min(1, Math.max(0, root.value))) - height / 2
            width: root.thumbLong
            height: root.thumbShort
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: root.activeFocus ? Theme.focusGlowRing : (root.plain ? Theme.trackbarThumbQuietBorder : Theme.trackbarThumbBorder)
                strokeWidth: 1
                joinStyle: ShapePath.MiterJoin
                fillGradient: LinearGradient {
                    y2: thumb.height

                    GradientStop { position: 0.0; color: root.plain ? Theme.trackbarThumbQuietFaceTop : Theme.trackbarThumbFaceTop }
                    GradientStop { position: 1.0; color: root.plain ? Theme.trackbarThumbQuietFaceBottom : Theme.trackbarThumbFaceBottom }
                }
                startX: 0.5
                startY: 0.5

                PathLine { x: 16.5; y: 0.5 }
                PathLine { x: 20.5; y: 5 }
                PathLine { x: 16.5; y: 9.5 }
                PathLine { x: 0.5; y: 9.5 }
                PathLine { x: 0.5; y: 0.5 }
            }

            // The bright rim inside the border.
            ShapePath {
                strokeColor: root.plain ? 'transparent' : (root.held ? Theme.trackbarThumbRimBottom : Theme.trackbarThumbRimTop)
                strokeWidth: 1
                fillColor: 'transparent'
                startX: 1.5
                startY: 1.5

                PathLine { x: 16; y: 1.5 }
                PathLine { x: 19.2; y: 5 }
                PathLine { x: 16; y: 8.5 }
                PathLine { x: 1.5; y: 8.5 }
                PathLine { x: 1.5; y: 1.5 }
            }
        }
    }

    // A press anywhere brings the thumb there, and it follows the pointer while held.
    MouseArea {
        id: mouseArea

        anchors.fill: parent
        preventStealing: true
        onPressed: mouse => {
            root.forceActiveFocus()
            root.moved(root.valueAt(root.vertical ? mouse.y : mouse.x))
        }
        onPositionChanged: mouse => {
            if (pressed) {
                root.moved(root.valueAt(root.vertical ? mouse.y : mouse.x))
            }
        }
    }

    WheelHandler {
        onWheel: event => {
            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
            root.nudge(root.step * delta / 120)
        }
    }
}
