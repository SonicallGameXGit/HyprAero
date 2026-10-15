import QtQuick
import QtQuick.Effects

// A short text naming a control, shown a moment after the pointer rests on it, in Windows 7's tooltip: a
// white to grey-blue face (tooltip-*) and the small menu shadow. Place it inside a parent
// that is big enough to hold it; `target` is the control, `shown` usually its hover.
Item {
    id: root

    property Item target: null
    property bool shown: false
    property string text: ''
    // How long the pointer must rest before it shows.
    readonly property int delay: 600

    property bool waited: false

    x: {
        if (target === null || parent === null) {
            return 0
        }

        const wanted = target.mapToItem(parent, target.width / 2, 0).x - width / 2
        return Math.max(Theme.space1, Math.min(wanted, parent.width - width - Theme.space1))
    }
    y: {
        if (target === null || parent === null) {
            return 0
        }

        const above = target.mapToItem(parent, 0, 0).y - height - Theme.space1
        return above >= 0 ? above : target.mapToItem(parent, 0, target.height).y + Theme.space1
    }
    z: 100
    width: label.implicitWidth + Theme.space2 * 2
    height: label.implicitHeight + Theme.space1 * 2
    visible: opacity > 0
    opacity: shown && waited && text !== '' && target !== null ? 1 : 0

    onShownChanged: {
        waited = false
        if (shown) {
            delayTimer.restart()
        }
    }

    Behavior on opacity {
        NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic }
    }

    Timer {
        id: delayTimer

        interval: root.delay
        onTriggered: root.waited = true
    }

    RectangularShadow {
        anchors.fill: parent
        radius: Theme.radiusControl
        offset.x: Theme.menuShadowOffset
        offset.y: Theme.menuShadowOffset
        blur: Theme.menuShadowBlur
        color: Theme.menuShadowColor
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusControl
        border.width: 1
        border.color: Theme.tooltipBorder

        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.tooltipFace[0] }
            GradientStop { position: 1.0; color: Theme.tooltipFace[1] }
        }
    }

    Text {
        id: label

        anchors.centerIn: parent
        text: root.text
        color: Theme.tooltipText
        font.family: Theme.fontUi
        font.pixelSize: Theme.fontSizeSmall
    }
}
