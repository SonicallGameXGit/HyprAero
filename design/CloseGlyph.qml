import QtQuick

// The flat "close" cross, one of the few structural glyphs that are not glossy icons (.aero/STYLE.md).
Item {
    id: root

    property int size: 8
    property int thickness: 2
    property color color: Theme.iconInk

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.centerIn: parent
        width: root.size * Math.SQRT2
        height: root.thickness
        radius: root.thickness / 2
        rotation: 45
        antialiasing: true
        color: root.color
    }

    Rectangle {
        anchors.centerIn: parent
        width: root.size * Math.SQRT2
        height: root.thickness
        radius: root.thickness / 2
        rotation: -45
        antialiasing: true
        color: root.color
    }
}
