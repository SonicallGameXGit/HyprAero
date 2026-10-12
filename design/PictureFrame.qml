import QtQuick
import QtQuick.Effects

// A person's picture in the Windows 7 user tile: a band of glass around it (tint, dark outer and bright
// inner edge, shine over the top), a dark line along the picture, and the picture with small rounded
// corners. Laid on other glass it reads a little denser, as in Windows 7, and it follows the theme with
// the rest of the glass. What is put inside is the picture: it fills `pictureSize` and is cut to the
// rounded corners.
Item {
    id: root

    default property alias content: picture.data
    property int pictureSize: 48

    // The glass band around the picture, its dark outer edge included.
    readonly property int frameWidth: Theme.space1 + 1

    implicitWidth: pictureSize + frameWidth * 2
    implicitHeight: implicitWidth

    // A soft shade under the tile, so it stands off the glass.
    RectangularShadow {
        anchors.fill: parent
        radius: Theme.radiusPanel
        offset.y: 1
        blur: Theme.space1
        color: Theme.iconShadow
    }

    // Frosted under the glass: whiter than the glass it lies on, most at the top, so the band stands out
    // as the Windows 7 tile does (faint in Slate, as its shine is).
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Theme.radiusPanel - 1

        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.glassShineTop }
            GradientStop { position: 1.0; color: Theme.glassShineMiddle }
        }
    }

    GlassPanel {
        anchors.fill: parent
        cornerRadius: Theme.radiusPanel
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
