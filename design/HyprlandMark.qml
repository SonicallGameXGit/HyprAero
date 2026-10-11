import QtQuick
import QtQuick.Shapes

// The Hyprland mark (the open drop), as vectors, for the start orb. Its height is `size`, its width
// follows the mark's own proportions.
//
// The path is taken unchanged from Hyprland's `assets/header.svg`:
// Copyright (c) 2022-2026, vaxerski. All rights reserved.
// Redistributed under the BSD 3-Clause License of the Hyprland project
// (https://github.com/hyprwm/Hyprland/blob/main/LICENSE). The Hyprland name and mark do not endorse
// this shell.
Item {
    id: root

    property real size: 24
    property color topColor: Theme.orbMarkTop
    property color bottomColor: Theme.orbMarkBottom

    // The mark's box in the units of its path.
    readonly property real pathLeft: 81.2
    readonly property real pathTop: 346.78
    readonly property real pathWidth: 241.8
    readonly property real pathHeight: 312.92

    implicitWidth: size * pathWidth / pathHeight
    implicitHeight: size

    // The path keeps its own coordinates; the shape is shifted so the mark's box starts at 0, 0.
    Shape {
        x: -root.pathLeft * scale
        y: -root.pathTop * scale
        width: root.pathLeft + root.pathWidth
        height: root.pathTop + root.pathHeight
        scale: root.size / root.pathHeight
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: 'transparent'

            fillGradient: LinearGradient {
                x1: 0
                y1: root.pathTop
                x2: 0
                y2: root.pathTop + root.pathHeight

                GradientStop { position: 0.0; color: root.topColor }
                GradientStop { position: 1.0; color: root.bottomColor }
            }

            PathSvg {
                path: 'M311.03,491.55c-9.09-20.56-22.42-39.71-35.29-58.22-2.38-3.41-4.62-6.64-6.84-9.87-3.15-4.6-7.42-10.49-12.36-17.31-11.29-15.59-28.92-39.62-40.84-59.36v49.42c12.28,17.62,24.2,33.49,30.57,42.78,13.94,20.33,30.09,42,39.67,63.66,28.78,65.13-11.7,128.85-82.05,129.61h-1.26c-.18,0-.35,0-.53,0-.18,0-.35,0-.53,0h-1.26c-70.35-.76-110.84-64.48-82.05-129.61,9.58-21.67,25.72-43.33,39.67-63.66,6.36-9.28,18.28-25.16,30.57-42.78v-49.42c-11.92,19.75-29.55,43.78-40.84,59.36-4.94,6.81-9.21,12.7-12.36,17.31-2.22,3.23-4.46,6.45-6.84,9.87-12.88,18.52-26.21,37.67-35.29,58.22-8.83,19.97-12.7,40.38-11.49,60.65,1.16,19.65,7.28,38.57,17.68,54.73,10.28,15.97,24.74,29.21,41.81,38.29,17.64,9.37,37.44,14.25,58.87,14.48.52,0,1.03,0,1.56,0,.18,0,.35,0,.53,0,.18,0,.35,0,.53,0,.52,0,1.03,0,1.56,0,21.43-.23,41.23-5.1,58.87-14.48,17.07-9.08,31.52-22.32,41.81-38.29,10.4-16.16,16.52-35.08,17.68-54.73,1.2-20.27-2.67-40.68-11.49-60.65Z'
            }
        }
    }
}
