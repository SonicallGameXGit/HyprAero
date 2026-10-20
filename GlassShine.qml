import QtQuick
import QtQuick.Shapes

// Windows 7's gloss on the taskbar's glass buttons (.aero/STYLE.md, "Taskbar items"): a see-through sheet of
// light over the top-left of a face, its lower edge a sharp curve from `leftY` on the left side up to `rightY`
// on the right (fractions of the height), lighter toward the top-left corner. Fill the face with it.
Shape {
    id: root

    property real leftY: 0.65
    property real rightY: 0
    // At the top-left corner, and along the curve.
    property color strong: Theme.taskbarItemShine[0]
    property color faint: Theme.taskbarItemShine[1]

    // The curve's control point, and the middle of the curve the light fades toward.
    readonly property point control: Qt.point(width * 0.4, height * (leftY + rightY) * 0.33)
    readonly property point middle: Qt.point(width * 0.25 + control.x * 0.5, height * (leftY + rightY) * 0.25 + control.y * 0.5)

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeWidth: -1
        strokeColor: 'transparent'

        fillGradient: LinearGradient {
            x1: 0
            y1: 0
            x2: root.middle.x
            y2: root.middle.y

            GradientStop { position: 0.0; color: root.strong }
            GradientStop { position: 1.0; color: root.faint }
        }

        PathSvg {
            path: `M 0 0 L ${root.width} 0 L ${root.width} ${root.height * root.rightY}`
                + ` Q ${root.control.x} ${root.control.y} 0 ${root.height * root.leftY} Z`
        }
    }
}
