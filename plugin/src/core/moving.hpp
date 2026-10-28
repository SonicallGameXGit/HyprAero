#pragma once

#include <cstdint>
#include <string_view>

#include "core/layout.hpp"
#include "core/window.hpp"

// Moving a window by its caption, as on Windows 7: a press becomes a move only once the pointer went far enough, a
// window in the layout comes out of it under the pointer, and let go at the top of the screen it goes back in.
namespace frames {

    // How far the pointer must go before a press on the caption moves the window: a few pixels for a floating window,
    // as on Windows; much farther for one in the layout, so a slip of the hand does not take it out
    double dragThreshold(Placement placement, double scale) noexcept;

    bool pastThreshold(Point start, Point now, double threshold) noexcept;

    // Where the window's top-left corner goes when it leaves the layout at `pointer`: across the caption the pointer
    // keeps its place in proportion, down it keeps its distance from the top, as on Windows. `outer` is the frame
    // when the caption was grabbed at `grab`, `client` the window's size out of the layout.
    Point placeUnderPointer(const Box& outer, Point grab, Point pointer, Size client, const Extents& extents) noexcept;

    // Whether the pointer is at the top of its screen, where letting go puts the window back into the layout
    bool atSnapEdge(Point pointer, const Box& screen, double scale) noexcept;

    // The cursor (its name in the cursor theme) over an edge that resizes these sides; empty for none
    std::string_view resizeCursor(const Edges& edges) noexcept;

    // A press on the caption: when (the pointer event's time, which wraps) and where
    struct Click {
        std::uint32_t timeMs = 0;
        Point         point  = {};
    };

    // Whether the second press makes a double click with the first, as Windows counts one: within half a second and
    // a 4 pixel square around the first (GetDoubleClickTime, SM_CXDOUBLECLK)
    bool doubleClick(const Click& first, const Click& second, double scale) noexcept;

}
