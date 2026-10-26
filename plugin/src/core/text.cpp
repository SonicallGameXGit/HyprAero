#include "core/text.hpp"

#include <cstdint>

namespace frames {

    namespace {

        constexpr std::string_view replacement = "\xEF\xBF\xBD";

        // The character starting at `at`, and how many bytes it takes; 0 bytes when they are not valid UTF-8
        struct Decoded {
            char32_t    character = 0;
            std::size_t length    = 0;
        };

        Decoded decode(std::string_view text, std::size_t at) {
            const auto byte = [&](std::size_t index) { return static_cast<std::uint8_t>(text[at + index]); };
            const auto next = [&](std::size_t index) { return at + index < text.size() && (byte(index) & 0xC0U) == 0x80U; };

            const std::uint8_t first = byte(0);
            if (first < 0x80U) {
                return {.character = first, .length = 1};
            }

            std::size_t length  = 0;
            char32_t    least   = 0;
            char32_t    current = 0;
            if ((first & 0xE0U) == 0xC0U) {
                length  = 2;
                least   = 0x80;
                current = first & 0x1FU;
            } else if ((first & 0xF0U) == 0xE0U) {
                length  = 3;
                least   = 0x800;
                current = first & 0x0FU;
            } else if ((first & 0xF8U) == 0xF0U) {
                length  = 4;
                least   = 0x10000;
                current = first & 0x07U;
            } else {
                return {};
            }

            for (std::size_t index = 1; index < length; index++) {
                if (!next(index)) {
                    return {};
                }

                current = (current << 6U) | (byte(index) & 0x3FU);
            }

            // Too long a form, a UTF-16 surrogate, or past Unicode's last character
            const bool overlong  = current < least;
            const bool surrogate = current >= 0xD800 && current <= 0xDFFF;
            if (overlong || surrogate || current > 0x10FFFF) {
                return {};
            }

            return {.character = current, .length = length};
        }

        bool isControl(char32_t character) {
            const bool c0       = character < 0x20 || character == 0x7F;
            const bool c1       = character >= 0x80 && character <= 0x9F;
            const bool newLines = character == 0x2028 || character == 0x2029;
            return c0 || c1 || newLines;
        }

    }

    std::string cleanTitle(std::string_view raw) {
        std::string clean = "";
        clean.reserve(raw.size() < maxTitleBytes ? raw.size() : maxTitleBytes);

        std::size_t at = 0;
        while (at < raw.size()) {
            const Decoded    decoded = decode(raw, at);
            std::string_view piece   = replacement;
            if (decoded.length == 0) {
                at += 1;
            } else if (isControl(decoded.character)) {
                piece = " ";
                at += decoded.length;
            } else {
                piece = raw.substr(at, decoded.length);
                at += decoded.length;
            }

            if (clean.size() + piece.size() > maxTitleBytes) {
                break;
            }

            clean.append(piece);
        }

        return clean;
    }

}
