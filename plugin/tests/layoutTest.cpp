#include <limits>

#include "check.hpp"
#include "core/layout.hpp"
#include "generated/tokens.hpp"

namespace {

    constexpr frames::Tokens tokens = frames::generated::aero;

    bool same(const frames::Box& box, double x, double y, double width, double height) {
        return box.x == x && box.y == y && box.width == width && box.height == height;
    }

    void aWindowAsOnWindows7() {
        // A frame 400 x 300 around its window, measured against the Windows 7 screenshot
        const auto layout = frames::layoutFrame(400, 300, tokens, 1);
        check::that(layout.has_value(), "a normal window has a frame");
        if (!layout.has_value()) {
            return;
        }

        check::that(same(layout->client, 8, 30, 384, 262), "the window sits 8 in from the sides and the bottom, 30 from the top");
        check::that(same(layout->strips[0], 0, 0, 400, 30), "the top strip is the caption");
        check::that(same(layout->strips[1], 0, 30, 8, 262), "the left strip");
        check::that(same(layout->strips[2], 392, 30, 8, 262), "the right strip");
        check::that(same(layout->strips[3], 0, 292, 400, 8), "the bottom strip");
        check::that(same(layout->close, 345, 1, 49, 20), "Close ends 6 in from the right, 1 below the top");
        check::that(same(layout->maximize, 316, 1, 29, 20), "Maximize sits just left of Close");
        check::that(same(layout->icon, 10, 7, 16, 16), "the icon is in the middle of the caption's height");
        check::that(same(layout->title, 31, 0, 280, 30), "the title starts after the icon, stops before the buttons, and is centred in the caption");
        check::that(layout->showButtons && layout->showIcon && layout->showTitle, "everything has room");
    }

    void scaledAsQtApps() {
        // QT_SCALE_FACTOR=1.25: every measure grows by a quarter; the room around the window stays whole pixels
        const auto layout = frames::layoutFrame(500, 400, tokens, 1.25);
        check::that(layout.has_value(), "a scaled window has a frame");
        if (!layout.has_value()) {
            return;
        }

        check::that(layout->extents.border == 10 && layout->extents.caption == 38, "8 and 30 become 10 and 37.5, rounded to 38");
        check::that(same(layout->client, 10, 38, 480, 352), "the window sits in the scaled room");
        check::that(same(layout->close, 431.25, 1.25, 61.25, 25), "Close grows with its distance from the right");
        check::that(same(layout->maximize, 395, 1.25, 36.25, 25), "Maximize too");
        check::that(same(layout->icon, 12.5, 9, 20, 20), "the icon is 20 pixels, in the middle of the caption");
        check::that(same(layout->title, 38.75, 0, 350, 38), "the title follows");

        const auto doubled = frames::layoutFrame(500, 400, tokens, 2);
        check::that(doubled.has_value() && doubled->extents.border == 16 && doubled->extents.caption == 60, "twice the size");
    }

    void scales() {
        check::that(frames::scaleFromText("1.25") == 1.25, "QT_SCALE_FACTOR=1.25");
        check::that(frames::scaleFromText("2") == 2.0, "a whole number");
        check::that(!frames::scaleFromText("").has_value(), "empty");
        check::that(!frames::scaleFromText("abc").has_value(), "not a number");
        check::that(!frames::scaleFromText("1.25x").has_value(), "a number and more");
        check::that(!frames::scaleFromText(" 1.25").has_value(), "a space before");
        check::that(!frames::scaleFromText("1e2").has_value(), "an exponent");
        check::that(!frames::scaleFromText("-1").has_value(), "negative");
        check::that(!frames::scaleFromText("0.1").has_value(), "too small to read");
        check::that(!frames::scaleFromText("10").has_value(), "larger than any screen wants");
        check::that(!frames::scaleFromText("nan").has_value() && !frames::scaleFromText("inf").has_value(), "not finite");

        constexpr double notANumber = std::numeric_limits<double>::quiet_NaN();
        check::that(frames::usableScale(notANumber) == 1 && frames::usableScale(100) == 1 && frames::usableScale(1.5) == 1.5, "an unusable scale counts as 1");
        const frames::Extents extents = frames::frameExtents(tokens, notANumber);
        check::that(extents.border == 8 && extents.caption == 30, "and gives the design's own sizes");
    }

    void narrowWindowsLoseButtonsThenTitle() {
        const auto noButtons = frames::layoutFrame(90, 100, tokens, 1);
        check::that(noButtons.has_value() && !noButtons->showButtons && noButtons->showTitle, "no room for the buttons: they go first");

        const auto noTitle = frames::layoutFrame(30, 100, tokens, 1);
        check::that(noTitle.has_value() && !noTitle->showButtons && !noTitle->showTitle, "then the title");

        const auto noIcon = frames::layoutFrame(20, 100, tokens, 1);
        check::that(noIcon.has_value() && !noIcon->showIcon, "then the icon");
    }

