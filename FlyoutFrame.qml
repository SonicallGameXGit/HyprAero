import QtQuick

// A flyout over the notification area, as Windows 7 draws them (the clock, the volume, the network, the
// power, the hidden icons; .aero/STYLE.md "Flyouts over the notification area"): a frame of window glass
// (a dark line, a light line, the glass, a light line, a dark line) around a white body, and the links in a
// band along the bottom whose top fades in. Children go on the body (`body`, inside the frame); `band`
// holds what goes in the band, `bandHeight` 0 leaves it out.
Item {
    id: root

    default property alias content: body.data
    property alias band: bandArea.data
    property int bandHeight: 0

    // From the outside to the body: 1 + 1 + 4 + 1 + 1.
    readonly property int frameWidth: 8
    readonly property alias body: body

    GlassPanel {
        anchors.fill: parent
        cornerRadius: Theme.radiusPanel
        kind: 'window'
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.frameWidth - 2
        color: 'transparent'
        border.width: 1
        border.color: Theme.glassBorderInner
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.frameWidth - 1
        color: Theme.surface
        border.width: 1
        border.color: Theme.glassBorderOuter

        Rectangle {
            x: 1
            width: parent.width - 2
            height: root.bandHeight
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            visible: root.bandHeight > 0
            color: Theme.surfaceSunken

            Rectangle {
                width: parent.width
                height: 5

                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.toolbarBorder }
                    GradientStop { position: 1.0; color: Theme.surfaceSunken }
                }
            }

            Item {
                id: bandArea

                anchors.fill: parent
            }
        }
    }

    Item {
        id: body

        anchors.fill: parent
        anchors.margins: root.frameWidth
    }
}
