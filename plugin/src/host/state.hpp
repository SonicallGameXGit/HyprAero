#pragma once

#include <hyprland/src/config/ConfigValue.hpp>
#include <hyprland/src/debug/log/Logger.hpp>
#include <hyprland/src/desktop/DesktopTypes.hpp>
#include <hyprland/src/helpers/math/Math.hpp>
#include <hyprland/src/layout/target/Target.hpp>
#include <hyprland/src/plugins/PluginAPI.hpp>

#include <cstdint>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include "core/fade.hpp"
#include "core/icons.hpp"
#include "core/layout.hpp"
#include "core/moving.hpp"
#include "core/safety.hpp"
#include "core/tiling.hpp"
#include "core/tokens.hpp"
#include "core/window.hpp"
#include "host/pictures.hpp"

// What the plugin keeps while it is loaded, and the safety switch every entry point runs through (AGENTS.md
// section 5.1). Included by main.cpp and the rest of host/ only.
namespace frames::host {

    class Frame;

    constexpr std::string_view pluginName = "hypraero-frames";

    enum class GrabKind : std::uint8_t {
        Move,
        Resize,
        // A line between windows in the layout
        Split,
    };

    // A line between windows in the layout, held: the window on whose side it is, which side, and how far from the
    // line the pointer holds it
    struct HeldLine {
        PHLWINDOWREF window   = {};
        bool         vertical = true;
        // The window's right or bottom side; else its left or top
        bool   after  = false;
        double offset = 0;
    };

    // A press on a frame's caption or edge, or on a line between windows, held (host/frames.cpp)
    struct Grab {
        // None for a line
        WP<Frame> frame = {};
        GrabKind  kind  = GrabKind::Move;
        // Where the press was, and the frame and the window's placement then
        Vector2D  start     = {};
        Box       outer     = {};
        Placement placement = Placement::Floating;
        // Hyprland's own drag of the window has begun: Hyprland moves or resizes it from then on, until it is ended
        bool                dragging = false;
        WP<Layout::ITarget> dragged  = {};
        // The lines held, one or both where they meet
        std::optional<HeldLine> vertical   = std::nullopt;
        std::optional<HeldLine> horizontal = std::nullopt;
    };

    enum class DropKind : std::uint8_t {
        // The top of a screen: into the layout
        Layout,
        // Near a side of a tiled window: beside it there
        Beside,
    };

    // Where letting go of a window being moved puts it, by its caption or by Hyprland's own drag (host/frames.cpp)
    struct Drop {
        PHLWINDOWREF  window = {};
        DropKind      kind   = DropKind::Layout;
        PHLMONITORREF screen = {};
        PHLWINDOWREF  beside = {};
        Side          side   = Side::Left;
        // What it takes there, on the screen: the preview's place
        Box area = {};
    };

    // A place found under the pointer, not shown or taken yet: only once the pointer stayed on it long enough
    // (core/tiling.hpp dropReady), counted from `sinceMs`
    struct WaitingDrop {
        Drop   drop    = {};
        double sinceMs = 0;
    };

    // Windows 7's glass outline of where a moved window goes, drawn by that window's frame under it, fading in and out
    struct Preview {
        WP<Frame>     drawer = {};
        PHLMONITORREF screen = {};
        Box           area   = {};
        Fade          fade   = {};
    };

    // The last press on a caption, to tell a double click
    struct LastClick {
        WP<Frame> frame = {};
        Click     click = {};
    };

    // Made in pluginInit, destroyed in pluginExit
    struct State {
        HANDLE              handle  = nullptr;
        std::uint64_t       load    = 0;
        frames::Safety      safety  = {};
        SP<SHyprCtlCommand> command = nullptr;

        Theme                                       theme       = Theme::Aero;
        IconShelf                                   icons       = {};
        Pictures                                    pictures    = {};
        std::unique_ptr<CConfigValue<Config::BOOL>> blurEnabled = nullptr;
        // Dwindle's resizing by the side held, which the lines between windows are moved with
        std::unique_ptr<CConfigValue<Config::BOOL>> smartResizing = nullptr;
        // Off: the preview appears and goes at once, as everything of Hyprland's then does
        std::unique_ptr<CConfigValue<Config::BOOL>> animationsEnabled = nullptr;
        // The frames' own scale, QT_SCALE_FACTOR's (core/layout.hpp)
        double scale = 1;

        std::vector<WP<Frame>>           frames    = {};
        std::vector<CHyprSignalListener> listeners = {};
        // The frame the pointer was last over, and the one whose button is held down
        WP<Frame> underPointer = {};
        WP<Frame> holding      = {};
        // The caption or edge held, and the resize cursor the frames show (empty: none)
        std::optional<Grab> grab   = std::nullopt;
        std::string         cursor = "";
        // Where letting go of the window being moved puts it, its preview, and the preview fading out; before that, the
        // place waiting under the pointer
        std::optional<WaitingDrop> waiting = std::nullopt;
        std::optional<Drop>        drop    = std::nullopt;
        std::optional<Preview>     preview = std::nullopt;
        std::optional<Preview>     leaving = std::nullopt;
        // For a double click on a caption; its second press was the frames', so its release is too
        std::optional<LastClick> lastClick  = std::nullopt;
        bool                     ownRelease = false;
    };

    // Empty whenever the plugin is not loaded. With `loads` below, the only globals.
    extern constinit std::unique_ptr<State> state;

    // How many times the plugin was loaded since Hyprland started. The library stays in memory after an unload
    // (it is linked with -z nodelete), so a frame Hyprland deletes late can tell it belongs to an earlier load.
    extern constinit std::uint64_t loads;

    const Tokens& currentTokens() noexcept;

    // The clock the previews fade by, in milliseconds, and how long a fade takes (motion-soft, none without animations)
    double nowMs() noexcept;
    double fadeTime() noexcept;

    void logLine(Hyprutils::CLI::eLogLevel level, std::string_view text) noexcept;
    void notify(HANDLE handle, eIcons icon, std::string_view text) noexcept;

    // Called once, when the safety switch has just been turned off
    void sayTurnedOff() noexcept;

    // The safety switch with what the plugin does when it trips. Every entry point goes through this or runAlways.
    template <typename Body>
    bool run(std::string_view where, Body&& body) noexcept {
        if (state == nullptr) {
            return false;
        }

        const bool wasOff = state->safety.off;
        const bool ran    = frames::guarded(state->safety, where, body);
        if (!wasOff && state->safety.off) {
            sayTurnedOff();
        }

        return ran;
    }

    template <typename Body>
    bool runAlways(std::string_view where, Body&& body) noexcept {
        if (state == nullptr) {
            return false;
        }

        const bool wasOff = state->safety.off;
        const bool ran    = frames::guardedAlways(state->safety, where, body);
        if (!wasOff && state->safety.off) {
            sayTurnedOff();
        }

        return ran;
    }

}