    void badSizesGiveNoFrame() {
        constexpr double notANumber = std::numeric_limits<double>::quiet_NaN();
        constexpr double infinite   = std::numeric_limits<double>::infinity();
        check::that(!frames::layoutFrame(0, 0, tokens, 1).has_value(), "a size of 0");
        check::that(!frames::layoutFrame(-400, 300, tokens, 1).has_value(), "a negative width");
        check::that(!frames::layoutFrame(400, -1, tokens, 1).has_value(), "a negative height");
        check::that(!frames::layoutFrame(notANumber, 300, tokens, 1).has_value(), "not a number");
        check::that(!frames::layoutFrame(400, infinite, tokens, 1).has_value(), "infinite");
        check::that(!frames::layoutFrame(1e12, 300, tokens, 1).has_value(), "huge");
        check::that(!frames::layoutFrame(16, 300, tokens, 1).has_value(), "no room for the window between the sides");
        check::that(!frames::layoutFrame(400, 38, tokens, 1).has_value(), "no room for the window between caption and bottom");
        check::that(frames::layoutFrame(400, 300, tokens, notANumber).has_value(), "a scale that is not a number counts as 1");

        frames::Tokens broken = tokens;
        broken.frameBorder    = -3;
        check::that(!frames::layoutFrame(400, 300, broken, 1).has_value(), "tokens that make no sense draw nothing");
    }

    void partsUnderThePointer() {
        const auto layout = frames::layoutFrame(400, 300, tokens, 1);
        if (!layout.has_value()) {
            check::that(false, "a normal window has a frame");
            return;
        }

        using frames::Part;
        check::that(frames::partAt(*layout, -1, 10, true) == Part::Outside, "left of the frame");
        check::that(frames::partAt(*layout, 400, 10, true) == Part::Outside, "the right edge is outside");
        check::that(frames::partAt(*layout, 100, 100, true) == Part::Client, "the window");
        check::that(frames::partAt(*layout, 100, 10, true) == Part::Caption, "the caption");
        check::that(frames::partAt(*layout, 3, 100, true) == Part::Edge, "a side");
        check::that(frames::partAt(*layout, 100, 295, true) == Part::Edge, "the bottom");
        check::that(frames::partAt(*layout, 100, 3, true) == Part::Edge, "the caption's top band resizes");
        check::that(frames::partAt(*layout, 3, 20, true) == Part::Edge, "and so do its sides");
        check::that(frames::partAt(*layout, 397, 10, true) == Part::Edge, "right of Close is the right side");
        check::that(frames::partAt(*layout, 330, 10, true) == Part::Maximize, "Maximize");
        check::that(frames::partAt(*layout, 370, 10, true) == Part::Close, "Close");
        check::that(frames::partAt(*layout, 370, 0, true) == Part::Close, "above Close, at the very top, is still Close");
        check::that(frames::partAt(*layout, 370, 22, true) == Part::Caption, "below Close is the caption");

        check::that(frames::partAt(*layout, 100, 3, false) == Part::Caption, "a window that cannot be resized moves by all of its caption");
        check::that(frames::partAt(*layout, 3, 20, false) == Part::Caption, "its sides too");
        check::that(frames::partAt(*layout, 3, 100, false) == Part::Edge, "below the caption its edge stays an edge, that does nothing");
    }

    bool sides(const frames::Edges& edges, bool top, bool bottom, bool left, bool right) {
        return edges.top == top && edges.bottom == bottom && edges.left == left && edges.right == right;
    }

    void edgesAsOnWindows() {
        const auto layout = frames::layoutFrame(400, 300, tokens, 1);
        if (!layout.has_value()) {
            check::that(false, "a normal window has a frame");
            return;
        }

        check::that(sides(frames::edgesAt(*layout, 3, 100), false, false, true, false), "the left side resizes only the width");
        check::that(sides(frames::edgesAt(*layout, 100, 3), true, false, false, false), "the top only the height");
        check::that(sides(frames::edgesAt(*layout, 100, 295), false, true, false, false), "the bottom");
        check::that(sides(frames::edgesAt(*layout, 397, 100), false, false, false, true), "the right side");
        check::that(sides(frames::edgesAt(*layout, 3, 3), true, false, true, false), "the top-left corner");
        check::that(sides(frames::edgesAt(*layout, 12, 3), true, false, true, false), "a corner reaches along the top");
        check::that(sides(frames::edgesAt(*layout, 3, 12), true, false, true, false), "and down the side");
        check::that(sides(frames::edgesAt(*layout, 397, 295), false, true, false, true), "the bottom-right corner");
        check::that(sides(frames::edgesAt(*layout, 3, 290), false, true, true, false), "the bottom-left corner");

        const auto tiny = frames::layoutFrame(20, 100, tokens, 1);
        if (!tiny.has_value()) {
            check::that(false, "a tiny window has a frame");
            return;
        }

        check::that(sides(frames::edgesAt(*tiny, 10, 3), true, false, true, false), "both sides in reach: the left one");
    }

