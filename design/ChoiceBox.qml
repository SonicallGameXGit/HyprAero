import QtQuick

// A drop-down list, as Windows 7's: a normal button showing the chosen words on the left and a small arrow
// pointing down on the right. A click (or Enter, Space, Down with keyboard focus) asks the owner for the
// list (`listRequested`), which it shows as a `MenuPanel` under the box; the owner sets `choice`.
ControlButton {
    id: root

    property string choice: ''

    signal listRequested()

    implicitWidth: label.implicitWidth + arrow.width + Theme.space3 * 3
    activeFocusOnTab: true
    Accessible.role: Accessible.ComboBox
    Accessible.name: choice
    Keys.onDownPressed: listRequested()
    onClicked: {
        forceActiveFocus()
        listRequested()
    }

    Text {
        id: label

        x: Theme.space3
        width: arrow.x - x - Theme.space2
        anchors.verticalCenter: parent.verticalCenter
        text: root.choice
        elide: Text.ElideRight
        color: root.enabled ? Theme.controlText : Theme.controlTextDisabled
        font.family: Theme.fontUi
        font.pixelSize: Theme.fontSizeBody
    }

    ChevronGlyph {
        id: arrow

        anchors.right: parent.right
        anchors.rightMargin: Theme.space3
        anchors.verticalCenter: parent.verticalCenter
        rotation: 90
        color: root.enabled ? Theme.controlText : Theme.controlTextDisabled
    }
}
