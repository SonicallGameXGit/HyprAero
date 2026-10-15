import QtQuick
import QtQuick.Effects

// A link, as Windows 7 puts at the bottom of a flyout or beside a list ("Customize...", "Restore default
// icon behaviors"): text-link coloured words, underlined under the pointer; on the shell's taskbar glass
// (`onGlass`) light words (taskbar-glass-link). With keyboard focus it glows (focus-glow) and Enter or Space
// follow it.
Item {
    id: root

    property string text: ''
    property bool onGlass: false

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

    GlassText {
        id: label

        text: root.text
        color: root.onGlass ? Theme.taskbarGlassLink : Theme.textLink
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
