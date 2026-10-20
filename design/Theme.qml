pragma Singleton

import Quickshell
import QtQuick
import qs.services

// The only place visual values are written (.aero/STYLE.md section 4). Only the tokens that
// the existing primitives use are here; add the rest here first when something needs them.
Singleton {
    id: root

    // Follows the system colour scheme. Aero (light) when the system says light or has no
    // preference, Slate (dark) when it says dark.
    readonly property bool slate: SystemTheme.dark

    readonly property var fontCandidates: [
        'Segoe UI',
        'Selawik',
        'Noto Sans',
        'Open Sans',
        'Helvetica Neue',
        'sans-serif',
    ]
    // QML's font.family takes one name, so pick the first candidate that is installed.
    readonly property string fontUi: {
        const installed = Qt.fontFamilies()
        for (const candidate of fontCandidates) {
            if (installed.includes(candidate)) {
                return candidate
            }
        }

        return Qt.application.font.family
    }
    readonly property int fontSizeSmall: 12
    readonly property int fontSizeBody: 13
    readonly property int fontSizeHeading: 16

    readonly property int space1: 4
    readonly property int space2: 8
    readonly property int space3: 12
    readonly property int space4: 16
    readonly property int space5: 24

    readonly property int radiusControl: 3
    readonly property int radiusPanel: 6
    readonly property int radiusWindow: 8

    readonly property int motionFast: 120

    readonly property color glassTint: slate ? '#a8262e38' : '#94d6e9fa'
    readonly property color glassBorderOuter: slate ? '#cc000000' : '#8c14325a'
    readonly property color glassBorderInner: slate ? '#33ffffff' : '#bfffffff'
    readonly property color glassShineTop: slate ? '#29ffffff' : '#99ffffff'
    readonly property color glassShineMiddle: slate ? '#08ffffff' : '#1fffffff'
    readonly property color glassText: slate ? '#e9eef3' : '#0d2238'
    // The shell's own chrome (bar, start menu, flyouts): Windows 7's darker taskbar glass.
    readonly property color taskbarGlassTint: slate ? '#b80a0d12' : '#ad163456'
    readonly property color taskbarGlassBorderOuter: slate ? '#e6000000' : '#d9000814'
    readonly property color taskbarGlassBorderInner: slate ? '#24ffffff' : '#61ffffff'
    readonly property color taskbarGlassShineTop: slate ? '#14ffffff' : '#2effffff'
    readonly property color taskbarGlassShineMiddle: slate ? '#05ffffff' : '#0dffffff'
    readonly property color taskbarGlassText: slate ? '#e9eef3' : '#ffffff'
    readonly property color taskbarGlassLink: slate ? '#9fd0f7' : '#cfe8ff'
    // The taskbar strip itself: Windows 7's taskbar, lighter and more see-through than the menus over it.
    readonly property color taskbarBarTint: slate ? '#c7161b22' : '#bf96afcd'
    readonly property color taskbarBarEdge: slate ? '#d9000000' : '#cc0c1e34'
    readonly property color taskbarBarShineTop: slate ? '#05ffffff' : '#08ffffff'

    // Gradient stops of a glass button's face: top, 49%, 50%, bottom.
    readonly property var glassButtonFace: slate
        ? ['#1affffff', '#0affffff', '#00ffffff', '#0dffffff']
        : ['#29ffffff', '#0fffffff', '#00ffffff', '#14ffffff']
    readonly property var glassButtonFaceHover: slate
        ? ['#33ffffff', '#1affffff', '#08ffffff', '#1affffff']
        : ['#57ffffff', '#29ffffff', '#0fffffff', '#2effffff']
    readonly property var glassButtonFaceCurrent: slate
        ? ['#47ffffff', '#26ffffff', '#12ffffff', '#29ffffff']
        : ['#7affffff', '#42ffffff', '#24ffffff', '#4dffffff']
    readonly property var glassButtonFaceActive: slate
        ? ['#66000000', '#4d000000', '#42000000', '#24000000']
        : ['#57000a19', '#3d000a19', '#33000a19', '#1a000a19']
    readonly property color glassButtonBorder: slate ? '#d9000000' : '#b3000814'
    readonly property color glassButtonInner: slate ? '#33ffffff' : '#80ffffff'

    // An app's button on the taskbar strip. Faces fading at both ends: top, middle, bottom; an open app's:
    // top, 70%, bottom (eased between), and the gloss over it: at the top-left corner, along its edge.
    readonly property var taskbarItemFaceHover: slate ? ['#00ffffff', '#0fffffff', '#00ffffff'] : ['#00ffffff', '#1fffffff', '#00ffffff']
    readonly property var taskbarItemFacePressed: slate ? ['#08ffffff', '#73000000', '#08ffffff'] : ['#0fffffff', '#52000a19', '#0fffffff']
    readonly property var taskbarItemFaceOpen: slate ? ['#2effffff', '#0dffffff', '#0dffffff'] : ['#6effffff', '#17ffffff', '#17ffffff']
    readonly property var taskbarItemFaceOpenHover: slate ? ['#3dffffff', '#14ffffff', '#14ffffff'] : ['#8cffffff', '#24ffffff', '#24ffffff']
    readonly property var taskbarItemFaceCurrent: slate ? ['#66ffffff', '#2effffff', '#33ffffff'] : ['#ccffffff', '#57ffffff', '#61ffffff']
    readonly property var taskbarItemShine: slate ? ['#17ffffff', '#04ffffff'] : ['#3affffff', '#0affffff']
    readonly property color taskbarItemBorder: slate ? '#cc000000' : '#8c000a19'
    readonly property color taskbarItemInner: slate ? '#29ffffff' : '#73ffffff'
    readonly property color taskbarItemEdge: slate ? '#b3000000' : '#80000a19'
    readonly property color taskbarItemEdgeLight: slate ? '#14ffffff' : '#38ffffff'
    readonly property color taskbarItemSpot: slate ? '#40ffffff' : '#66ffffff'
    readonly property real taskbarItemGlowStrength: slate ? 0.7 : 0.9
    readonly property color taskbarItemGlowNeutral: '#ffffff'
    readonly property real taskbarItemGlowCore: slate ? 0.5 : 0.65
    readonly property int taskbarItemGap: 3

    // The "Show desktop" block at the bar's end. Faces: top, 25%, bottom.
    readonly property var showDesktopFace: slate ? ['#1affffff', '#66000000', '#14000000'] : ['#38ffffff', '#52000a19', '#0a000a19']
    readonly property var showDesktopFaceHover: slate ? ['#33ffffff', '#0affffff', '#14ffffff'] : ['#66ffffff', '#14ffffff', '#24ffffff']
    readonly property var showDesktopFaceActive: slate ? ['#0dffffff', '#80000000', '#4d000000'] : ['#1affffff', '#73000a19', '#33000a19']
    readonly property color showDesktopShine: slate ? '#0fffffff' : '#26ffffff'

    // The user's picture tile: the band's face (top, 50%, 85%, bottom), its shine and how far its sides bow out.
    readonly property var pictureFrameFace: slate ? ['#8d969f', '#bf505a64', '#b33c4650', '#2f8fa8'] : ['#f2f5f8', '#b3c8d2dc', '#a6a0b4c4', '#5cc8e6']
    readonly property color pictureFrameShine: slate ? '#40ffffff' : '#b3ffffff'
    readonly property real pictureFrameBulge: 1.5

    readonly property color surface: slate ? '#23282e' : '#ffffff'
    readonly property color surfaceSunken: slate ? '#1b2025' : '#f2f6fb'
    readonly property color surfaceBorder: slate ? '#0d1013' : '#a9b9cc'
    readonly property color text: slate ? '#e6eaee' : '#1b1f24'
    readonly property color textMuted: slate ? '#a3adb8' : '#55616f'
    readonly property color textLink: slate ? '#7cc0f5' : '#0b5cad'
    readonly property color headingText: slate ? '#8cc4f0' : '#1a4a9c'
    readonly property color dangerText: slate ? '#ff9d95' : '#a3231b'

    readonly property color fieldBackground: slate ? '#171b1f' : '#ffffff'
    readonly property color fieldBorder: slate ? '#07090b' : '#8e9aa8'
    readonly property color fieldBorderTop: slate ? '#000000' : '#6f7b89'
    // field-inner-shadow: an inset shadow along the top edge (colour and depth).
    readonly property color fieldInnerShadow: slate ? '#99000000' : '#1f000000'
    readonly property int fieldInnerShadowSize: slate ? 3 : 2

    // Row faces are top -> bottom gradients.
    readonly property var rowHoverFace: slate ? ['#2c333b', '#272e35'] : ['#fafcff', '#ebf3fd']
    readonly property color rowHoverBorder: slate ? '#3d4954' : '#b8d6fb'
    readonly property var rowSelectedFace: slate ? ['#34526e', '#2a4560'] : ['#dcebfc', '#c1dbfc']
    readonly property color rowSelectedBorder: slate ? '#4d86b8' : '#7da2ce'
    readonly property color rowSeparator: slate ? '#2c3239' : '#e6ecf3'

    // toolbar-face is a top -> bottom gradient; also the face of a list's column headings.
    readonly property var toolbarFace: slate ? ['#343b43', '#2a3037'] : ['#fbfdff', '#e4edf8']
    readonly property color toolbarBorder: slate ? '#14181c' : '#c3d0de'

    readonly property color menuBackground: slate ? '#2a3037' : '#ffffff'
    readonly property color menuBorder: slate ? '#07090b' : '#7c8794'
    // menu-shadow: offset (the same to the right and down), blur and colour; tooltips too.
    readonly property int menuShadowOffset: 2
    readonly property int menuShadowBlur: 5
    readonly property color menuShadowColor: slate ? '#b3000000' : '#59082346'
    readonly property color menuGutterLine: slate ? '#1d2228' : '#e2e3e3'
    readonly property color menuGutterLight: slate ? '#363d45' : '#ffffff'

    // tooltip-face is a top -> bottom gradient.
    readonly property var tooltipFace: slate ? ['#3a424b', '#2a3037'] : ['#ffffff', '#e4e5f0']
    readonly property color tooltipBorder: slate ? '#07090b' : '#767676'
    readonly property color tooltipText: slate ? '#d5dbe1' : '#575757'
    readonly property color overlay: slate ? '#8c000000' : '#590a1e3c'

    // Gradient stops of a control face: top, 49%, 50%, bottom.
    readonly property var controlFace: slate
        ? ['#5a626b', '#474e56', '#363c43', '#2f343a']
        : ['#fdfdfd', '#eeeeee', '#dcdcdc', '#d0d0d0']
    readonly property var controlFaceHover: slate
        ? ['#6b7885', '#55626f', '#3f4c59', '#384552']
        : ['#f2faff', '#dcf1fd', '#b9e3fb', '#a5d9f7']
    readonly property var controlFaceActive: slate
        ? ['#2c3238', '#2a2f35', '#22262b', '#262b30']
        : ['#e2f3fc', '#c2e4f6', '#94cdee', '#6fb8e3']
    readonly property color controlBorder: slate ? '#0b0d10' : '#7c8794'
    readonly property color controlBorderHover: slate ? '#5aa3d8' : '#3c7fb1'
    readonly property color controlInner: slate ? '#29ffffff' : '#d9ffffff'
    readonly property color controlText: slate ? '#eef1f4' : '#1b1f24'
    readonly property color controlFaceDisabled: slate ? '#2a2f35' : '#f4f4f4'
    readonly property color controlBorderDisabled: slate ? '#1b1f23' : '#adb2b5'
    readonly property color controlTextDisabled: slate ? '#6b737c' : '#838383'

    // A check box's sunken square: its face runs from the top-left corner to the bottom-right.
    readonly property color checkBoxBorder: slate ? '#0b0d10' : '#8e8f8f'
    readonly property color checkBoxBorderHover: slate ? '#5aa3d8' : '#5586a3'
    readonly property color checkBoxGap: slate ? '#3a4148' : '#f4f4f4'
    readonly property color checkBoxGapHover: slate ? '#3d5a72' : '#def9fa'
    readonly property color checkBoxRing: slate ? '#4d000000' : '#14000000'
    readonly property color checkBoxRingHover: slate ? '#4f8fbf' : '#89d1f9'
    readonly property color checkBoxRingActive: slate ? '#4d86b8' : '#56a6d6'
    readonly property var checkBoxFace: slate ? ['#1b2025', '#2a3037', '#363c43'] : ['#cdcdcd', '#e8e8e8', '#f5f5f5']
    readonly property var checkBoxFaceHover: slate ? ['#24435c', '#2f5878', '#3b6a8c'] : ['#aecede', '#c4eafd', '#e9f5fb']
    readonly property var checkBoxFaceActive: slate ? ['#173a55', '#22506f', '#2a5d80'] : ['#7ebce3', '#96cbeb', '#9ed0ec']

    // A scrollbar thumb's face runs from left to right: left, 49%, 50%, right.
    readonly property var scrollThumbFace: slate
        ? ['#5a626b', '#474e56', '#363c43', '#2f343a']
        : ['#f5f5f5', '#e9e9eb', '#d9dadc', '#c0c0c4']
    readonly property var scrollThumbFaceHover: slate
        ? ['#6b7885', '#55626f', '#3f4c59', '#384552']
        : ['#f5f5f5', '#d6eefb', '#a9dbf6', '#a9dbf6']
    readonly property var scrollThumbFaceActive: slate
        ? ['#3b6a8c', '#3b6a8c', '#2a5d80', '#2a5d80']
        : ['#b5e4f7', '#b5e4f7', '#6fcaf0', '#6fcaf0']
    readonly property color scrollThumbBorder: slate ? '#0b0d10' : '#979797'
    readonly property color scrollThumbBorderHover: slate ? '#5aa3d8' : '#356f9b'
    readonly property color scrollThumbBorderActive: slate ? '#4d86b8' : '#18598a'
    readonly property color scrollThumbInner: slate ? '#29ffffff' : '#99ffffff'

    readonly property var accentFace: slate
        ? ['#5f9fcf', '#3a7fb5', '#1f629b', '#2a73ad']
        : ['#8fd0f7', '#4fa9e6', '#1f86d4', '#2d9be0']
    readonly property var accentFaceHover: slate
        ? ['#7cb7e2', '#4f95c9', '#2b76b3', '#3b89c6']
        : ['#aee0ff', '#6cbcf2', '#2f97e4', '#49b0f0']
    readonly property var accentFaceActive: slate
        ? ['#2f6893', '#25587f', '#17456b', '#1d517a']
        : ['#5aa6d8', '#2f84c4', '#1568ad', '#1c78bf']
    readonly property color accentBorder: slate ? '#06121d' : '#134e86'
    readonly property color accentText: '#ffffff'

    readonly property var dangerFace: ['#f7a79c', '#e5604f', '#cf3524', '#dc4a38']
    readonly property var dangerFaceHover: ['#ffc0b7', '#f07a6a', '#dd4534', '#ea5e4c']
    readonly property var dangerFaceActive: ['#d0685b', '#b84032', '#9c2417', '#aa3123']
    readonly property color dangerControlBorder: slate ? '#2a0704' : '#7a1810'

    readonly property color iconBlueLight: '#9ad6ff'
    readonly property color iconBlueDark: '#1f7fd6'
    readonly property color iconBlueEdge: '#0f4f94'
    readonly property color iconPaperLight: '#ffffff'
    readonly property color iconPaperDark: '#d3e0ee'
    readonly property color iconPaperEdge: '#5f7590'
    readonly property color iconGoldLight: '#ffee9a'
    readonly property color iconGoldDark: '#f0a81c'
    readonly property color iconGoldEdge: '#a86a00'
    readonly property color iconGreenLight: '#baf083'
    readonly property color iconGreenDark: '#3fa52e'
    readonly property color iconGreenEdge: '#23701a'
    readonly property color iconRedLight: '#ffa695'
    readonly property color iconRedDark: '#d83a2a'
    readonly property color iconRedEdge: '#8f1a10'
    readonly property color iconSteelLight: '#d5dde6'
    readonly property color iconSteelDark: '#7d8b9e'
    readonly property color iconSteelEdge: '#3f4c5e'
    readonly property color iconInk: '#ffffff'
    readonly property color iconInkDark: '#2b2100'
    readonly property color iconGlossTop: '#e6ffffff'
    readonly property color iconGlossBottom: '#14ffffff'
    readonly property color iconShadow: '#59000000'

    readonly property var avatarColors: [
        '#2f8fd8',
        '#3fa56a',
        '#d9822b',
        '#c2507f',
        '#7a62c9',
        '#2aa3a8',
    ]
    // avatar-shine: white 0.45 -> 0.08 at 49% -> 0 at 50%.
    readonly property color avatarShineTop: '#73ffffff'
    readonly property color avatarShineMiddle: '#14ffffff'
    // avatar-glass: a white inner ring and a dark shade along the bottom.
    readonly property color avatarGlassRing: '#66ffffff'
    readonly property color avatarGlassShade: '#47000000'
    readonly property color avatarText: '#ffffff'

    // The start orb (.aero/STYLE.md "Start orb"), the same in both themes.
    readonly property color orbEdge: '#04101c'
    readonly property color orbBodyCenter: '#46c2ff'
    readonly property color orbBodyMiddle: '#16609c'
    readonly property color orbBodyOuter: '#0a1d33'
    readonly property color orbRim: '#66ffffff'
    readonly property color orbShineTop: '#bfffffff'
    readonly property color orbShineBottom: '#0dffffff'
    readonly property color orbHoverTint: '#4778d7ff'
    readonly property color orbPressedTint: '#59001024'
    readonly property color orbGlow: '#d95ac8ff'
    readonly property int orbGlowBlur: 10
    readonly property color orbMarkTop: '#00e5d0'
    readonly property color orbMarkBottom: '#00a8f4'
    readonly property color orbMarkGlow: '#a600e5d0'

    // The notification area's glyphs (.aero/STYLE.md "Notification area glyphs"), pixel drawings, the same
    // in both themes.
    readonly property color trayGlyphInk: '#ffffff'
    readonly property color trayGlyphShade: '#808080'
    readonly property color trayGlyphShadeLight: '#c0c0c0'
    readonly property color trayGlyphEdge: '#80000000'
    readonly property color trayGlyphScreen: '#4d000000'

    // The trackbar of a slider (.aero/STYLE.md "Sliders").
    readonly property color trackbarChannel: slate ? '#1b2025' : '#e7eaea'
    readonly property color trackbarChannelEdge: slate ? '#0b0d10' : '#b0b0b0'
    readonly property color trackbarChannelLight: slate ? '#363c43' : '#fdfdfd'
    readonly property color trackbarRamp: slate ? '#2a3037' : '#d5dfe5'
    readonly property color trackbarTick: slate ? '#4a525b' : '#cfcfcf'
    readonly property color trackbarThumbBorder: '#3c7fb1'
    readonly property color trackbarThumbRimTop: '#41f7fd'
    readonly property color trackbarThumbRimBottom: '#30dafb'
    readonly property color trackbarThumbFaceTop: '#e7f5fd'
    readonly property color trackbarThumbFaceBottom: '#aedef8'
    // The thumb of a slider that does not have the keyboard (the Volume Mixer's other columns).
    readonly property color trackbarThumbQuietBorder: slate ? '#0b0d10' : '#b0b0b0'
    readonly property color trackbarThumbQuietFaceTop: slate ? '#5a626b' : '#f7f7f7'
    readonly property color trackbarThumbQuietFaceBottom: slate ? '#363c43' : '#d5d5d5'

    // The thin frames that group things inside a window (.aero/STYLE.md "Group boxes").
    readonly property color groupBorder: slate ? '#2c3239' : '#eaeff2'

    // The analog clock (.aero/STYLE.md "Analog clock"), the same in both themes.
    readonly property color clockEdge: '#04101c'
    readonly property color clockFaceTop: '#2e6fae'
    readonly property color clockFaceBottom: '#0b2542'
    readonly property color clockRim: '#66ffffff'
    readonly property color clockShineTop: '#8cffffff'
    readonly property color clockShineBottom: '#0dffffff'
    readonly property color clockTick: '#d9ffffff'
    readonly property color clockHand: '#ffffff'
    readonly property color clockSecondHand: '#ff6a55'

    readonly property int motionSoft: 220

    // The Frutiger Aero backdrop (imagery only, behind glass): sky to water to green, a soft light and bokeh.
    readonly property color backdropTop: slate ? '#10161d' : '#2f8fd8'
    readonly property color backdropMiddle: slate ? '#25323f' : '#7fd0f0'
    readonly property color backdropBottom: slate ? '#16303a' : '#3fb68b'
    readonly property color backdropLight: slate ? '#388cbee6' : '#bfffffff'
    readonly property color backdropBokeh: slate ? '#1aa0d2f0' : '#47ffffff'

    readonly property real dragImageOpacity: 0.75
    // focus-glow: a 1px ring, then a soft glow around it (blur, spread), the same in both themes.
    readonly property color focusGlowRing: '#3c9be6'
    readonly property color focusGlowColor: '#bf3c9be6'
    readonly property int focusGlowBlur: 6
    readonly property int focusGlowSpread: 1
}
