pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import 'balloonShape.js' as BalloonShape

// Windows 7's notification balloon (.aero/STYLE.md "Notification balloons"): a tooltip's white to grey-blue
// face with its menu shadow, a stem on the edge nearest the corner it points at, a bold title with its 16px
// icon, a 48px picture left of the title and the words when there is one, a small close button at the top
// right and, when there are any, the action buttons along the bottom, wrapping onto more rows. It only draws
// and reports clicks: what a click does, how long it stays and its fading belong to whoever shows it.
Item {
    id: root

    property string title: ''
    property string text: ''
    // The 16px icon before the title: one of Windows' own icons (`WindowsIcon`, `iconName`) or a picture's
    // address (`iconSource`). `genericIcon` draws the stand-in for an app whose icon cannot be found, which a
    // picture that fails to load also gets.
    property string iconName: ''
    property string iconSource: ''
    property bool genericIcon: false
    // A picture sent with the notification (a chat avatar, an album cover), 48px left of the title and the
    // words, where Windows put its large balloon icon; the icon stays before the title.
    property string pictureSource: ''
    // The words of the action buttons, in order; the first is the main one.
    property var actions: []
    // Where the stem is: `stemEdge` 'top', 'bottom' or 'none'; `stemSide` 'left', 'center' or 'right'.
    property string stemEdge: 'none'
    property string stemSide: 'right'
    // The words wrap at this width.
    property int maxTextWidth: 300

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool hasStem: stemEdge === 'top' || stemEdge === 'bottom'
    readonly property int stemTop: stemEdge === 'top' ? Theme.balloonStemHeight : 0
    readonly property int stemBottom: stemEdge === 'bottom' ? Theme.balloonStemHeight : 0
    readonly property bool hasPicture: pictureSource !== ''
    readonly property bool hasIcon: iconName !== '' || iconSource !== '' || genericIcon
    readonly property int iconSize: 16
    readonly property int pictureSize: 48
    readonly property int closeSize: 16
    // The title's line keeps room for its icon and for the close button.
    readonly property int titleRoom: (hasIcon ? iconSize + Theme.space2 : 0) + Theme.space2 + closeSize
    // Rounded up: a width a fraction short of the words wraps their last one.
    readonly property int wordsWidth: Math.ceil(Math.min(maxTextWidth, Math.max(
        titleWidth.implicitWidth + titleRoom,
        bodyWidth.implicitWidth,
        actionsWidth,
    )))
    // The action buttons side by side; past the words' width they wrap.
    readonly property real actionsWidth: {
        let total = 0
        let count = 0
        for (const child of actionFlow.children) {
            if (child.visible) {
                total += child.implicitWidth
                count++
            }
        }

        return count === 0 ? 0 : total + Theme.space2 * (count - 1)
    }
    readonly property int wordsX: Theme.space3 + (hasPicture ? pictureSize + Theme.space2 : 0)

    signal clicked()
    signal closeClicked()
    signal actionClicked(int index)

    implicitWidth: wordsX + wordsWidth + Theme.space2
    implicitHeight: stemTop + Theme.space2 + Math.max(hasPicture ? pictureSize : 0, words.implicitHeight) + Theme.space3 + stemBottom
    Accessible.role: Accessible.AlertMessage
    Accessible.name: title
    Accessible.description: text

    // Under the outline, which draws over it again: the effect also draws its source, and without a GPU
    // (Qt's software renderer leaves effects out) the outline alone still shows.
    MultiEffect {
        anchors.fill: outline
        source: outline
        shadowEnabled: true
        shadowColor: Theme.menuShadowColor
        shadowHorizontalOffset: Theme.menuShadowOffset
        shadowVerticalOffset: Theme.menuShadowOffset
        shadowBlur: 1
        blurMax: Theme.menuShadowBlur
        autoPaddingEnabled: true
    }

    Shape {
        id: outline

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Theme.tooltipBorder
            strokeWidth: 1
            fillGradient: LinearGradient {
                y1: root.stemTop
                y2: root.height - root.stemBottom

                GradientStop { position: 0.0; color: Theme.tooltipFace[0] }
                GradientStop { position: 1.0; color: Theme.tooltipFace[1] }
            }

            PathSvg {
                path: BalloonShape.outline(root.width, root.height, Theme.radiusPanel, 1, {
                    edge: root.stemEdge,
                    side: root.stemSide,
                    width: Theme.balloonStemWidth,
                    height: Theme.balloonStemHeight,
                    inset: Theme.balloonStemInset,
                })
            }
        }
    }

    // The words' widths unwrapped: a Text that wraps reports the width it was given.
    Text {
        id: titleWidth

        visible: false
        text: titleText.text
        font: titleText.font
    }

    Text {
        id: bodyWidth

        visible: false
        text: bodyText.text
        font: bodyText.font
    }

    // A click anywhere but on a button is a click on the balloon.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    HoverHandler {
        id: hoverHandler
    }

    AppIconImage {
        x: Theme.space3
        y: root.stemTop + Theme.space2
        width: root.pictureSize
        height: root.pictureSize
        loadSize: root.pictureSize * 2
        fillMode: Image.PreserveAspectFit
        visible: root.hasPicture
        source: root.pictureSource
    }

    Column {
        id: words

        x: root.wordsX
        y: root.stemTop + Theme.space2
        width: root.wordsWidth
        spacing: Theme.space1

        Item {
            width: parent.width
            height: Math.max(root.iconSize, titleText.implicitHeight)

            WindowsIcon {
                visible: root.hasIcon && root.iconName !== ''
                name: root.iconName
                size: root.iconSize
            }

            AppIconImage {
                id: iconImage

                width: root.iconSize
                height: root.iconSize
                loadSize: root.iconSize * 4
                visible: root.iconName === '' && root.iconSource !== '' && status !== Image.Error
                source: root.iconName === '' ? root.iconSource : ''
            }

            GenericAppIcon {
                width: root.iconSize
                height: root.iconSize
                visible: root.iconName === '' && (root.iconSource === '' ? root.genericIcon : iconImage.status === Image.Error)
            }

            Text {
                id: titleText

                x: root.hasIcon ? root.iconSize + Theme.space2 : 0
                width: parent.width - root.titleRoom
                text: root.title
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
            }
        }

        Text {
            id: bodyText

            width: parent.width
            visible: root.text !== ''
            text: root.text
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Theme.text
            font.family: Theme.fontUi
            font.pixelSize: Theme.fontSizeSmall
        }

        Item {
            width: parent.width
            height: actionFlow.height + Theme.space1
            visible: root.actions.length > 0

            Flow {
                id: actionFlow

                anchors.bottom: parent.bottom
                width: parent.width
                spacing: Theme.space2

                Repeater {
                    model: root.actions

                    ControlButton {
                        id: actionButton

                        required property string modelData
                        required property int index

                        kind: index === 0 ? 'accent' : 'normal'
                        text: modelData
                        onClicked: root.actionClicked(actionButton.index)
                    }
                }
            }
        }
    }

    ControlButton {
        x: root.width - Theme.space2 - width
        y: root.stemTop + Theme.space2
        width: root.closeSize
        height: root.closeSize
        kind: 'tool'
        Accessible.name: qsTr('Close')
        onClicked: root.closeClicked()

        CloseGlyph {
            anchors.centerIn: parent
            size: 7
            color: Theme.tooltipText
        }
    }
}
