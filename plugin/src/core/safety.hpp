#pragma once

#include <cstddef>
#include <exception>
#include <string>
#include <string_view>

// The safety switch (AGENTS.md section 5.1). Plain C++ without Hyprland, so the tests cover it.
namespace frames {

    // The longest text kept about an error; anything longer is cut
    constexpr std::size_t maxReasonLength = 200;

    struct Safety {
        bool        off    = false;
        std::string where  = "";
        std::string reason = "";
    };

    // Printable ASCII only, at most maxLength characters: whatever reaches the log or a reply is plain and short,
    // whatever bytes it came with
    std::string plainText(std::string_view text, std::size_t maxLength) noexcept;

    // Turns the plugin off for the session and remembers where and why. Only the first error is kept: what
    // follows it is usually a consequence.
    void turnOff(Safety& safety, std::string_view where, std::string_view reason) noexcept;

    // Runs body, unless the plugin is already off. Nothing it throws gets out: it turns the plugin off instead.
    // Returns whether body ran to its end.
    template <typename Body>
    bool guarded(Safety& safety, std::string_view where, Body&& body) noexcept {
        if (safety.off) {
            return false;
        }

        try {
            body();
            return true;
        } catch (const std::exception& error) {
            turnOff(safety, where, error.what());
        } catch (...) {
            turnOff(safety, where, "an exception of an unknown type");
        }

        return false;
    }

    // As guarded, but runs body while the plugin is off too: for what must keep working then (saying that it is
    // off, cleaning up on unload)
    template <typename Body>
    bool guardedAlways(Safety& safety, std::string_view where, Body&& body) noexcept {
        try {
            body();
            return true;
        } catch (const std::exception& error) {
            turnOff(safety, where, error.what());
        } catch (...) {
            turnOff(safety, where, "an exception of an unknown type");
        }

        return false;
    }

}
