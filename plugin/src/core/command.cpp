#include "core/command.hpp"

#include <array>

namespace frames {

    namespace {

        constexpr std::string_view commandName = "hypraero-frames";

        // The words of a request, split on runs of spaces; at most `most` of them, nothing when there are more
        std::optional<std::vector<std::string_view>> splitWords(std::string_view text, std::size_t most) {
            std::vector<std::string_view> words = {};
            std::size_t                   at    = 0;
            while (at < text.size()) {
                if (text[at] == ' ') {
                    at += 1;
                    continue;
                }

                const std::size_t end  = text.find(' ', at);
                const std::size_t stop = end == std::string_view::npos ? text.size() : end;
                if (words.size() == most) {
                    return std::nullopt;
                }

                words.push_back(text.substr(at, stop - at));
                at = stop;
            }

            return words;
        }

        std::optional<std::uint8_t> hexDigit(char digit) {
            if (digit >= '0' && digit <= '9') {
                return static_cast<std::uint8_t>(digit - '0');
            }

            if (digit >= 'a' && digit <= 'f') {
                return static_cast<std::uint8_t>(digit - 'a' + 10);
            }

            if (digit >= 'A' && digit <= 'F') {
                return static_cast<std::uint8_t>(digit - 'A' + 10);
            }

            return std::nullopt;
        }

        Request parseIcon(const std::vector<std::string_view>& words) {
            if (words.size() != 4) {
                return BadRequest{.reason = "an icon needs a size, a class and pixels"};
            }

            int size = 0;
            if (words[1] == "16") {
                size = 16;
            } else if (words[1] == "32") {
                size = 32;
            } else {
                return BadRequest{.reason = "an icon is 16 or 32 pixels"};
            }

            const auto className = fromHex(words[2]);
            if (!className.has_value() || className->empty() || className->size() > maxClassLength) {
                return BadRequest{.reason = "the class is not 1 to 256 bytes in hexadecimal"};
            }

            auto pixels = fromHex(words[3]);
            if (!pixels.has_value() || pixels->size() != static_cast<std::size_t>(size) * static_cast<std::size_t>(size) * 4) {
                return BadRequest{.reason = "the pixels are not size x size x 4 bytes in hexadecimal"};
            }

            return IconRequest{
                .className = std::string(className->begin(), className->end()),
                .size      = size,
                .rgba      = std::move(*pixels),
            };
        }

    }

    Request parseRequest(std::string_view text) {
        if (text.size() > maxRequestLength) {
            return BadRequest{.reason = "too long"};
        }

        // hyprctl may leave a line break at the end
        while (!text.empty() && (text.back() == '\n' || text.back() == ' ')) {
            text.remove_suffix(1);
        }

        if (!text.starts_with(commandName)) {
            return BadRequest{.reason = "not a request for hypraero-frames"};
        }

        const std::string_view rest = text.substr(commandName.size());
        if (rest.empty()) {
            return StatusRequest{};
        }

        // Hyprland matches the command by its start, so "hypraero-framesX" arrives here too
        if (rest.front() != ' ') {
            return BadRequest{.reason = "unknown request"};
        }

        const auto words = splitWords(rest, 4);
        if (!words.has_value()) {
            return BadRequest{.reason = "too many words"};
        }

        if (words->empty()) {
            return StatusRequest{};
        }

        const std::string_view verb = words->front();
        if (verb == "theme") {
            if (words->size() == 2 && (*words)[1] == "aero") {
                return ThemeRequest{.theme = Theme::Aero};
            }

            if (words->size() == 2 && (*words)[1] == "slate") {
                return ThemeRequest{.theme = Theme::Slate};
            }

            return BadRequest{.reason = "the theme is aero or slate"};
        }

        if (verb == "icon") {
            return parseIcon(*words);
        }

        if (verb == "missing" && words->size() == 1) {
            return MissingRequest{};
        }

        return BadRequest{.reason = "unknown request"};
    }

    std::string toHex(std::string_view bytes) {
        constexpr std::array<char, 16> digits = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'};

        std::string hex = "";
        hex.reserve(bytes.size() * 2);
        for (const char character : bytes) {
            const auto byte = static_cast<std::uint8_t>(character);
            hex.push_back(digits.at(byte >> 4U));
            hex.push_back(digits.at(byte & 0x0FU));
        }

        return hex;
    }

    std::optional<std::vector<std::uint8_t>> fromHex(std::string_view hex) {
        if (hex.size() % 2 != 0) {
            return std::nullopt;
        }

        std::vector<std::uint8_t> bytes = {};
        bytes.reserve(hex.size() / 2);
        for (std::size_t at = 0; at < hex.size(); at += 2) {
            const auto high = hexDigit(hex[at]);
            const auto low  = hexDigit(hex[at + 1]);
            if (!high.has_value() || !low.has_value()) {
                return std::nullopt;
            }

            bytes.push_back(static_cast<std::uint8_t>((static_cast<unsigned>(*high) << 4U) | static_cast<unsigned>(*low)));
        }

        return bytes;
    }

    std::string missingText(Theme theme, const std::vector<std::string>& classes) {
        std::string text = theme == Theme::Slate ? "theme slate\n" : "theme aero\n";
        for (const std::string& className : classes) {
            text += toHex(className);
            text += '\n';
        }

        return text;
    }

}
