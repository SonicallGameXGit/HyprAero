import QtQuick

// An app icon from a file or the icon theme, smooth at any size. Theme icons often only exist as a big
// picture (256px), and the theme shrinks it to the asked size in one step, which leaves jagged edges.
// So the big picture is loaded as it is and the GPU shrinks it through mipmaps.
Image {
    readonly property int loadSize: 256

    sourceSize: Qt.size(loadSize, loadSize)
    asynchronous: true
    smooth: true
    mipmap: true
}
