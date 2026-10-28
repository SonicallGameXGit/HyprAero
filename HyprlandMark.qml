pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

// The Hyprland mark (the open drop), as vectors, for the start orb. Its height is `size`, its width
// follows the mark's own proportions, and the item is `margin` bigger on every side for its weight. In
// Hyprland's colours, or in Windows 7's flag's (.aero/STYLE.md "Start orb"); either can be split into the
// flag's four panes by gaps, and drawn bolder.
//
// The path is taken unchanged from Hyprland's `assets/header.svg`:
// Copyright (c) 2022-2026, vaxerski. All rights reserved.
// Redistributed under the BSD 3-Clause License of the Hyprland project
// (https://github.com/hyprwm/Hyprland/blob/main/LICENSE). The Hyprland name and mark do not endorse
// this shell.
Item {
    id: root

    property real size: 24
    // 'hyprland' (`topColor` -> `bottomColor`) or 'windows' (the flag's four panes).
    property string colors: 'hyprland'
    // The four panes parted by gaps as wide as the opening at the mark's top.
    property bool gaps: false
    // How much bolder than Hyprland's own mark it is drawn, in the units of its path: its outline is
    // stroked this wide in its own colours, half of it outside the mark, half inside.
    property real weight: 0
    property color topColor: Theme.orbMarkTop
    property color bottomColor: Theme.orbMarkBottom

    // The mark's box in the units of its path.
    readonly property real pathLeft: 81.2
    readonly property real pathTop: 346.78
    readonly property real pathWidth: 241.8
    readonly property real pathHeight: 312.92
    // The opening between the drop's two tips (x 188.5 to 215.7 in the path, narrowed by the weight),
    // centred on the mark.
    readonly property real gap: gaps ? size * Math.max(27.2 - weight, 0) / pathHeight : 0
    // Room around the mark for the half of its weight outside it and its antialiased edge: a layer over
    // the item (the orb's glow and brightness) draws only what is inside it.
    readonly property real margin: size * weight / 2 / pathHeight + 1
    readonly property bool split: gaps || colors === 'windows'

    implicitWidth: size * pathWidth / pathHeight + 2 * margin
    implicitHeight: size + 2 * margin

    // The whole mark, its gradient from `start` to `end` (parts of its height).
    component Drop: Shape {
        id: drop

        property color startColor: root.topColor
        property color endColor: root.bottomColor
        property real start: 0
        property real end: 1
        // One gradient for the fill and the stroke, so the weight is the mark's own colour.
        property LinearGradient gradient: LinearGradient {
            x1: 0
            y1: root.pathTop + root.pathHeight * drop.start
            x2: 0
            y2: root.pathTop + root.pathHeight * drop.end

            GradientStop { position: 0.0; color: drop.startColor }
            GradientStop { position: 1.0; color: drop.endColor }
        }

        // The path keeps its own coordinates; the shape is shifted so the mark's box starts at the margin.
        x: root.margin - root.pathLeft * drop.scale
        y: root.margin - root.pathTop * drop.scale
        width: root.pathLeft + root.pathWidth
        height: root.pathTop + root.pathHeight
        scale: root.size / root.pathHeight
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            // A width of 0 would still draw a hairline; below 0 nothing is stroked.
            strokeWidth: root.weight > 0 ? root.weight : -1
            joinStyle: ShapePath.RoundJoin
            fillGradient: drop.gradient
            strokeGradient: drop.gradient

            PathSvg {
                path: 'M311.03,491.55c-9.09-20.56-22.42-39.71-35.29-58.22-2.38-3.41-4.62-6.64-6.84-9.87-3.15-4.6-7.42-10.49-12.36-17.31-11.29-15.59-28.92-39.62-40.84-59.36v49.42c12.28,17.62,24.2,33.49,30.57,42.78,13.94,20.33,30.09,42,39.67,63.66,28.78,65.13-11.7,128.85-82.05,129.61h-1.26c-.18,0-.35,0-.53,0-.18,0-.35,0-.53,0h-1.26c-70.35-.76-110.84-64.48-82.05-129.61,9.58-21.67,25.72-43.33,39.67-63.66,6.36-9.28,18.28-25.16,30.57-42.78v-49.42c-11.92,19.75-29.55,43.78-40.84,59.36-4.94,6.81-9.21,12.7-12.36,17.31-2.22,3.23-4.46,6.45-6.84,9.87-12.88,18.52-26.21,37.67-35.29,58.22-8.83,19.97-12.7,40.38-11.49,60.65,1.16,19.65,7.28,38.57,17.68,54.73,10.28,15.97,24.74,29.21,41.81,38.29,17.64,9.37,37.44,14.25,58.87,14.48.52,0,1.03,0,1.56,0,.18,0,.35,0,.53,0,.18,0,.35,0,.53,0,.52,0,1.03,0,1.56,0,21.43-.23,41.23-5.1,58.87-14.48,17.07-9.08,31.52-22.32,41.81-38.29,10.4-16.16,16.52-35.08,17.68-54.73,1.2-20.27-2.67-40.68-11.49-60.65Z'
            }
        }
    }

    Drop {
        visible: root.split === false
    }

    // The flag's panes, each the mark cut to its quarter. In the flag's colours each pane has its own
    // gloss over its own half; in Hyprland's the mark keeps its one gradient across the cuts.
    Repeater {
        model: [
            { left: true, top: true, light: Theme.orbFlagRedTop, dark: Theme.orbFlagRedBottom },
            { left: false, top: true, light: Theme.orbFlagGreenTop, dark: Theme.orbFlagGreenBottom },
            { left: true, top: false, light: Theme.orbFlagBlueTop, dark: Theme.orbFlagBlueBottom },
            { left: false, top: false, light: Theme.orbFlagYellowTop, dark: Theme.orbFlagYellowBottom },
        ]

        Item {
            id: pane

            required property var modelData

            readonly property bool flag: root.colors === 'windows'

            visible: root.split
            x: modelData.left ? 0 : root.width / 2 + root.gap / 2
            y: modelData.top ? 0 : root.height / 2 + root.gap / 2
            width: root.width / 2 - root.gap / 2
            height: root.height / 2 - root.gap / 2
            clip: true

            Drop {
                id: paneDrop

                x: root.margin - pane.x - root.pathLeft * paneDrop.scale
                y: root.margin - pane.y - root.pathTop * paneDrop.scale
                startColor: pane.flag ? pane.modelData.light : root.topColor
                endColor: pane.flag ? pane.modelData.dark : root.bottomColor
                start: pane.flag && pane.modelData.top === false ? 0.5 : 0
                end: pane.flag && pane.modelData.top ? 0.5 : 1
            }
        }
    }
}
