#pragma once

#include <cstddef>
#include <string>
#include <string_view>

// A window's title comes from any app, possibly a hostile one (AGENTS.md section 5.1). It is cleaned here before
// anything else sees it, and it is never logged.
namespace frames {

    // More than fits in any caption
    constexpr std::size_t maxTitleBytes = 512;

    // Valid UTF-8, at most maxTitleBytes, cut between two characters. Invalid bytes become U+FFFD; control
    // characters and line breaks become spaces, so the title stays one line.
    std::string cleanTitle(std::string_view raw);

}
