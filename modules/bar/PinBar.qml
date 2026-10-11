pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.design
import qs.services
import '../../services/pins.js' as PinList

// The apps pinned to the bar, between two dotted grips right of the start orb, after Windows Vista's
// Quick Launch. Something that can be pinned (an app from the start menu, a window of a known app, a pin
// itself) dragged over it shows a glowing mark where it would go (`gap`); where a drop goes is the bar's
// decision. With nothing pinned the grips keep one pin's room between them, so there is a place to drop.
Item {
    id: root

    // The bar's screen, for the ghost a dragged pin leaves.
    property var screen: null
    // Where a drop would put it: the gap before pin `gap` (the number of pins: after the last), -1: none.
    property int gap: -1
    // The pinned apps shown. They hold still during a drag: rebuilding the pins would destroy the one a
    // drag started from.
    property var apps: []
    // The pinned app whose menu is open; its pin stays lit.
    property string menuApp: ''

    readonly property int pinWidth: 32
    readonly property int pinHeight: 40

    // `at` is in this item.
    signal menuRequested(var app, point at)
    signal pinHovered(Item pin, bool hovered)

    // The gap closest to `x` (in the bar window's coordinates).
    function gapAt(x: real): int {
        const slots = []
        for (let index = 0; index < pins.count; index++) {
            const pin = pins.itemAt(index)
            if (pin !== null) {
                const left = pin.mapToItem(null, 0, 0).x
                slots.push({ left: left, right: left + pin.width })
            }
        }

        return PinList.gapAt(x, slots)
    }

    Binding on apps {
        value: Pins.apps
        when: BarDrag.active === false
        restoreMode: Binding.RestoreNone
    }

    implicitWidth: rightGrip.x + rightGrip.width
    implicitHeight: pinHeight

    GripGlyph {
        id: leftGrip

        anchors.verticalCenter: parent.verticalCenter
        height: root.pinHeight - Theme.space2 * 2
    }

    Row {
        id: row

        x: leftGrip.width + Theme.space1
        width: Math.max(implicitWidth, root.pinWidth)
        height: root.pinHeight

        Repeater {
            id: pins

            model: root.apps

            PinButton {
                id: pin

                required property var modelData

                app: modelData
                screen: root.screen
                highlighted: root.menuApp === modelData.id
                onMenuRequested: at => root.menuRequested(pin.modelData, pin.mapToItem(root, at))
                onHoveredChanged: root.pinHovered(pin, pin.hovered)
            }
        }
    }

    GripGlyph {
        id: rightGrip

        x: row.x + row.width + Theme.space1
        anchors.verticalCenter: parent.verticalCenter
        height: root.pinHeight - Theme.space2 * 2
    }

    // The mark between two pins, glowing like a focused control.
    Item {
        readonly property real gapX: {
            if (pins.count === 0) {
                return row.width / 2
            }

            const after = pins.itemAt(Math.min(root.gap, pins.count - 1))
            if (after === null) {
                return 0
            }

            return root.gap < pins.count ? after.x : after.x + after.width
        }

        x: row.x + gapX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: root.pinHeight - Theme.space1 * 2
        visible: root.gap >= 0

        RectangularShadow {
            anchors.fill: parent
            blur: Theme.focusGlowBlur
            spread: Theme.focusGlowSpread
            color: Theme.focusGlowColor
        }

        Rectangle {
            anchors.fill: parent
            radius: 1
            color: Theme.focusGlowRing
        }
    }
}
