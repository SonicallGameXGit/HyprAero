#include <array>
#include <limits>

#include "check.hpp"
#include "core/tiling.hpp"

namespace {

    using frames::Box;
    using frames::Tile;

    constexpr double border = 8;

    // A tile as Hyprland's layout makes it: the frame stands 6 pixels in from its room on every side (gaps_in)
    Tile tile(double x, double y, double width, double height, bool grips = true) {
        constexpr double gap = 6;
        return {
            .node  = {.x = x, .y = y, .width = width, .height = height},
            .frame = {.x = x + gap, .y = y + gap, .width = width - gap * 2, .height = height - gap * 2},
            .grips = grips,
        };
    }

    bool sides(const frames::Edges& edges, bool top, bool bottom, bool left, bool right) {
        return edges.top == top && edges.bottom == bottom && edges.left == left && edges.right == right;
    }

    void sharedSides() {
        const std::array<Tile, 1> alone = {tile(0, 0, 1000, 600)};
        check::that(sides(frames::sharedSides(alone, 0), false, false, false, false), "the only window resizes nowhere");

        // A | (B / C)
        const std::array<Tile, 3> three = {tile(0, 0, 500, 600), tile(500, 0, 500, 300), tile(500, 300, 500, 300)};
        check::that(sides(frames::sharedSides(three, 0), false, false, false, true), "the left window only by its right side");
        check::that(sides(frames::sharedSides(three, 1), false, true, true, false), "the top right one by its left and bottom");
        check::that(sides(frames::sharedSides(three, 2), true, false, true, false), "the bottom right one by its left and top");
        check::that(sides(frames::sharedSides(three, 3), false, false, false, false), "a tile that is not there has no sides");

        // Touching at a corner only is not sharing a side
        const std::array<Tile, 2> corner = {tile(0, 0, 500, 300), tile(500, 300, 500, 300)};
        check::that(sides(frames::sharedSides(corner, 0), false, false, false, false), "a corner is not a side");

        constexpr double          notANumber = std::numeric_limits<double>::quiet_NaN();
        const std::array<Tile, 2> broken     = {tile(0, 0, 500, 600), tile(notANumber, 0, 500, 600)};
        check::that(sides(frames::sharedSides(broken, 0), false, false, false, false), "a room that is not a number is no neighbour");

        check::that(sides(frames::commonSides(frames::allSides, {.bottom = true, .left = true}), false, true, true, false), "common sides");
        check::that(!frames::anySide({}), "no side");
    }

    void splitters() {
        const std::array<Tile, 1> alone = {tile(0, 0, 1000, 600)};
        const frames::Split       none  = frames::splitAt(alone, {.x = 3, .y = 300}, border);
        check::that(!none.vertical.has_value() && !none.horizontal.has_value(), "no line around the only window");

        const std::array<Tile, 2> pair = {tile(0, 0, 500, 600), tile(500, 0, 500, 600)};
        const frames::Split       gap  = frames::splitAt(pair, {.x = 500, .y = 300}, border);
        check::that(gap.vertical.has_value() && !gap.horizontal.has_value(), "the gap between two windows is their line");
        check::that(gap.vertical.has_value() && gap.vertical->at == 500, "which is where their rooms meet");

        const frames::Split leftFrame = frames::splitAt(pair, {.x = 487, .y = 300}, border);
        check::that(leftFrame.vertical.has_value() && leftFrame.vertical->tile == 0 && leftFrame.vertical->after, "inside the left frame's edge");
        const frames::Split rightFrame = frames::splitAt(pair, {.x = 513, .y = 300}, border);
        check::that(rightFrame.vertical.has_value() && rightFrame.vertical->tile == 1 && !rightFrame.vertical->after, "inside the right one's");
        check::that(!frames::splitAt(pair, {.x = 485, .y = 300}, border).vertical.has_value(), "farther in is the window");
        check::that(!frames::splitAt(pair, {.x = 3, .y = 300}, border).vertical.has_value(), "the workspace's edge is no line");
        check::that(frames::splitAt(pair, {.x = 500, .y = 0}, border).vertical.has_value(), "the line runs the whole height");

        // A | (B / C): where the lines meet, both are held, from either side of the gap
        const std::array<Tile, 3> three  = {tile(0, 0, 500, 600), tile(500, 0, 500, 300), tile(500, 300, 500, 300)};
        const frames::Split       middle = frames::splitAt(three, {.x = 500, .y = 300}, border);
        check::that(middle.vertical.has_value() && middle.horizontal.has_value(), "both lines where they meet");
        check::that(middle.horizontal.has_value() && middle.horizontal->at == 300, "the horizontal one is between B and C");
        const frames::Split leftOfGap = frames::splitAt(three, {.x = 490, .y = 300}, border);
        check::that(leftOfGap.vertical.has_value() && leftOfGap.horizontal.has_value(), "and from the left half of the gap too");
        const frames::Split along = frames::splitAt(three, {.x = 490, .y = 100}, border);
        check::that(along.vertical.has_value() && !along.horizontal.has_value(), "away from the meeting, only the vertical line");
        const frames::Split across = frames::splitAt(three, {.x = 700, .y = 300}, border);
        check::that(!across.vertical.has_value() && across.horizontal.has_value(), "and only the horizontal one");
        const frames::Split inside = frames::splitAt(three, {.x = 300, .y = 300}, border);
        check::that(!inside.vertical.has_value() && !inside.horizontal.has_value(), "the left window's middle is no line");

        // A pseudotiled window does not hold its line, its neighbour still does
        const std::array<Tile, 2> pseudo = {tile(0, 0, 500, 600), tile(500, 0, 500, 600, false)};
        check::that(!frames::splitAt(pseudo, {.x = 505, .y = 300}, border).vertical.has_value(), "not by the pseudotiled window");
        check::that(frames::splitAt(pseudo, {.x = 495, .y = 300}, border).vertical.has_value(), "but by its neighbour");

        constexpr double notANumber = std::numeric_limits<double>::quiet_NaN();
        check::that(!frames::splitAt(pair, {.x = notANumber, .y = 300}, border).vertical.has_value(), "a pointer that is not a number");
    }

