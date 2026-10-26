#pragma once

#include <array>
#include <cstdint>
#include <optional>

#include "core/pieces.hpp"
#include "core/tokens.hpp"

// Where each part of a frame goes (design/.aero/STYLE.md "Window frames"). Everything is in logical pixels,
// relative to the frame's outer top-left corner; the window itself sits in `client`.
namespace frames {

    struct Box {
        double x      = 0;
        double y      = 0;
        double width  = 0;
        double height = 0;
    };

    bool contains(const Box& box, double x, double y) noexcept;

    enum class Part : std::uint8_t {
        Outside,
        Client,
        Edge,
        Caption,
        Maximize,
        Close,
    };

    struct FrameLayout {
        Box outer  = {};
        Box client = {};
        // The glass around the window, in four strips that never reach under it
        std::array<Box, 4> strips = {};

        // What a narrow window has no room for is left out, from the right: first the buttons, then the title and the icon
        bool showButtons = false;
        bool showIcon    = false;
        bool showTitle   = false;

        Box maximize = {};
        Box close    = {};
        Box icon     = {};
        // The words start at its left and are cut with an ellipsis at its right; its middle is the caption's
        Box title = {};
    };

    // Nothing for a frame too small to have its own edges (a size of 0, negative, not a number or huge)
    std::optional<FrameLayout> layoutFrame(double outerWidth, double outerHeight, const Tokens& tokens) noexcept;

    Part partAt(const FrameLayout& layout, double x, double y) noexcept;

    // Where Windows puts a glyph on a button: centred, the odd pixel to the right, and above the face's bottom light line
    Box glyphBox(const Box& face, double glyphWidth, double glyphHeight) noexcept;

    // The title's glow behind words of this width
    Box titleGlowBox(const FrameLayout& layout, double textWidth) noexcept;

    // The glow around a button under the pointer
    Box buttonGlowBox(const Box& face, const Margins& margins) noexcept;

    // One piece of a stretched picture: which part of the picture goes to which part of the target
    struct Slice {
        Box source = {};
        Box target = {};
    };

    // A picture drawn into a box of another size: the corners keep their size, the edges stretch along, the middle
    // both ways. Margins that do not fit the target shrink together. Slices with nothing to draw are left empty.
    std::array<Slice, 9> nineSlice(double sourceWidth, double sourceHeight, const Margins& margins, const Box& target) noexcept;

}
