#pragma once

#include <array>
#include <cstdint>
#include <optional>
#include <string_view>

#include "core/pieces.hpp"
#include "core/tokens.hpp"

// Where each part of a frame goes (design/.aero/STYLE.md "Window frames"). Everything is in logical pixels,
// relative to the frame's outer top-left corner; the window itself sits in `client`. Every measure of the design is
// multiplied by the frames' scale (QT_SCALE_FACTOR, scaleFromText), as Qt apps grow by it.
namespace frames {

    struct Box {
        double x      = 0;
        double y      = 0;
        double width  = 0;
        double height = 0;
    };

    struct Point {
        double x = 0;
        double y = 0;
    };

    bool contains(const Box& box, double x, double y) noexcept;

    // The scales the frames take; past them a value is a mistake, not a choice, and counts as 1
    constexpr double smallestScale = 0.5;
    constexpr double largestScale  = 4;

    double usableScale(double scale) noexcept;

    // QT_SCALE_FACTOR's text as a scale; nothing when it is not a plain number in the range above
    std::optional<double> scaleFromText(std::string_view text) noexcept;

    // How far the frame reaches out of the window, in whole logical pixels so the window stays on whole pixels
    struct Extents {
        double border  = 0;
        double caption = 0;
    };

    Extents frameExtents(const Tokens& tokens, double scale) noexcept;

    enum class Part : std::uint8_t {
        Outside,
        Client,
        // Resizes the window, or does nothing for a window that cannot be resized
        Edge,
        Caption,
        Maximize,
        Close,
    };

    struct FrameLayout {
        Box     outer   = {};
        Box     client  = {};
        Extents extents = {};
        double  scale   = 1;
        // The glass around the window, in four strips that never reach under it
        std::array<Box, 4> strips = {};

        // What a narrow window has no room for is left out, from the right: first the buttons, then the title and the icon
        bool showButtons = false;
        bool showIcon    = false;
        bool showTitle   = false;

        Box maximize = {};
        Box close    = {};
        Box icon     = {};
        // The words start at its left and are cut with an ellipsis at its right; they are centred in its height, the caption's
        Box title = {};
    };

    // Nothing for a frame too small to have its own edges (a size of 0, negative, not a number or huge)
    std::optional<FrameLayout> layoutFrame(double outerWidth, double outerHeight, const Tokens& tokens, double scale) noexcept;

    // Sides of a window: those a press resizes, or those that can resize at all
    struct Edges {
        bool top    = false;
        bool bottom = false;
        bool left   = false;
        bool right  = false;
    };

    constexpr Edges allSides = {.top = true, .bottom = true, .left = true, .right = true};

    // `sides` are the ones that resize the window: all of a floating one, none of one that cannot be resized, those
    // it shares with a neighbour in the layout (core/tiling.hpp). The caption's top band and its sides are edges only
    // where their side resizes; else they move the window.
    Part partAt(const FrameLayout& layout, double x, double y, const Edges& sides) noexcept;

    // The sides of the window a press on a point of its edge resizes. Near a corner it is both sides of that corner.
    Edges edgesAt(const FrameLayout& layout, double x, double y) noexcept;

    // The frame around what the app drew. Hyprland keeps a window's room when its app draws less (a fixed size, a size
    // it refused) and places the drawing in it; the frame follows the drawing so it never stands away from the app.
    // `window` is the room, `surface` the drawing, both on the screen. A drawing that does not fit in the room (or
    // makes no sense) leaves `outer` as it is.
    Box fitToSurface(const Box& outer, const Box& window, const Box& surface) noexcept;

    // Where Windows puts a glyph on a button: centred, the odd pixel to the right, and above the face's bottom light
    // line. `pixel` is one pixel of the pictures, the frames' scale.
    Box glyphBox(const Box& face, double glyphWidth, double glyphHeight, double pixel) noexcept;

    // The glow around a button under the pointer
    Box buttonGlowBox(const Box& face, const Margins& margins, double scale) noexcept;

    // One piece of a stretched picture: which part of the picture goes to which part of the target
    struct Slice {
        Box source = {};
        Box target = {};
    };

    // A picture drawn into a box of another size: the corners keep their size (times `scale`), the edges stretch
    // along, the middle both ways. Margins that do not fit the target shrink together. Slices with nothing to draw
    // are left empty.
    std::array<Slice, 9> nineSlice(double sourceWidth, double sourceHeight, const Margins& margins, const Box& target, double scale) noexcept;

}
