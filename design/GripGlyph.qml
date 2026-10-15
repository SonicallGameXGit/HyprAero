pragma ComponentBehavior: Bound

import QtQuick

// The dotted grip at each end of a toolbar on the bar, after Windows Vista's Quick Launch: two columns of
// small etched dots, each a dark dot with a light one under it to the right, like the glass edge. A flat
// structural glyph; it fills its height with as many rows as fit.
Item {
    id: root

    readonly property int pitch: 4
    // The right column sits half a step lower, so the dots stagger.
    readonly property int rows: Math.max(Math.floor((height - pitch / 2) / pitch), 1)

    implicitWidth: pitch + 3
    implicitHeight: pitch * 6

    Repeater {
        model: root.rows * 2

        Item {
            required property int index

            x: (index % 2) * root.pitch
            y: Math.floor(index / 2) * root.pitch + (index % 2) * root.pitch / 2
            width: 3
            height: 3

            Rectangle {
                x: 1
                y: 1
                width: 2
                height: 2
                color: Theme.taskbarGlassBorderInner
            }

            Rectangle {
                width: 2
                height: 2
                color: Theme.taskbarGlassBorderOuter
            }
        }
    }
}
