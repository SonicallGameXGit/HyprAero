#include <string>
#include <variant>

#include "check.hpp"
#include "core/command.hpp"

namespace {

    constexpr std::size_t smallBytes = 1024;
    constexpr std::size_t largeBytes = 4096;
    constexpr std::size_t oddBytes   = 2304;

    template <typename Kind>
    bool is(const frames::Request& request) {
        return std::holds_alternative<Kind>(request);
    }

    std::string iconRequest(std::string_view size, std::string_view className, std::size_t pixelBytes) {
        return std::string("hypraero-frames icon ") + std::string(size) + " " + frames::toHex(className) + " " + std::string(pixelBytes * 2, 'f');
    }

    void status() {
        check::that(is<frames::StatusRequest>(frames::parseRequest("hypraero-frames")), "the bare name is the status");
        check::that(is<frames::StatusRequest>(frames::parseRequest("hypraero-frames\n")), "with a line break");
        check::that(is<frames::StatusRequest>(frames::parseRequest("hypraero-frames   ")), "with spaces");
    }

    void theme() {
        const auto slate = frames::parseRequest("hypraero-frames theme slate");
        check::that(is<frames::ThemeRequest>(slate) && std::get<frames::ThemeRequest>(slate).theme == frames::Theme::Slate, "slate");
        const auto aero = frames::parseRequest("hypraero-frames  theme   aero");
        check::that(is<frames::ThemeRequest>(aero) && std::get<frames::ThemeRequest>(aero).theme == frames::Theme::Aero, "aero, among extra spaces");
        check::that(is<frames::BadRequest>(frames::parseRequest("hypraero-frames theme")), "no theme");
        check::that(is<frames::BadRequest>(frames::parseRequest("hypraero-frames theme dark")), "an unknown theme");
        check::that(is<frames::BadRequest>(frames::parseRequest("hypraero-frames theme aero slate")), "two themes");
    }

    void icons() {
        const auto good = frames::parseRequest(iconRequest("16", "org.gnome.Nautilus", smallBytes));
        check::that(is<frames::IconRequest>(good), "a 16 pixel icon");
        if (is<frames::IconRequest>(good)) {
            const auto& icon = std::get<frames::IconRequest>(good);
            check::that(icon.className == "org.gnome.Nautilus" && icon.size == 16 && icon.rgba.size() == 1024 && icon.rgba[0] == 0xff, "its class and pixels");
        }

        check::that(is<frames::IconRequest>(frames::parseRequest(iconRequest("32", "a b\nc", largeBytes))), "a class with spaces and a line break, in hex");
        check::that(is<frames::BadRequest>(frames::parseRequest(iconRequest("24", "app", oddBytes))), "a size that is not 16 or 32");
        check::that(is<frames::BadRequest>(frames::parseRequest(iconRequest("16", "app", smallBytes - 1))), "too few pixels");
        check::that(is<frames::BadRequest>(frames::parseRequest(iconRequest("16", "app", smallBytes + 1))), "too many pixels");
        check::that(is<frames::BadRequest>(frames::parseRequest(iconRequest("16", "", smallBytes))), "an empty class");
        check::that(is<frames::BadRequest>(frames::parseRequest(iconRequest("16", std::string(257, 'x'), smallBytes))), "a class too long");
        check::that(is<frames::BadRequest>(frames::parseRequest("hypraero-frames icon 16 6170 zz")), "pixels not in hex");
        check::that(is<frames::BadRequest>(frames::parseRequest("hypraero-frames icon 16 617 00")), "a class of odd length");
        check::that(is<frames::BadRequest>(frames::parseRequest("hypraero-frames icon 16")), "missing words");
        check::that(is<frames::BadRequest>(frames::parseRequest("hypraero-frames icon 16 61 00 extra")), "a word too many");
    }

    void others() {
        check::that(is<frames::MissingRequest>(frames::parseRequest("hypraero-frames missing")), "missing");
        check::that(is<frames::BadRequest>(frames::parseRequest("hypraero-frames missing now")), "missing with words after it");
        check::that(is<frames::BadRequest>(frames::parseRequest("hypraero-framesX")), "another command that starts the same");
        check::that(is<frames::BadRequest>(frames::parseRequest("hypraero-frames fly")), "an unknown request");
        check::that(is<frames::BadRequest>(frames::parseRequest("")), "nothing");
        check::that(is<frames::BadRequest>(frames::parseRequest("hypraero-frames " + std::string(frames::maxRequestLength, 'a'))), "too long");
        check::that(is<frames::BadRequest>(frames::parseRequest("hypraero-frames a b c d e f g h")), "too many words");
    }

    void hex() {
        check::that(frames::toHex("Az\n\xff") == "417a0aff", "to hex");
        const auto bytes = frames::fromHex("417A0aff");
        check::that(bytes.has_value() && bytes->size() == 4 && (*bytes)[1] == 0x7a && (*bytes)[3] == 0xff, "from hex, either case");
        check::that(frames::fromHex("").has_value(), "empty is empty");
        check::that(!frames::fromHex("abc").has_value(), "an odd length");
        check::that(!frames::fromHex("0g").has_value(), "not a hex digit");
    }

    void missing() {
        check::that(frames::missingText(frames::Theme::Aero, {}) == "theme aero\n", "nothing missing");
        check::that(frames::missingText(frames::Theme::Slate, {"kitty", "a\nb"}) == "theme slate\n6b69747479\n610a62\n", "one hex class per line");
    }

}

int main() {
    status();
    theme();
    icons();
    others();
    hex();
    missing();
    return check::result("command");
}
