#include <limits>

#include "check.hpp"
#include "core/moving.hpp"

namespace {

    using frames::Placement;

    void thresholds() {
        check::that(frames::dragThreshold(Placement::Floating, 1) == 4, "a floating window moves after 4 pixels, as on Windows");
        check::that(frames::dragThreshold(Placement::InLayout, 1) == 32, "one in the layout only after 32");
        check::that(frames::dragThreshold(Placement::Maximized, 1) == 32, "a maximized one too");
        check::that(frames::dragThreshold(Placement::InLayout, 2) == 64, "farther at twice the size");

        check::that(!frames::pastThreshold({.x = 0, .y = 0}, {.x = 3, .y = 0}, 4), "3 pixels is a click");
        check::that(!frames::pastThreshold({.x = 0, .y = 0}, {.x = 4, .y = 0}, 4), "4 is still a click");
        check::that(frames::pastThreshold({.x = 0, .y = 0}, {.x = 3, .y = 3}, 4), "4.2 across a diagonal moves");
        check::that(frames::pastThreshold({.x = 100, .y = 100}, {.x = 100, .y = 60}, 32), "upwards too");

        constexpr double notANumber = std::numeric_limits<double>::quiet_NaN();
        check::that(!frames::pastThreshold({.x = 0, .y = 0}, {.x = notANumber, .y = 0}, 4), "a pointer that is not a number does not move anything");
    }

    void leavingTheLayout() {
        const frames::Extents extents = {.border = 8, .caption = 30};
        const frames::Box     tiled   = {.x = 0, .y = 0, .width = 1000, .height = 600};

        const frames::Point middle = frames::placeUnderPointer(tiled, {.x = 500, .y = 15}, {.x = 600, .y = 60}, {.width = 800, .height = 500}, extents);
        check::that(middle.x == 200 && middle.y == 75, "held in the middle of the caption, the window comes out centred under the pointer");

        const frames::Point left = frames::placeUnderPointer(tiled, {.x = 100, .y = 15}, {.x = 100, .y = 15}, {.width = 384, .height = 300}, extents);
        check::that(left.x == 68 && left.y == 30, "held near the left, it stays near the left under the pointer");

        const frames::Point low = frames::placeUnderPointer(tiled, {.x = 500, .y = 50}, {.x = 600, .y = 60}, {.width = 800, .height = 500}, extents);
        check::that(low.y == 60, "the pointer stays in the caption");

        const frames::Point none = frames::placeUnderPointer({}, {.x = 0, .y = 0}, {.x = 500, .y = 100}, {.width = 384, .height = 300}, extents);
        check::that(none.x == 308 && none.y == 130, "a frame of no width puts the pointer in the middle");
    }

    void theTopOfTheScreen() {
        const frames::Box screen = {.x = 0, .y = 0, .width = 1920, .height = 1080};
        check::that(frames::atSnapEdge({.x = 500, .y = 0}, screen, 1), "at the top edge");
        check::that(frames::atSnapEdge({.x = 500, .y = 7}, screen, 1), "just below it");
        check::that(!frames::atSnapEdge({.x = 500, .y = 8}, screen, 1), "8 pixels down is not");
        check::that(frames::atSnapEdge({.x = 500, .y = 15}, screen, 2), "farther at twice the size");
        check::that(!frames::atSnapEdge({.x = -5, .y = 0}, screen, 1), "off the screen");

        const frames::Box second = {.x = 1920, .y = 0, .width = 2560, .height = 1440};
        check::that(frames::atSnapEdge({.x = 2000, .y = 3}, second, 1), "the top of a second screen");
    }

    void cursors() {
        check::that(frames::resizeCursor({.top = true, .left = true}) == "nw-resize", "top-left");
        check::that(frames::resizeCursor({.bottom = true, .right = true}) == "se-resize", "bottom-right");
        check::that(frames::resizeCursor({.left = true}) == "w-resize", "left");
        check::that(frames::resizeCursor({.top = true}) == "n-resize", "top");
        check::that(frames::resizeCursor({}).empty(), "no side, no cursor");
    }

}

int main() {
    thresholds();
    leavingTheLayout();
    theTopOfTheScreen();
    cursors();
    return check::result("moving");
}
