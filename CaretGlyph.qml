import QtQuick
import QtQuick.Shapes

// The thin caret of a group heading that folds (Windows 7's network flyout): pointing up while the group is
// open (`folded` false), down while it is folded. Drawn in an 8 x 8 box.
Item {
    id: root

    property bool folded: false
    property color color: Theme.headingText

    implicitWidth: 8
    implicitHeight: 8

    Shape {
        anchors.fill: parent
        rotation: root.folded ? 180 : 0
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: 2
            fillColor: 'transparent'
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.MiterJoin
            startX: 1
            startY: 6

            PathLine { x: 4; y: 3 }
            PathLine { x: 7; y: 6 }
        }
    }
}
