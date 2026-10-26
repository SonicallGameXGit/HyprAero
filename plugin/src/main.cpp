// The entry points Hyprland calls. Each one is a thin wrapper that runs its work through the safety switch, so
// nothing that goes wrong here reaches Hyprland (AGENTS.md section 5.1). The work itself is in host/.

#include <hyprland/src/plugins/PluginAPI.hpp>

#include <format>
#include <memory>
#include <stdexcept>
#include <string>
#include <string_view>

#include "host/frame.hpp"
#include "host/frames.hpp"
#include "host/state.hpp"

namespace {

    constexpr std::string_view pluginVersion = FRAMES_VERSION;

}

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

// The one place that throws: it is how Hyprland's interface refuses a load (it catches it and unloads the plugin,
// removing what was registered, without calling pluginExit). Nothing is registered before the checks.
APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    using namespace frames::host;

    const std::string serverHash = __hyprland_api_get_hash();
    const std::string clientHash = __hyprland_api_get_client_hash();
    if (serverHash != clientHash) {
        notify(handle, ICON_ERROR, "built for another Hyprland; rebuild it against the one running");
        throw std::runtime_error("[hypraero-frames] built for another Hyprland");
    }

    if (state != nullptr) {
        throw std::runtime_error("[hypraero-frames] loaded twice");
    }

    try {
        state         = std::make_unique<State>();
        state->handle = handle;
        loads += 1;
        state->load = loads;

        // Not exact: Hyprland hands every request starting with the name to it, and core/command.cpp sorts them
        state->command = HyprlandAPI::registerHyprCtlCommand(handle, SHyprCtlCommand{
                                                                         .name  = std::string(pluginName),
                                                                         .exact = false,
                                                                         .fn    = answerRequest,
                                                                     });
        if (state->command == nullptr) {
            logLine(Log::WARN, "could not register the hyprctl command");
        }

        startFrames();
    } catch (...) {
        stopFrames();
        state.reset();
        throw;
    }

    logLine(Log::INFO, std::format("loaded, version {}", pluginVersion));
    return {
        .name        = std::string(pluginName),
        .description = "Windows 7 window frames for HyprAero",
        .author      = "HyprAero",
        .version     = std::string(pluginVersion),
    };
}

APICALL EXPORT void PLUGIN_EXIT() noexcept {
    using namespace frames::host;

    if (state == nullptr) {
        return;
    }

    // Hyprland removes the frames itself right after this returns (its unloadPlugin); until then they draw nothing
    stopFrames();
    runAlways("unload", [] {
        if (state->command != nullptr) {
            HyprlandAPI::unregisterHyprCtlCommand(state->handle, state->command);
        }
    });
    state.reset();
    logLine(Log::INFO, "unloaded");
}
