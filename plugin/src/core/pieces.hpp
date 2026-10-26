#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <string_view>

// The pictures the frames are drawn with: Windows 7's own, cut by tools/cut-pictures.py into resources/
// (resources/README.md). Their sizes are what the layout counts with; the plugin checks each decoded picture
// against them and leaves out one that does not match rather than draw it wrong.
namespace frames {

    enum class Piece : std::uint8_t {
        FaceMaximizeRest,
        FaceMaximizeHover,
        FaceMaximizePressed,
        FaceMaximizeInactive,
        FaceCloseRest,
        FaceCloseHover,
        FaceClosePressed,
        FaceCloseInactive,
        GlyphClose,
        GlyphCloseInactive,
        GlyphMaximize,
        GlyphMaximizeInactive,
        GlyphRestore,
        GlyphRestoreInactive,
        GlowMaximize,
        GlowClose,
        GlowTitle,
        Reflection,
        Application16,
        Application32,
    };

    constexpr std::size_t pieceCount = 20;

    // How far a picture's corners and edges reach in from each side: those keep their size when the picture is
    // stretched, only the middle grows (nineSlice)
    struct Margins {
        int left   = 0;
        int top    = 0;
        int right  = 0;
        int bottom = 0;
    };

    struct PieceInfo {
        std::string_view file    = "";
        int              width   = 0;
        int              height  = 0;
        Margins          margins = {};
    };

    // In the order of Piece. The glows' margins were measured on Windows 7's atlas: where each glow's fading edge ends.
    constexpr std::array<PieceInfo, pieceCount> pieces = {{
        {.file = "face-maximize-rest.png", .width = 29, .height = 20},
        {.file = "face-maximize-hover.png", .width = 29, .height = 20},
        {.file = "face-maximize-pressed.png", .width = 29, .height = 20},
        {.file = "face-maximize-inactive.png", .width = 29, .height = 20},
        {.file = "face-close-rest.png", .width = 49, .height = 20},
        {.file = "face-close-hover.png", .width = 49, .height = 20},
        {.file = "face-close-pressed.png", .width = 49, .height = 20},
        {.file = "face-close-inactive.png", .width = 49, .height = 20},
        {.file = "glyph-close.png", .width = 11, .height = 10},
        {.file = "glyph-close-inactive.png", .width = 11, .height = 10},
        {.file = "glyph-maximize.png", .width = 12, .height = 10},
        {.file = "glyph-maximize-inactive.png", .width = 12, .height = 10},
        {.file = "glyph-restore.png", .width = 12, .height = 12},
        {.file = "glyph-restore-inactive.png", .width = 12, .height = 12},
        {.file = "glow-maximize.png", .width = 49, .height = 38, .margins = {.left = 11, .top = 9, .right = 10, .bottom = 8}},
        {.file = "glow-close.png", .width = 66, .height = 40, .margins = {.left = 11, .top = 9, .right = 10, .bottom = 10}},
        {.file = "glow-title.png", .width = 47, .height = 33, .margins = {.left = 23, .top = 0, .right = 23, .bottom = 0}},
        {.file = "reflection.png", .width = 802, .height = 604},
        {.file = "application-16.png", .width = 16, .height = 16},
        {.file = "application-32.png", .width = 32, .height = 32},
    }};

    constexpr const PieceInfo& pieceInfo(Piece piece) noexcept {
        return pieces.at(static_cast<std::size_t>(piece));
    }

    // How far the title's glow reaches past the words on each side, measured on Windows 7 screenshots
    constexpr int titleGlowReach = 13;

}
