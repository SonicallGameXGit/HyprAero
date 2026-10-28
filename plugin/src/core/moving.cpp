#include "core/moving.hpp"

#include <algorithm>
#include <cmath>

namespace frames {

    namespace {

        // Windows' own (SM_CXDRAG) for a floating window; the owner asked for a wide margin in the layout
        constexpr double floatingThreshold = 4;
        constexpr double layoutThreshold   = 32;

        // How far down from the screen's top edge the pointer counts as at it
        constexpr double snapReach = 8;

        // Windows' own: GetDoubleClickTime's default, and half of SM_CXDOUBLECLK each way
        constexpr std::uint32_t doubleClickTime  = 500;
        constexpr double        doubleClickReach = 2;

    }

    double dragThreshold(Placement placement, double scale) noexcept {
        const double base = placement == Placement::Floating ? floatingThreshold : layoutThreshold;
        return base * usableScale(scale);
    }

    bool pastThreshold(Point start, Point now, double threshold) noexcept {
        const double across = now.x - start.x;
        const double down   = now.y - start.y;
        if (!std::isfinite(across) || !std::isfinite(down)) {
            return false;
        }

        return across * across + down * down > threshold * threshold;
    }

    Point placeUnderPointer(const Box& outer, Point grab, Point pointer, Size client, const Extents& extents) noexcept {
        const double proportion = outer.width > 0 && std::isfinite(outer.width) ? std::clamp((grab.x - outer.x) / outer.width, 0.0, 1.0) : 0.5;
        const double down       = std::isfinite(grab.y - outer.y) ? std::clamp(grab.y - outer.y, 0.0, extents.caption) : 0;
        const double width      = client.width + extents.border * 2;

        return {
            .x = std::round(pointer.x - proportion * width + extents.border),
            .y = std::round(pointer.y - down + extents.caption),
        };
    }

    bool atSnapEdge(Point pointer, const Box& screen, double scale) noexcept {
        const double reach = snapReach * usableScale(scale);
        return contains(screen, pointer.x, pointer.y) && pointer.y < screen.y + reach;
    }

    std::string_view resizeCursor(const Edges& edges) noexcept {
        if (edges.top && edges.left) {
            return "nw-resize";
        }

        if (edges.top && edges.right) {
            return "ne-resize";
        }

        if (edges.bottom && edges.left) {
            return "sw-resize";
        }

        if (edges.bottom && edges.right) {
            return "se-resize";
        }

        if (edges.top) {
            return "n-resize";
        }

        if (edges.bottom) {
            return "s-resize";
        }

        if (edges.left) {
            return "w-resize";
        }

        if (edges.right) {
            return "e-resize";
        }

        return "";
    }

    bool doubleClick(const Click& first, const Click& second, double scale) noexcept {
        // Unsigned, so a time that wrapped around between the two still counts the few milliseconds between them
        const std::uint32_t elapsed = second.timeMs - first.timeMs;
        const double        reach   = doubleClickReach * usableScale(scale);
        const double        across  = std::abs(second.point.x - first.point.x);
        const double        down    = std::abs(second.point.y - first.point.y);
        return elapsed <= doubleClickTime && across <= reach && down <= reach;
    }

}
