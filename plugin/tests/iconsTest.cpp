#include <array>
#include <cstdint>
#include <string>
#include <vector>

#include "check.hpp"
#include "core/icons.hpp"

namespace {

    void premultiplied() {
        const std::array<std::uint8_t, 12> rgba   = {255, 0, 0, 128, 10, 20, 30, 255, 200, 200, 200, 0};
        const auto                         pixels = frames::premultiply(rgba);
        check::that(pixels.size() == 3, "one value a pixel");
        check::that(pixels[0] == 0x80800000U, "half see-through red");
        check::that(pixels[1] == 0xff0a141eU, "opaque stays as it is");
        check::that(pixels[2] == 0U, "fully see-through is all zero");
        check::that(frames::premultiply(std::array<std::uint8_t, 3>{1, 2, 3}).empty(), "a cut-off pixel is left out");
    }

    void shelf() {
        frames::IconShelf shelf = {};
        check::that(frames::keepIcon(shelf, "kitty", 16, std::vector<std::uint32_t>(256, 1)), "a 16 pixel icon is kept");
        check::that(frames::findIcon(shelf, "kitty", 16).size() == 256, "and found");
        check::that(frames::findIcon(shelf, "kitty", 32).empty(), "no 32 pixel one yet");
        check::that(frames::findIcon(shelf, "foot", 16).empty(), "nor for another class");
        check::that(shelf.changes == 1, "each kept icon is a change");

        check::that(!frames::keepIcon(shelf, "kitty", 24, std::vector<std::uint32_t>(576, 1)), "24 pixels are refused");
        check::that(!frames::keepIcon(shelf, "kitty", 32, std::vector<std::uint32_t>(100, 1)), "the wrong count of pixels is refused");
        check::that(shelf.changes == 1, "a refused icon changes nothing");
    }

    void full() {
        frames::IconShelf shelf = {};
        for (std::size_t index = 0; index < frames::maxIcons; index++) {
            frames::keepIcon(shelf, "app" + std::to_string(index), 16, std::vector<std::uint32_t>(256, 1));
        }

        check::that(!frames::keepIcon(shelf, "one more", 16, std::vector<std::uint32_t>(256, 1)), "a full shelf refuses a new class");
        check::that(frames::keepIcon(shelf, "app0", 32, std::vector<std::uint32_t>(1024, 1)), "and still takes one it has");
    }

}

int main() {
    premultiplied();
    shelf();
    full();
    return check::result("icons");
}
