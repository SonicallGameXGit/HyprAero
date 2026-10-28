#include "core/tiling.hpp"

#include <algorithm>
#include <array>
#include <cmath>

namespace frames {

    namespace {

        // Hyprland's own (STICKS in its layout): two edges this close are the same edge
        constexpr double touching = 2;

        // The drop bands of dropSideAt
        constexpr double dropShare = 0.2;
        constexpr double dropReach = 96;

        // A line closer to the pointer than this is under it
        constexpr double closeEnough = 0.5;

        bool finite(const Box& box) {
            return std::isfinite(box.x) && std::isfinite(box.y) && std::isfinite(box.width) && std::isfinite(box.height) && box.width > 0 && box.height > 0;
        }

        double right(const Box& box) {
            return box.x + box.width;
        }

        double bottom(const Box& box) {
            return box.y + box.height;
        }

        // How long two ranges lie along each other
        double overlap(double start, double end, double otherStart, double otherEnd) {
            return std::min(end, otherEnd) - std::max(start, otherStart);
        }

        Box between(double left, double top, double rightEdge, double bottomEdge) {
            return {.x = left, .y = top, .width = rightEdge - left, .height = bottomEdge - top};
        }

        // How far the frame stands in from its room on each side: the tile's share of the gap
        struct Insets {
            double left   = 0;
            double right  = 0;
            double top    = 0;
            double bottom = 0;
        };

        Insets insetsOf(const Tile& tile) {
            return {
                .left   = std::max(tile.frame.x - tile.node.x, 0.0),
                .right  = std::max(right(tile.node) - right(tile.frame), 0.0),
                .top    = std::max(tile.frame.y - tile.node.y, 0.0),
                .bottom = std::max(bottom(tile.node) - bottom(tile.frame), 0.0),
            };
        }

    }

    Edges sharedSides(std::span<const Tile> tiles, std::size_t index) noexcept {
        if (index >= tiles.size() || !finite(tiles[index].node)) {
            return {};
        }

        const Box& node  = tiles[index].node;
        Edges      sides = {};
        for (std::size_t other = 0; other < tiles.size(); other++) {
            const Box& next = tiles[other].node;
            if (other == index || !finite(next)) {
                continue;
            }

            const bool alongY = overlap(node.y, bottom(node), next.y, bottom(next)) > touching;
            const bool alongX = overlap(node.x, right(node), next.x, right(next)) > touching;
            sides.left        = sides.left || (alongY && std::abs(right(next) - node.x) < touching);
            sides.right       = sides.right || (alongY && std::abs(next.x - right(node)) < touching);
            sides.top         = sides.top || (alongX && std::abs(bottom(next) - node.y) < touching);
            sides.bottom      = sides.bottom || (alongX && std::abs(next.y - bottom(node)) < touching);
        }

        return sides;
    }

    Edges commonSides(const Edges& first, const Edges& second) noexcept {
        return {
            .top    = first.top && second.top,
            .bottom = first.bottom && second.bottom,
            .left   = first.left && second.left,
            .right  = first.right && second.right,
        };
    }

    bool anySide(const Edges& edges) noexcept {
        return edges.top || edges.bottom || edges.left || edges.right;
    }