    void lines() {
        const Box node = {.x = 100, .y = 50, .width = 400, .height = 300};
        check::that(frames::lineOf(node, true, true) == 500, "right side");
        check::that(frames::lineOf(node, true, false) == 100, "left side");
        check::that(frames::lineOf(node, false, true) == 350, "bottom side");
        check::that(frames::lineOf(node, false, false) == 50, "top side");

        const auto shift = frames::lineShift(500, 530, 4);
        check::that(shift.has_value() && *shift == 26, "the line follows the pointer, kept where it was held");
        check::that(!frames::lineShift(500, 504.2, 4).has_value(), "it is under the pointer already");
        constexpr double notANumber = std::numeric_limits<double>::quiet_NaN();
        check::that(!frames::lineShift(500, notANumber, 4).has_value(), "a pointer that is not a number moves nothing");

        const frames::SplitLine line = {};
        check::that(frames::splitCursor({.vertical = line}) == "ew-resize", "a vertical line's cursor");
        check::that(frames::splitCursor({.horizontal = line}) == "ns-resize", "a horizontal line's cursor");
        check::that(frames::splitCursor({.vertical = line, .horizontal = line}) == "all-scroll", "where two meet");
        check::that(frames::splitCursor({}).empty(), "none");
    }

    void drops() {
        using frames::Side;
        const Box window = {.x = 0, .y = 0, .width = 1000, .height = 500};
        check::that(frames::dropSideAt(window, {.x = 50, .y = 250}, 1) == Side::Left, "near the left side");
        check::that(frames::dropSideAt(window, {.x = 950, .y = 250}, 1) == Side::Right, "near the right side");
        check::that(frames::dropSideAt(window, {.x = 500, .y = 20}, 1) == Side::Top, "near the top");
        check::that(frames::dropSideAt(window, {.x = 500, .y = 480}, 1) == Side::Bottom, "near the bottom");
        check::that(!frames::dropSideAt(window, {.x = 500, .y = 250}, 1).has_value(), "the middle stays floating");
        check::that(!frames::dropSideAt(window, {.x = 100, .y = 250}, 1).has_value(), "96 pixels at most, however large the window");
        check::that(frames::dropSideAt(window, {.x = 5, .y = 20}, 1) == Side::Left, "in a corner, the side it is deeper toward");
        check::that(!frames::dropSideAt(window, {.x = -1, .y = 250}, 1).has_value(), "outside the window");

        const Box small = {.x = 0, .y = 0, .width = 200, .height = 100};
        check::that(frames::dropSideAt(small, {.x = 30, .y = 50}, 1) == Side::Left, "a fifth of a small window");
        check::that(!frames::dropSideAt(small, {.x = 45, .y = 50}, 1).has_value(), "and no more");

        const Box wide = {.x = 0, .y = 0, .width = 2000, .height = 1000};
        check::that(frames::dropSideAt(wide, {.x = 150, .y = 500}, 2) == Side::Left, "farther at twice the size");

        const auto same = [](const Box& box, double x, double y, double width, double height) {
            return box.x == x && box.y == y && box.width == width && box.height == height;
        };
        const Box node = {.x = 100, .y = 0, .width = 800, .height = 600};
        check::that(same(frames::dropArea(node, Side::Left), 100, 0, 400, 600), "the left half");
        check::that(same(frames::dropArea(node, Side::Right), 500, 0, 400, 600), "the right half");
        check::that(same(frames::dropArea(node, Side::Top), 100, 0, 800, 300), "the top half");
        check::that(same(frames::dropArea(node, Side::Bottom), 100, 300, 800, 300), "the bottom half");

        check::that(frames::preselectFor(Side::Left) == "preselect l", "dwindle's left");
        check::that(frames::preselectFor(Side::Top) == "preselect u", "dwindle's up");
    }

}

int main() {
    sharedSides();
    splitters();
    lines();
    drops();
    return check::result("tiling");
}
