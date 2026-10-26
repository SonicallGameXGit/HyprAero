#pragma once

#include <hyprland/src/config/ConfigValue.hpp>
#include <hyprland/src/debug/log/Logger.hpp>
#include <hyprland/src/plugins/PluginAPI.hpp>

#include <cstdint>
#include <memory>
#include <string_view>
#include <vector>

#include "core/icons.hpp"
#include "core/safety.hpp"
#include "core/tokens.hpp"
#include "host/pictures.hpp"

// What the plugin keeps while it is loaded, and the safety switch every entry point runs through (AGENTS.md
// section 5.1). Included by main.cpp and the rest of host/ only.
namespace frames::host {

    class Frame;

    constexpr std::string_view pluginName = "hypraero-frames";

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

        std::vector<WP<Frame>>           frames    = {};
        std::vector<CHyprSignalListener> listeners = {};
        // The frame the pointer was last over, and the one whose button is held down
        WP<Frame> underPointer = {};
        WP<Frame> holding      = {};
    };

    // Empty whenever the plugin is not loaded. With `loads` below, the only globals.
    extern constinit std::unique_ptr<State> state;

    // How many times the plugin was loaded since Hyprland started. The library stays in memory after an unload
    // (it is linked with -z nodelete), so a frame Hyprland deletes late can tell it belongs to an earlier load.
    extern constinit std::uint64_t loads;

    const Tokens& currentTokens() noexcept;

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
