#include "host/state.hpp"

#include <any>
#include <format>
#include <string>
#include <unordered_map>

#include "generated/tokens.hpp"

namespace frames::host {

    constinit std::unique_ptr<State> state = nullptr;
    constinit std::uint64_t          loads = 0;

    namespace {

        // How long Hyprland's own notification about the plugin stays, in milliseconds
        constexpr std::uint64_t noticeTime = 10000;

    }

    const Tokens& currentTokens() noexcept {
        if (state != nullptr && state->theme == Theme::Slate) {
            return generated::slate;
        }

        return generated::aero;
    }

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

}
