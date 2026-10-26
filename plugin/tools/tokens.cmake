# Writes generated/tokens.hpp from design/Theme.qml: the tokens the frames use, for both themes, so the plugin never
# types a design value again (AGENTS.md section 4.2). Run by the build whenever Theme.qml changes:
#   cmake -DTHEME=<Theme.qml> -DOUTPUT=<tokens.hpp> -P tokens.cmake
# A token that is missing or not in the form below stops the build: drawing with a guessed value would be worse.
# Each token is one line of Theme.qml: `readonly property <int|real|color> <name>: <value>` or
# `... <name>: slate ? <slate value> : <aero value>`.

set(frameTokens
    frameBorder int
    frameCaption int
    frameRadius int
    frameButtonsTop int
    frameButtonsRight int
    frameIconLeft int
    frameIconSize int
    frameTitleGap int
    frameGlassTint color
    frameGlassTintInactive color
    frameEdgeOuter color
    frameEdgeOuterInactive color
    frameEdgeInner color
    frameEdgeInnerInactive color
    frameClientEdgeLight color
    frameClientEdgeDark color
    frameTitleText color
    frameTitleGlow real
    fontSizeSmall int
)

file(READ "${THEME}" theme)

# One value of Theme.qml as C++
function(cppValue type value result)
    string(STRIP "${value}" value)
    if(type STREQUAL "color")
        string(REGEX REPLACE "^'(.*)'$" "\\1" value "${value}")
        if(value MATCHES "^#([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])$")
            set(value "#ff${CMAKE_MATCH_1}")
        endif()
        if(NOT value MATCHES "^#([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])$")
            message(FATAL_ERROR "${THEME}: '${value}' is not a colour")
        endif()
        set(${result} "hexColor(0x${CMAKE_MATCH_1}U)" PARENT_SCOPE)
    elseif(type STREQUAL "int")
        if(NOT value MATCHES "^-?[0-9]+$")
            message(FATAL_ERROR "${THEME}: '${value}' is not a whole number")
        endif()
        set(${result} "${value}" PARENT_SCOPE)
    else()
        if(value MATCHES "^-?[0-9]+$")
            set(${result} "${value}.0F" PARENT_SCOPE)
        elseif(value MATCHES "^-?[0-9]+\\.[0-9]+$")
            set(${result} "${value}F" PARENT_SCOPE)
        else()
            message(FATAL_ERROR "${THEME}: '${value}' is not a number")
        endif()
    endif()
endfunction()

set(aeroLines "")
set(slateLines "")
list(LENGTH frameTokens count)
math(EXPR last "${count} - 1")
foreach(index RANGE 0 ${last} 2)
    math(EXPR typeIndex "${index} + 1")
    list(GET frameTokens ${index} name)
    list(GET frameTokens ${typeIndex} type)

    if(NOT theme MATCHES "readonly property ${type} ${name}: ([^\n]*)")
        message(FATAL_ERROR "${THEME}: no `readonly property ${type} ${name}` (design/.aero/STYLE.md \"Window frames\")")
    endif()
    set(line "${CMAKE_MATCH_1}")

    if(line MATCHES "^slate \\? (.*) : (.*)$")
        set(slateText "${CMAKE_MATCH_1}")
        set(aeroText "${CMAKE_MATCH_2}")
    else()
        set(slateText "${line}")
        set(aeroText "${line}")
    endif()

    cppValue(${type} "${aeroText}" aeroValue)
    cppValue(${type} "${slateText}" slateValue)
    string(APPEND aeroLines "        .${name} = ${aeroValue},\n")
    string(APPEND slateLines "        .${name} = ${slateValue},\n")
endforeach()

# font-ui: the list of candidates, the same in both themes
if(NOT theme MATCHES "readonly property var fontCandidates: \\[([^]]*)\\]")
    message(FATAL_ERROR "${THEME}: no `readonly property var fontCandidates: [...]`")
endif()
string(REGEX MATCHALL "'[^']*'" candidates "${CMAKE_MATCH_1}")
list(TRANSFORM candidates REPLACE "'" "")
list(JOIN candidates ", " fontUi)
if(fontUi STREQUAL "" OR fontUi MATCHES "[\"\\\\]")
    message(FATAL_ERROR "${THEME}: fontCandidates is empty or has a quote or a backslash")
endif()
string(APPEND aeroLines "        .fontUi = \"${fontUi}\",\n")
string(APPEND slateLines "        .fontUi = \"${fontUi}\",\n")

set(header "#pragma once

// Generated from design/Theme.qml by plugin/tools/tokens.cmake. Do not edit: change the design.

#include \"core/tokens.hpp\"

namespace frames::generated {

    constexpr Tokens aero = {
${aeroLines}    };

    constexpr Tokens slate = {
${slateLines}    };

}
")

# Written only when it changed, so a build does not recompile everything after each run
if(EXISTS "${OUTPUT}")
    file(READ "${OUTPUT}" previous)
    if(previous STREQUAL header)
        return()
    endif()
endif()
file(WRITE "${OUTPUT}" "${header}")