    Split splitAt(std::span<const Tile> tiles, Point point, double border) noexcept {
        Split split = {};
        if (!std::isfinite(point.x) || !std::isfinite(point.y) || !std::isfinite(border) || border < 0) {
            return split;
        }

        for (std::size_t index = 0; index < tiles.size(); index++) {
            const Tile& tile = tiles[index];
            if (!tile.grips || !finite(tile.node) || !finite(tile.frame)) {
                continue;
            }

            const Edges  sides  = sharedSides(tiles, index);
            const Insets insets = insetsOf(tile);
            const Box&   node   = tile.node;
            const Box&   frame  = tile.frame;

            // Along its length a line reaches past the room's end into the gap beyond, where it meets the line across
            const double above  = sides.top ? insets.top + border : 0;
            const double below  = sides.bottom ? insets.bottom + border : 0;
            const double before = sides.left ? insets.left + border : 0;
            const double past   = sides.right ? insets.right + border : 0;

            if (!split.vertical.has_value()) {
                const double top     = node.y - above;
                const double end     = bottom(node) + below;
                const bool   onLeft  = sides.left && contains(between(node.x, top, frame.x + border, end), point.x, point.y);
                const bool   onRight = sides.right && contains(between(right(frame) - border, top, right(node), end), point.x, point.y);
                if (onLeft || onRight) {
                    split.vertical = SplitLine{.tile = index, .after = onRight, .at = onRight ? right(node) : node.x};
                }
            }

            if (!split.horizontal.has_value()) {
                const double left     = node.x - before;
                const double end      = right(node) + past;
                const bool   onTop    = sides.top && contains(between(left, node.y, end, frame.y + border), point.x, point.y);
                const bool   onBottom = sides.bottom && contains(between(left, bottom(frame) - border, end, bottom(node)), point.x, point.y);
                if (onTop || onBottom) {
                    split.horizontal = SplitLine{.tile = index, .after = onBottom, .at = onBottom ? bottom(node) : node.y};
                }
            }
        }

        return split;
    }

    double lineOf(const Box& node, bool vertical, bool after) noexcept {
        if (vertical) {
            return after ? right(node) : node.x;
        }

        return after ? bottom(node) : node.y;
    }

    std::optional<double> lineShift(double line, double pointer, double offset) noexcept {
        const double shift = pointer - offset - line;
        if (!std::isfinite(shift) || std::abs(shift) < closeEnough) {
            return std::nullopt;
        }

        return shift;
    }

    std::string_view splitCursor(const Split& split) noexcept {
        if (split.vertical.has_value() && split.horizontal.has_value()) {
            return "all-scroll";
        }

        if (split.vertical.has_value()) {
            return "ew-resize";
        }

        if (split.horizontal.has_value()) {
            return "ns-resize";
        }

        return "";
    }

    std::optional<Side> dropSideAt(const Box& window, Point pointer, double scale) noexcept {
        if (!finite(window) || !contains(window, pointer.x, pointer.y)) {
            return std::nullopt;
        }

        const double reach  = dropReach * usableScale(scale);
        const double across = std::min(window.width * dropShare, reach);
        const double down   = std::min(window.height * dropShare, reach);

        // The side whose band the pointer is deepest in front of, measured in its own band's depth
        struct Candidate {
            Side   side     = Side::Left;
            double distance = 0;
            double band     = 0;
        };

        const std::array<Candidate, 4> candidates = {{
            {.side = Side::Left, .distance = pointer.x - window.x, .band = across},
            {.side = Side::Right, .distance = right(window) - pointer.x, .band = across},
            {.side = Side::Top, .distance = pointer.y - window.y, .band = down},
            {.side = Side::Bottom, .distance = bottom(window) - pointer.y, .band = down},
        }};

        std::optional<Side> found   = std::nullopt;
        double              nearest = 1;
        for (const Candidate& candidate : candidates) {
            if (candidate.band <= 0 || candidate.distance >= candidate.band) {
                continue;
            }

            const double depth = candidate.distance / candidate.band;
            if (!found.has_value() || depth < nearest) {
                found   = candidate.side;
                nearest = depth;
            }
        }

        return found;
    }

    Box dropArea(const Box& node, Side side) noexcept {
        const double halfWidth  = node.width / 2;
        const double halfHeight = node.height / 2;
        switch (side) {
        case Side::Left:
            return {.x = node.x, .y = node.y, .width = halfWidth, .height = node.height};
        case Side::Right:
            return {.x = node.x + halfWidth, .y = node.y, .width = node.width - halfWidth, .height = node.height};
        case Side::Top:
            return {.x = node.x, .y = node.y, .width = node.width, .height = halfHeight};
        case Side::Bottom:
            break;
        }

        return {.x = node.x, .y = node.y + halfHeight, .width = node.width, .height = node.height - halfHeight};
    }

    std::string_view preselectFor(Side side) noexcept {
        switch (side) {
        case Side::Left:
            return "preselect l";
        case Side::Right:
            return "preselect r";
        case Side::Top:
            return "preselect u";
        case Side::Bottom:
            break;
        }

        return "preselect d";
    }

}
