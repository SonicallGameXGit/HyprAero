cmake_minimum_required(VERSION 3.27)

project(hypraero-frames VERSION 0.2.0 LANGUAGES CXX)

# Hyprland is built with GCC and its plugin interface passes C++ objects: a plugin from another compiler may not
# match it and could take the session down (AGENTS.md section 3)
if(NOT CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    message(FATAL_ERROR "build the plugin with GCC, as Hyprland is: cmake -S plugin -B build -G Ninja -DCMAKE_CXX_COMPILER=g++ --fresh")
endif()

set(CMAKE_CXX_STANDARD 26)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# .aero/CODE_STYLE.md section 5; Hyprland's headers come in as system headers, so their warnings are not ours
set(framesWarnings -Wall -Wextra -Wpedantic -Wconversion -Wshadow -Werror)

# The tokens, read from the design at build time (tools/tokens.cmake), and again whenever Theme.qml changes
set(themeFile ${CMAKE_CURRENT_SOURCE_DIR}/../design/Theme.qml)
set(generatedFolder ${CMAKE_CURRENT_BINARY_DIR}/generated)
set(tokensHeader ${generatedFolder}/generated/tokens.hpp)
add_custom_command(
    OUTPUT ${tokensHeader}
    COMMAND ${CMAKE_COMMAND} -DTHEME=${themeFile} -DOUTPUT=${tokensHeader} -P ${CMAKE_CURRENT_SOURCE_DIR}/tools/tokens.cmake
    DEPENDS ${themeFile} ${CMAKE_CURRENT_SOURCE_DIR}/tools/tokens.cmake
    COMMENT "Reading the tokens from design/Theme.qml"
)
add_custom_target(frames-tokens DEPENDS ${tokensHeader})

set(coreSources
    src/core/buttons.cpp
    src/core/command.cpp
    src/core/icons.cpp
    src/core/layout.cpp
    src/core/safety.cpp
    src/core/status.cpp
    src/core/text.cpp
)

# The plugin. It is never built with sanitizers: they do not work in a library loaded into a program built without them.
find_package(PkgConfig REQUIRED)
pkg_check_modules(hyprland REQUIRED IMPORTED_TARGET hyprland)
pkg_check_modules(cairo REQUIRED IMPORTED_TARGET cairo)

set(hostSources
    src/host/frame.cpp
    src/host/frames.cpp
    src/host/pictures.cpp
    src/host/state.cpp
)

# Windows 7's pictures are built into the plugin (#embed), so it reads no file while Hyprland runs
set(pictureFolders ${CMAKE_CURRENT_SOURCE_DIR}/../resources/frame ${CMAKE_CURRENT_SOURCE_DIR}/../resources/icons)
file(GLOB pictureFiles CONFIGURE_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/../resources/frame/*.png ${CMAKE_CURRENT_SOURCE_DIR}/../resources/icons/*.png)

add_library(hypraero-frames SHARED src/main.cpp ${hostSources} ${coreSources})
add_dependencies(hypraero-frames frames-tokens)
target_include_directories(hypraero-frames PRIVATE src ${generatedFolder})
target_compile_options(hypraero-frames PRIVATE ${framesWarnings} --embed-dir=${CMAKE_CURRENT_SOURCE_DIR}/../resources)
target_compile_definitions(hypraero-frames PRIVATE FRAMES_VERSION="${PROJECT_VERSION}")
target_link_libraries(hypraero-frames PRIVATE PkgConfig::hyprland PkgConfig::cairo)
# Never unmapped once loaded: Hyprland deletes the decoration of a hidden window only when it is shown again, which
# can be after the plugin was unloaded; its code must still be there then (AGENTS.md section 5.1, DECISIONS.md)
target_link_options(hypraero-frames PRIVATE -Wl,-z,nodelete)
set_target_properties(hypraero-frames PROPERTIES PREFIX "")
set_source_files_properties(src/host/pictures.cpp PROPERTIES OBJECT_DEPENDS "${pictureFiles}")

# The tests: core only (no Hyprland), with AddressSanitizer and UndefinedBehaviorSanitizer
enable_testing()

set(framesSanitizers -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)

foreach(testName buttonsTest commandTest iconsTest layoutTest safetyTest statusTest textTest)
    add_executable(${testName} tests/${testName}.cpp ${coreSources})
    add_dependencies(${testName} frames-tokens)
    target_include_directories(${testName} PRIVATE src ${generatedFolder})
    target_compile_options(${testName} PRIVATE ${framesWarnings} ${framesSanitizers})
    target_link_options(${testName} PRIVATE ${framesSanitizers})
    add_test(NAME ${testName} COMMAND ${testName})
endforeach()
