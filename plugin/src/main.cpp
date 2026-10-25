// The entry points Hyprland calls. Each one is a thin wrapper that runs its work through the safety switch, so
// nothing that goes wrong here reaches Hyprland (AGENTS.md section 5.1).

#include <hyprland/src/debug/log/Logger.hpp>
#include <hyprland/src/plugins/PluginAPI.hpp>

#include <any>
#include <cstdint>
#include <format>
#include <memory>
#include <stdexcept>
#include <string>
#include <string_view>
#include <unordered_map>

#include "core/safety.hpp"
#include "core/status.hpp"

namespace {

    constexpr std::string_view pluginName    = "hypraero-frames";
    constexpr std::string_view pluginVersion = FRAMES_VERSION;

    // How long Hyprland's own notification about the plugin stays, in milliseconds
    constexpr std::uint64_t noticeTime = 10000;

    // Everything the plugin keeps: made in pluginInit, destroyed in pluginExit. The pointer is the only global,
    // and it is empty whenever the plugin is not loaded.
    struct State {
        HANDLE              handle        = nullptr;
        frames::Safety      safety        = {};
        SP<SHyprCtlCommand> statusCommand = nullptr;
    };

    constinit std::unique_ptr<State> state = nullptr;

    void logLine(Hyprutils::CLI::eLogLevel level, std::string_view text) noexcept {
        try {
            Log::logger->log(level, std::format("[{}] {}", pluginName, text));
        } catch (...) { // NOLINT(bugprone-empty-catch): a line that cannot be written is lost; failing over it would be worse
        }
    }

    void notify(HANDLE handle, eIcons icon, std::string_view text) noexcept {
        try {
            const std::unordered_map<std::string, std::any> notice = {
                {"text", std::format("[{}] {}", pluginName, text)},
                {"time", noticeTime},
                {"color", CHyprColor(0)},
                {"icon", icon},
            };
            HyprlandAPI::addNotificationV2(handle, notice);
        } catch (...) {
            logLine(Log::ERR, "could not show a notification");
        }
    }

    // Called once, when the safety switch has just been turned off
    void sayTurnedOff() noexcept {
        if (state == nullptr) {
            return;
        }

        try {
            logLine(Log::CRIT, std::format("turned off after an error in {}: {}", state->safety.where, state->safety.reason));
        } catch (...) {
            logLine(Log::CRIT, "turned off after an error");
        }
        notify(state->handle, ICON_ERROR, "turned off after an error; `hyprctl hypraero-frames` says why");
    }

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

    std::string answerStatus(eHyprCtlOutputFormat format, const std::string& /* request */) noexcept {
        std::string answer = "";
        const bool  ran    = runAlways("status command", [&] { answer = frames::statusText(state->safety, pluginVersion, format == FORMAT_JSON); });
        if (!ran) {
            return "hypraero-frames: no answer, see Hyprland's log\n";
        }

        return answer;
    }

}

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

// The one place that throws: it is how Hyprland's interface refuses a load (it catches it and unloads the plugin;
// pluginExit is not called then). Nothing is registered before the checks.
APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
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

        state->statusCommand = HyprlandAPI::registerHyprCtlCommand(handle, SHyprCtlCommand{
                                                                               .name  = std::string(pluginName),
                                                                               .exact = true,
                                                                               .fn    = answerStatus,
                                                                           });
        if (state->statusCommand == nullptr) {
            logLine(Log::WARN, "could not register the hyprctl command");
        }
    } catch (...) {
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
    if (state == nullptr) {
        return;
    }

    runAlways("unload", [] {
        if (state->statusCommand != nullptr) {
            HyprlandAPI::unregisterHyprCtlCommand(state->handle, state->statusCommand);
        }
    });
    state.reset();
    logLine(Log::INFO, "unloaded");
}
