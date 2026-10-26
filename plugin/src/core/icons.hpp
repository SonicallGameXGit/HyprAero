#pragma once

#include <cstddef>
#include <cstdint>
#include <span>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

// The apps' icons the companion sent, by their windows' class. Windows 7's generic application icon stands in
// for a class with none.
namespace frames {

    // More apps than anyone has open; past it a new class is refused, so a flood cannot use up the memory
    constexpr std::size_t maxIcons = 256;

    // Each pixel as cairo keeps it (CAIRO_FORMAT_ARGB32): 0xAARRGGBB in the machine's byte order, the colour
    // multiplied by the alpha
    std::vector<std::uint32_t> premultiply(std::span<const std::uint8_t> rgba);

    struct IconPixels {
        std::vector<std::uint32_t> small = {};
        std::vector<std::uint32_t> large = {};
    };

    struct IconShelf {
        std::unordered_map<std::string, IconPixels> icons = {};
        // Goes up with every icon kept, so a picture made from an older one is known to be old
        std::uint64_t changes = 0;
    };

    // Returns whether it was kept: a size other than 16 or 32, pixels of the wrong count or a full shelf keep nothing
    bool keepIcon(IconShelf& shelf, const std::string& className, int size, std::vector<std::uint32_t> pixels);

    // The pixels at that size, or empty when there are none
    std::span<const std::uint32_t> findIcon(const IconShelf& shelf, std::string_view className, int size);

}
