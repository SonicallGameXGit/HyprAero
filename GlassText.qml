import QtQuick

// Words on glass in the glass's own text colour. kind: 'taskbar' (the shell's dark glass: white words, as
// in the Windows 7 start menu) or 'window' (a window's pale glass: dark words).
Text {
    property string kind: 'taskbar'

    color: kind === 'taskbar' ? Theme.taskbarGlassText : Theme.glassText
    font.family: Theme.fontUi
    font.pixelSize: Theme.fontSizeBody
}
