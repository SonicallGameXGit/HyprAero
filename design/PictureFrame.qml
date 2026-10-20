import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// A person's picture in the Windows 7 user tile (.aero/STYLE.md, "User picture tile"): a silver glossy band
// around it, white at the top and aqua along the bottom, its outer sides bowed out a little at their middle so
// the band is widest there; a dark line along the picture with a light one outside it, and the picture with
// small rounded corners. What is put inside is the picture: it fills `pictureSize` and is cut to the rounded
// corners.
Item {
    id: root

    default property alias content: picture.data
    property int pictureSize: 48

    // The band around the picture, its outer edge included.
    readonly property int frameWidth: Theme.space1 + 2
    // The band's outline: straight corners `bulge` inside the item, each side bowing out to the item's edge
    // at its middle.
    readonly property string outline: {
        const size = width
        const bulge = Theme.pictureFrameBulge
        const corner = Theme.radiusPanel
        const near = bulge + corner
        const far = size - bulge - corner
        const middle = size / 2
        const edge = size - bulge
        return `M ${near} ${bulge} Q ${middle} ${-bulge} ${far} ${bulge}`
            + ` A ${corner} ${corner} 0 0 1 ${edge} ${near} Q ${size + bulge} ${middle} ${edge} ${far}`
            + ` A ${corner} ${corner} 0 0 1 ${far} ${edge} Q ${middle} ${size + bulge} ${near} ${edge}`
            + ` A ${corner} ${corner} 0 0 1 ${bulge} ${far} Q ${-bulge} ${middle} ${bulge} ${near}`
            + ` A ${corner} ${corner} 0 0 1 ${near} ${bulge} Z`
    }

    implicitWidth: pictureSize + frameWidth * 2
    implicitHeight: implicitWidth

    // A soft shade under the tile, so it stands off the glass.
    RectangularShadow {
        anchors.fill: parent
        anchors.margins: Theme.pictureFrameBulge
        radius: Theme.radiusPanel
        offset.y: 1
        blur: Theme.space1
        color: Theme.iconShadow
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 1
            strokeColor: Theme.glassBorderOuter

            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: root.height

                GradientStop { position: 0.0; color: Theme.pictureFrameFace[0] }
                GradientStop { position: 0.5; color: Theme.pictureFrameFace[1] }
                GradientStop { position: 0.85; color: Theme.pictureFrameFace[2] }
                GradientStop { position: 1.0; color: Theme.pictureFrameFace[3] }
            }

            PathSvg {
                path: root.outline
            }
        }

        // The gloss over the upper half.
        ShapePath {
            strokeWidth: -1
            strokeColor: 'transparent'

            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: root.height / 2

                GradientStop { position: 0.0; color: Theme.pictureFrameShine }
                GradientStop { position: 1.0; color: Qt.alpha(Theme.pictureFrameShine, 0) }
            }

            PathSvg {
                path: root.outline
            }
        }
    }

    // A light line outside the dark one along the picture, so the picture sits in the band as cut into it.
    Rectangle {
        x: root.frameWidth - 2
        y: x
        width: root.pictureSize + 4
        height: width
        radius: Theme.radiusControl + 2
        color: Theme.glassBorderInner
    }

    // The dark line between the frame and the picture: one pixel of it shows around the picture.
    Rectangle {
        x: root.frameWidth - 1
        y: x
        width: root.pictureSize + 2
        height: width
        radius: Theme.radiusControl + 1
        color: Theme.glassBorderOuter
    }

    // Drawn only through the effect below, which cuts its corners. Not as the picture's own `layer.effect`:
    // that one was missing from item grabs (`grabToImage`), while an effect beside it is not.
    Item {
        id: picture

        x: root.frameWidth
        y: x
        width: root.pictureSize
        height: width
        visible: false
    }

    MultiEffect {
        anchors.fill: picture
        source: picture
        maskEnabled: true
        maskSource: corners
        // A soft one-pixel edge, so the rounded corners are smooth.
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }

    Rectangle {
        id: corners

        width: root.pictureSize
        height: width
        radius: Theme.radiusControl
        visible: false
        layer.enabled: true
    }
}