    void theFrameFollowsTheDrawing() {
        const frames::Box outer  = {.x = 92, .y = 70, .width = 400, .height = 300};
        const frames::Box window = {.x = 100, .y = 100, .width = 384, .height = 262};

        check::that(same(frames::fitToSurface(outer, window, window), 92, 70, 400, 300), "an app that fills its room");
        check::that(same(frames::fitToSurface(outer, window, {.x = 100, .y = 100, .width = 300, .height = 200}), 92, 70, 316, 238),
                    "an app smaller than its room, at its top-left");
        check::that(same(frames::fitToSurface(outer, window, {.x = 142, .y = 131, .width = 300, .height = 200}), 134, 101, 316, 238),
                    "an app Hyprland centred in its room");
        check::that(same(frames::fitToSurface(outer, window, {.x = 100, .y = 100, .width = 500, .height = 200}), 92, 70, 400, 300),
                    "an app larger than its room: the room");
        check::that(same(frames::fitToSurface(outer, window, {.x = 100, .y = 100, .width = 0, .height = 200}), 92, 70, 400, 300), "an empty drawing");

        constexpr double notANumber = std::numeric_limits<double>::quiet_NaN();
        check::that(same(frames::fitToSurface(outer, window, {.x = notANumber, .y = 100, .width = 300, .height = 200}), 92, 70, 400, 300),
                    "a drawing that is not a number");
    }

    void glyphsAsWindowsCentresThem() {
        const frames::Box close = {.x = 345, .y = 1, .width = 49, .height = 20};
        check::that(same(frames::glyphBox(close, 11, 10, 1), 364, 5, 11, 10), "Close's cross");
        const frames::Box maximize = {.x = 316, .y = 1, .width = 29, .height = 20};
        check::that(same(frames::glyphBox(maximize, 12, 10, 1), 325, 5, 12, 10), "Maximize's box, the odd pixel to the right");
        check::that(same(frames::glyphBox(maximize, 12, 12, 1), 325, 4, 12, 12), "Restore's boxes");

        const frames::Box doubled = {.x = 0, .y = 0, .width = 58, .height = 40};
        check::that(same(frames::glyphBox(doubled, 22, 20, 2), 18, 8, 22, 20), "at twice the size, twice as far in");
    }

    void glows() {
        const frames::Margins margins = {.left = 11, .top = 9, .right = 10, .bottom = 8};
        check::that(same(frames::buttonGlowBox({.x = 316, .y = 1, .width = 29, .height = 20}, margins, 1), 305, -8, 50, 37), "a button's glow surrounds it");
        check::that(same(frames::buttonGlowBox({.x = 0, .y = 0, .width = 58, .height = 40}, margins, 2), -22, -18, 100, 74), "scaled, it reaches farther");
    }

    void slices() {
        const frames::Margins margins = {.left = 11, .top = 9, .right = 10, .bottom = 8};
        const auto            nine    = frames::nineSlice(49, 38, margins, {.x = 100, .y = 50, .width = 70, .height = 40}, 1);
        check::that(same(nine[0].source, 0, 0, 11, 9) && same(nine[0].target, 100, 50, 11, 9), "the top-left corner keeps its size");
        check::that(same(nine[4].source, 11, 9, 28, 21) && same(nine[4].target, 111, 59, 49, 23), "the middle stretches both ways");
        check::that(same(nine[8].source, 39, 30, 10, 8) && same(nine[8].target, 160, 82, 10, 8), "the bottom-right corner keeps its size");

        const auto scaled = frames::nineSlice(49, 38, margins, {.x = 0, .y = 0, .width = 140, .height = 80}, 2);
        check::that(same(scaled[0].source, 0, 0, 11, 9) && same(scaled[0].target, 0, 0, 22, 18), "scaled, a corner is twice its size");
        check::that(same(scaled[4].target, 22, 18, 98, 46), "and the middle takes the rest");

        const frames::Margins sides = {.left = 23, .top = 0, .right = 23, .bottom = 0};
        const auto            three = frames::nineSlice(47, 33, sides, {.x = 0, .y = 0, .width = 23, .height = 33}, 1);
        check::that(same(three[3].target, 0, 0, 11.5, 33) && same(three[5].target, 11.5, 0, 11.5, 33), "sides that do not fit shrink together");
        check::that(three[4].target.width == 0 && three[0].target.width == 0, "what has nothing to draw stays empty");

        const auto none = frames::nineSlice(49, 38, margins, {.x = 0, .y = 0, .width = -5, .height = 10}, 1);
        check::that(none[4].target.width == 0, "a negative target draws nothing");
    }

}

int main() {
    aWindowAsOnWindows7();
    scaledAsQtApps();
    scales();
    narrowWindowsLoseButtonsThenTitle();
    badSizesGiveNoFrame();
    partsUnderThePointer();
    edgesAsOnWindows();
    theFrameFollowsTheDrawing();
    glyphsAsWindowsCentresThem();
    glows();
    slices();
    return check::result("layout");
}
