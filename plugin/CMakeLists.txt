cmake_minimum_required(VERSION 3.27)

project(hypraero-frames VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 26)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# .aero/CODE_STYLE.md section 5; Hyprland's headers come in as system headers, so their warnings are not ours
set(framesWarnings -Wall -Wextra -Wpedantic -Wconversion -Wshadow -Werror)

set(coreSources
    src/core/safety.cpp
    src/core/status.cpp
)

# The plugin. It is never built with sanitizers: they do not work in a library loaded into a program built without them.
find_package(PkgConfig REQUIRED)
pkg_check_modules(hyprland REQUIRED IMPORTED_TARGET hyprland)

add_library(hypraero-frames SHARED src/main.cpp ${coreSources})
target_include_directories(hypraero-frames PRIVATE src)
target_compile_options(hypraero-frames PRIVATE ${framesWarnings})
target_compile_definitions(hypraero-frames PRIVATE FRAMES_VERSION="${PROJECT_VERSION}")
target_link_libraries(hypraero-frames PRIVATE PkgConfig::hyprland)
set_target_properties(hypraero-frames PROPERTIES PREFIX "")

# The tests: core only (no Hyprland), with AddressSanitizer and UndefinedBehaviorSanitizer
enable_testing()

set(framesSanitizers -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)

foreach(testName safetyTest statusTest)
    add_executable(${testName} tests/${testName}.cpp ${coreSources})
    target_include_directories(${testName} PRIVATE src)
    target_compile_options(${testName} PRIVATE ${framesWarnings} ${framesSanitizers})
    target_link_options(${testName} PRIVATE ${framesSanitizers})
    add_test(NAME ${testName} COMMAND ${testName})
endforeach()
