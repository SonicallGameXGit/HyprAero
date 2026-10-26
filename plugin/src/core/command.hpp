#pragma once

#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <variant>
#include <vector>

#include "core/tokens.hpp"

// The one door between the companion and the plugin: `hyprctl hypraero-frames ...` (AGENTS.md section 4.2).
// Everything that comes through it is untrusted text. Version 1 of the interface:
//
//   hypraero-frames                                   the status (core/status.hpp)
//   hypraero-frames theme <aero|slate>                which tokens to draw with; Aero until told
//   hypraero-frames icon <16|32> <class> <pixels>     an app's icon: its windows' class and the icon's pixels, both
//                                                     in hexadecimal; the pixels are rows of red, green, blue, alpha
//   hypraero-frames missing                           "theme <name>", then each class with a frame and no icon, one
//                                                     per line, in hexadecimal
//
// Hexadecimal keeps every request one line of plain words, whatever bytes a class has. The answer to theme and icon
// is "ok", or "error: <why>" when nothing was changed.
namespace frames {

    constexpr int interfaceVersion = 1;

    // Larger than an icon request at 32 pixels
    constexpr std::size_t maxRequestLength = 16384;
    constexpr std::size_t maxClassLength   = 256;

    struct StatusRequest {};

    struct ThemeRequest {
        Theme theme = Theme::Aero;
    };

    struct IconRequest {
        std::string               className = "";
        int                       size      = 0;
        std::vector<std::uint8_t> rgba      = {};
    };

    struct MissingRequest {};

    struct BadRequest {
        std::string_view reason = "";
    };

    using Request = std::variant<StatusRequest, ThemeRequest, IconRequest, MissingRequest, BadRequest>;

    // `text` is what Hyprland hands the command: its name and the words after it
    Request parseRequest(std::string_view text);

    std::string toHex(std::string_view bytes);

    // Nothing when it is not hexadecimal (an odd length, any other character)
    std::optional<std::vector<std::uint8_t>> fromHex(std::string_view hex);

    std::string missingText(Theme theme, const std::vector<std::string>& classes);

}
