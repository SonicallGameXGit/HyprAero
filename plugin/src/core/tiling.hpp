#pragma once

#include <cstddef>
#include <cstdint>
#include <optional>
#include <span>
#include <string_view>

#include "core/layout.hpp"

// Windows in Hyprland's layout, for the frames: which sides of a tiled window resize it (only those it shares with
// another window), the lines between windows a press holds, and where a window dropped on a tiled one goes. The host
// reads the layout's boxes; these decide. Every box is on the screen, in logical pixels.
namespace frames {

    // A window in the layout: the room the layout gives it (`node`; the rooms meet edge to edge) and what it shows in
    // that room, its frame included (`frame`, apart from its neighbours' by the gaps)
    struct Tile {
        Box node  = {};
        Box frame = {};
        // Whether its sides hold the lines beside it: not a pseudotiled window, which is smaller than its room
        bool grips = true;
    };

    // The sides along which another tile's room meets this one's: only those move in the layout. The others lie on the
    // edge of the workspace, where nothing can move them.
    Edges sharedSides(std::span<const Tile> tiles, std::size_t index) noexcept;

    // Only the sides in both
    Edges commonSides(const Edges& first, const Edges& second) noexcept;

    bool anySide(const Edges& edges) noexcept;

    // A line between windows held by a press near it: the tile on whose side it was found, which side, and where it is
    struct SplitLine {
        std::size_t tile = 0;
        // The tile's right side (a vertical line) or bottom side (a horizontal one); else its left or top side
        bool   after = false;
        double at    = 0;
    };

    // The lines under a point: a vertical one (between columns), a horizontal one (between rows), or both where they meet
    struct Split {
        std::optional<SplitLine> vertical   = std::nullopt;
        std::optional<SplitLine> horizontal = std::nullopt;
    };

    // A line can be held from `border` inside one window's frame, across the gap, to `border` inside the other's, so
    // the pointer finds the same line wherever it crosses it. Where two lines meet, both are held.
    Split splitAt(std::span<const Tile> tiles, Point point, double border) noexcept;

    // Where a line is now: that side of the tile's room
    double lineOf(const Box& node, bool vertical, bool after) noexcept;

    // How far to move a line so it is under the pointer again, keeping the distance the pointer held it at.
    // Nothing when it is there already (less than half a pixel away) or a value is not a number.
    std::optional<double> lineShift(double line, double pointer, double offset) noexcept;

    // Both arrows of one line, or all four where two meet; empty for none
    std::string_view splitCursor(const Split& split) noexcept;

    enum class Side : std::uint8_t {
        Left,
        Right,
        Top,
        Bottom,
    };

    // Dropped near one side of a tiled window (inside a band a fifth of its size deep, at most 96 pixels), a moved
    // window goes beside it there. Farther in, it stays floating over it. `window` is the tiled one with its frame.
    // In a corner, inside two bands, a side on the layout's outer edge comes before one it shares with another window
    // (`shared`, from sharedSides): let go at the bottom of the screen, a window goes below the one there, not beside
    // it. Between two of the same kind, the side it is deeper toward.
    std::optional<Side> dropSideAt(const Box& window, Point pointer, double scale, const Edges& shared) noexcept;

    // The tile whose room is nearest to a point, as dwindle finds the window to put a new one beside when the point is
    // over none and on a screen's reserved area (CDwindleAlgorithm::getClosestNode); none without tiles
    std::optional<std::size_t> nearestTile(std::span<const Tile> tiles, Point point) noexcept;

    // A place to drop a moved window on is shown, and taken, only once the pointer stayed on it for a while (0.6s):
    // moved past windows in the layout, or let go near one, a window stays floating. `sinceMs` is when the pointer
    // came onto it. A time that is not a number ends the wait, rather than keeping it forever.
    bool dropReady(double sinceMs, double nowMs) noexcept;

    // What the dropped window takes of the tiled one's room: the half on that side, as Hyprland's dwindle splits it
    Box dropArea(const Box& node, Side side) noexcept;

    // The layout message that tells dwindle which side the next window goes to
    std::string_view preselectFor(Side side) noexcept;

    // And the one that takes it back, should the window not have gone into the layout ("none": any word but a side)
    constexpr std::string_view preselectNone = "preselect none";

}
