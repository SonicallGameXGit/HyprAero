#include "core/icons.hpp"

namespace frames {

    namespace {

        std::uint32_t multiply(std::uint8_t part, std::uint8_t alpha) {
            constexpr std::uint32_t most = 255;
            return (static_cast<std::uint32_t>(part) * alpha + most / 2) / most;
        }

    }

    std::vector<std::uint32_t> premultiply(std::span<const std::uint8_t> rgba) {
        std::vector<std::uint32_t> pixels = {};
        pixels.reserve(rgba.size() / 4);
        for (std::size_t at = 0; at + 3 < rgba.size(); at += 4) {
            const std::uint8_t alpha = rgba[at + 3];
            pixels.push_back((static_cast<std::uint32_t>(alpha) << 24U) | (multiply(rgba[at], alpha) << 16U) | (multiply(rgba[at + 1], alpha) << 8U) |
                             multiply(rgba[at + 2], alpha));
        }

        return pixels;
    }

    bool keepIcon(IconShelf& shelf, const std::string& className, int size, std::vector<std::uint32_t> pixels) {
        if ((size != 16 && size != 32) || pixels.size() != static_cast<std::size_t>(size) * static_cast<std::size_t>(size)) {
            return false;
        }

        if (!shelf.icons.contains(className) && shelf.icons.size() >= maxIcons) {
            return false;
        }

        IconPixels& icon = shelf.icons[className];
        if (size == 16) {
            icon.small = std::move(pixels);
        } else {
            icon.large = std::move(pixels);
        }

        shelf.changes += 1;
        return true;
    }

    std::span<const std::uint32_t> findIcon(const IconShelf& shelf, std::string_view className, int size) {
        const auto found = shelf.icons.find(std::string(className));
        if (found == shelf.icons.end()) {
            return {};
        }

        return size == 32 ? std::span<const std::uint32_t>(found->second.large) : std::span<const std::uint32_t>(found->second.small);
    }

}
