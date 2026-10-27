#include <limits>

#include "check.hpp"
#include "core/window.hpp"

namespace {

    using frames::DecorationRequest;
    using frames::Placement;
    using frames::Toggle;

    void placements() {
        check::that(frames::placementOf(true, false) == Placement::Floating, "floating");
        check::that(frames::placementOf(false, false) == Placement::InLayout, "tiled");
        check::that(frames::placementOf(true, true) == Placement::Maximized && frames::placementOf(false, true) == Placement::Maximized,
                    "maximized, whether it floats underneath or not");
    }

    void theButtonFollowsTheWindow() {
        check::that(!frames::showsRestore(Placement::Floating), "a floating window shows Maximize");
        check::that(frames::showsRestore(Placement::InLayout) && frames::showsRestore(Placement::Maximized), "in the layout or maximized: Restore");

        check::that(frames::toggleFor(Placement::Floating) == Toggle::Tile, "Maximize puts it into the layout");
        check::that(frames::toggleFor(Placement::InLayout) == Toggle::Float, "Restore takes it out");
        check::that(frames::toggleFor(Placement::Maximized) == Toggle::Unmaximize, "Restore ends Hyprland's maximize");
    }

    void corners() {
        check::that(frames::rounded(Placement::Floating), "a floating window is rounded");
        check::that(!frames::rounded(Placement::InLayout) && !frames::rounded(Placement::Maximized), "in the layout it is square");
    }

    void fixedWindows() {
        const frames::Size small = {.width = 400, .height = 300};
        const frames::Size large = {.width = 1e300, .height = 1e300};
        check::that(frames::fixedSize(small, small), "the same smallest and largest size");
        check::that(frames::fixedSize(small, frames::Size{.width = 400.2, .height = 299.8}), "a fraction apart is the same");
        check::that(!frames::fixedSize(small, large), "a window that can grow");
        check::that(!frames::fixedSize(std::nullopt, small) && !frames::fixedSize(small, std::nullopt), "no limits given");

        constexpr double notANumber = std::numeric_limits<double>::quiet_NaN();
        check::that(!frames::fixedSize(frames::Size{.width = notANumber, .height = 300}, small), "a size that is not a number");
        check::that(!frames::fixedSize(frames::Size{.width = 0, .height = 0}, frames::Size{.width = 0, .height = 0}), "sizes of 0");

        check::that(!frames::canToggle(Placement::Floating, true), "a fixed floating window cannot go into the layout");
        check::that(frames::canToggle(Placement::InLayout, true), "but one that is there can leave it");
        check::that(frames::canToggle(Placement::Floating, false), "any other can");

        check::that(!frames::resizable(Placement::Floating, true), "a fixed window is not resized");
        check::that(!frames::resizable(Placement::Maximized, false), "nor a maximized one");
        check::that(frames::resizable(Placement::InLayout, false) && frames::resizable(Placement::Floating, false), "the others are");
    }

    void titleBars() {
        check::that(frames::decorationRequestFrom(false, 2) == DecorationRequest::Never, "an app that never asked");
        check::that(frames::decorationRequestFrom(true, 0) == DecorationRequest::NoPreference, "asked, then took it back");
        check::that(frames::decorationRequestFrom(true, 1) == DecorationRequest::ClientSide, "its own title bar (Chromium, Electron)");
        check::that(frames::decorationRequestFrom(true, 2) == DecorationRequest::ServerSide, "the compositor's");
        check::that(frames::decorationRequestFrom(true, 7) == DecorationRequest::NoPreference, "a mode the protocol does not have");

        check::that(frames::wantsServerFrame(DecorationRequest::ServerSide) && frames::wantsServerFrame(DecorationRequest::NoPreference),
                    "the frame for apps that want it or leave it to us");
        check::that(!frames::wantsServerFrame(DecorationRequest::ClientSide) && !frames::wantsServerFrame(DecorationRequest::Never),
                    "none for apps that draw their own");
    }

}

int main() {
    placements();
    theButtonFollowsTheWindow();
    corners();
    fixedWindows();
    titleBars();
    return check::result("window");
}
