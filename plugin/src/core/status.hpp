#pragma once

#include <string>
#include <string_view>

#include "core/safety.hpp"

// What `hyprctl hypraero-frames` answers (AGENTS.md section 6)
namespace frames {

    // A JSON string literal, quotes included. Expects plain text (plainText): only quotes, backslashes and
    // control characters are escaped.
    std::string jsonString(std::string_view text);

    std::string statusText(const Safety& safety, std::string_view version, bool json);

}
