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

    readonly property int motionFast: 120

    readonly property color glassTint: slate ? '#a8262e38' : '#94d6e9fa'
    readonly property color glassBorderOuter: slate ? '#cc000000' : '#8c14325a'
    readonly property color glassBorderInner: slate ? '#33ffffff' : '#bfffffff'
    readonly property color glassShineTop: slate ? '#29ffffff' : '#99ffffff'
    readonly property color glassShineMiddle: slate ? '#08ffffff' : '#1fffffff'
    readonly property color glassText: slate ? '#e9eef3' : '#0d2238'

    readonly property color surface: slate ? '#23282e' : '#ffffff'
    readonly property color surfaceSunken: slate ? '#1b2025' : '#f2f6fb'
    readonly property color surfaceBorder: slate ? '#0d1013' : '#a9b9cc'
    readonly property color text: slate ? '#e6eaee' : '#1b1f24'
    readonly property color textMuted: slate ? '#a3adb8' : '#55616f'
    readonly property color headingText: slate ? '#8cc4f0' : '#1a4a9c'

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

    readonly property color menuBackground: slate ? '#2a3037' : '#ffffff'
    readonly property color menuBorder: slate ? '#07090b' : '#7c8794'
    // menu-shadow: offset down, blur and colour.
    readonly property int menuShadowOffset: 6
    readonly property int menuShadowBlur: 18
    readonly property color menuShadowColor: slate ? '#b3000000' : '#59082346'
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
    readonly property color iconRedLight: '#ffa695'
    readonly property color iconRedDark: '#d83a2a'
    readonly property color iconRedEdge: '#8f1a10'
    readonly property color iconSteelLight: '#d5dde6'
    readonly property color iconSteelDark: '#7d8b9e'
    readonly property color iconSteelEdge: '#3f4c5e'
    readonly property color iconInk: '#ffffff'
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

    readonly property int motionSoft: 220

    readonly property real dragImageOpacity: 0.75
    // focus-glow: a 1px ring, then a soft glow around it (blur, spread), the same in both themes.
    readonly property color focusGlowRing: '#3c9be6'
    readonly property color focusGlowColor: '#bf3c9be6'
    readonly property int focusGlowBlur: 6
    readonly property int focusGlowSpread: 1
}
