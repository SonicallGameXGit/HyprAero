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
    readonly property int fontSizeBody: 13

    readonly property int space1: 4
    readonly property int space2: 8
    readonly property int space3: 12

    readonly property int radiusControl: 3
    readonly property int radiusPanel: 6

    readonly property int motionFast: 120

    readonly property color glassTint: slate ? '#a8262e38' : '#94d6e9fa'
    readonly property color glassBorderOuter: slate ? '#cc000000' : '#8c14325a'
    readonly property color glassBorderInner: slate ? '#33ffffff' : '#bfffffff'
    readonly property color glassShineTop: slate ? '#29ffffff' : '#99ffffff'
    readonly property color glassShineMiddle: slate ? '#08ffffff' : '#1fffffff'
    readonly property color glassText: slate ? '#e9eef3' : '#0d2238'

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
}
