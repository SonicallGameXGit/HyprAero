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
        const auto layout = frames::layoutFrame(400, 300, tokens);
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
        check::that(same(layout->icon, 10, 11, 16, 16), "the icon is centred in the caption's band");
        check::that(same(layout->title, 31, 8, 280, 22), "the title starts after the icon and stops before the buttons");
        check::that(layout->showButtons && layout->showIcon && layout->showTitle, "everything has room");
    }

    void narrowWindowsLoseButtonsThenTitle() {
        const auto noButtons = frames::layoutFrame(90, 100, tokens);
        check::that(noButtons.has_value() && !noButtons->showButtons && noButtons->showTitle, "no room for the buttons: they go first");

        const auto noTitle = frames::layoutFrame(30, 100, tokens);
        check::that(noTitle.has_value() && !noTitle->showButtons && !noTitle->showTitle, "then the title");

        const auto noIcon = frames::layoutFrame(20, 100, tokens);
        check::that(noIcon.has_value() && !noIcon->showIcon, "then the icon");
    }

    void badSizesGiveNoFrame() {
        constexpr double notANumber = std::numeric_limits<double>::quiet_NaN();
        constexpr double infinite   = std::numeric_limits<double>::infinity();
        check::that(!frames::layoutFrame(0, 0, tokens).has_value(), "a size of 0");
        check::that(!frames::layoutFrame(-400, 300, tokens).has_value(), "a negative width");
        check::that(!frames::layoutFrame(400, -1, tokens).has_value(), "a negative height");
        check::that(!frames::layoutFrame(notANumber, 300, tokens).has_value(), "not a number");
        check::that(!frames::layoutFrame(400, infinite, tokens).has_value(), "infinite");
        check::that(!frames::layoutFrame(1e12, 300, tokens).has_value(), "huge");
        check::that(!frames::layoutFrame(16, 300, tokens).has_value(), "no room for the window between the sides");
        check::that(!frames::layoutFrame(400, 38, tokens).has_value(), "no room for the window between caption and bottom");

        frames::Tokens broken = tokens;
        broken.frameBorder    = -3;
        check::that(!frames::layoutFrame(400, 300, broken).has_value(), "tokens that make no sense draw nothing");
    }

    void partsUnderThePointer() {
        const auto layout = frames::layoutFrame(400, 300, tokens);
        if (!layout.has_value()) {
            check::that(false, "a normal window has a frame");
            return;
        }

        check::that(frames::partAt(*layout, -1, 10) == frames::Part::Outside, "left of the frame");
        check::that(frames::partAt(*layout, 400, 10) == frames::Part::Outside, "the right edge is outside");
        check::that(frames::partAt(*layout, 100, 100) == frames::Part::Client, "the window");
        check::that(frames::partAt(*layout, 100, 10) == frames::Part::Caption, "the caption");
        check::that(frames::partAt(*layout, 3, 100) == frames::Part::Edge, "a side");
        check::that(frames::partAt(*layout, 100, 295) == frames::Part::Edge, "the bottom");
        check::that(frames::partAt(*layout, 330, 10) == frames::Part::Maximize, "Maximize");
        check::that(frames::partAt(*layout, 370, 10) == frames::Part::Close, "Close");
        check::that(frames::partAt(*layout, 370, 0) == frames::Part::Close, "above Close, at the very top, is still Close");
        check::that(frames::partAt(*layout, 370, 22) == frames::Part::Caption, "below Close is the caption");
        check::that(frames::partAt(*layout, 397, 10) == frames::Part::Caption, "right of Close is the caption");
    }

    void glyphsAsWindowsCentresThem() {
        const frames::Box close = {.x = 345, .y = 1, .width = 49, .height = 20};
        check::that(same(frames::glyphBox(close, 11, 10), 364, 5, 11, 10), "Close's cross");
        const frames::Box maximize = {.x = 316, .y = 1, .width = 29, .height = 20};
        check::that(same(frames::glyphBox(maximize, 12, 10), 325, 5, 12, 10), "Maximize's box, the odd pixel to the right");
        check::that(same(frames::glyphBox(maximize, 12, 12), 325, 4, 12, 12), "Restore's boxes");
    }

    void glows() {
        const auto layout = frames::layoutFrame(400, 300, tokens);
        if (!layout.has_value()) {
            check::that(false, "a normal window has a frame");
            return;
        }

        check::that(same(frames::titleGlowBox(*layout, 100), 18, 2, 126, 33), "the title's glow reaches past the words");
        const frames::Margins margins = {.left = 11, .top = 9, .right = 10, .bottom = 8};
        check::that(same(frames::buttonGlowBox(layout->maximize, margins), 305, -8, 50, 37), "a button's glow surrounds it");
    }

    void slices() {
        const frames::Margins margins = {.left = 11, .top = 9, .right = 10, .bottom = 8};
        const auto            nine    = frames::nineSlice(49, 38, margins, {.x = 100, .y = 50, .width = 70, .height = 40});
        check::that(same(nine[0].source, 0, 0, 11, 9) && same(nine[0].target, 100, 50, 11, 9), "the top-left corner keeps its size");
        check::that(same(nine[4].source, 11, 9, 28, 21) && same(nine[4].target, 111, 59, 49, 23), "the middle stretches both ways");
        check::that(same(nine[8].source, 39, 30, 10, 8) && same(nine[8].target, 160, 82, 10, 8), "the bottom-right corner keeps its size");

        const frames::Margins sides = {.left = 23, .top = 0, .right = 23, .bottom = 0};
        const auto            three = frames::nineSlice(47, 33, sides, {.x = 0, .y = 0, .width = 23, .height = 33});
        check::that(same(three[3].target, 0, 0, 11.5, 33) && same(three[5].target, 11.5, 0, 11.5, 33), "sides that do not fit shrink together");
        check::that(three[4].target.width == 0 && three[0].target.width == 0, "what has nothing to draw stays empty");

        const auto none = frames::nineSlice(49, 38, margins, {.x = 0, .y = 0, .width = -5, .height = 10});
        check::that(none[4].target.width == 0, "a negative target draws nothing");
    }

}

int main() {
    aWindowAsOnWindows7();
    narrowWindowsLoseButtonsThenTitle();
    badSizesGiveNoFrame();
    partsUnderThePointer();
    glyphsAsWindowsCentresThem();
    glows();
    slices();
    return check::result("layout");
}
