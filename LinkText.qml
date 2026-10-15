import QtQuick
import QtQuick.Effects

// A link, as Windows 7 puts at the bottom of a flyout or beside a list ("Customize...", "Restore default
// icon behaviors"): text-link coloured words, underlined under the pointer. With keyboard focus it glows
// (focus-glow) and Enter or Space follow it.
Item {
    id: root

    property string text: ''

    signal clicked()

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    Accessible.role: Accessible.Link
    Accessible.name: text
    Accessible.onPressAction: clicked()
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onSpacePressed: clicked()

    RectangularShadow {
        anchors.fill: parent
        anchors.margins: -2
        radius: Theme.radiusControl
        blur: Theme.focusGlowBlur
        spread: Theme.focusGlowSpread
        color: Theme.focusGlowColor
        visible: root.activeFocus
    }

    Text {
        id: label

        text: root.text
        color: Theme.textLink
        font.family: Theme.fontUi
        font.pixelSize: Theme.fontSizeBody
        font.underline: hoverHandler.hovered
    }

    HoverHandler {
        id: hoverHandler
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
