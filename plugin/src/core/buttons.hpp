#pragma once

#include <cstdint>

#include "core/layout.hpp"
#include "core/pieces.hpp"

// The caption buttons under the pointer, as Windows 7's behave: a button acts when it is let go over the same
// button it was pressed on; dragged off, it only looks lit, and let go elsewhere it does nothing.
namespace frames {

    enum class Button : std::uint8_t {
        None,
        Maximize,
        Close,
    };

    Button buttonAt(Part part) noexcept;

    struct Pointer {
        Button hovered = Button::None;
        Button pressed = Button::None;
    };

    // The pointer moved over `at`. Returns whether a button's look changed.
    bool movePointer(Pointer& pointer, Button at) noexcept;

    // The left button went down over `at`. Returns whether the press is the frame's (on a caption button), so it
    // is not passed on.
    bool pressPointer(Pointer& pointer, Button at) noexcept;

    // The left button went up over `at`. Returns the button to act on, None when there is nothing to do.
    Button releasePointer(Pointer& pointer, Button at) noexcept;

    // The pointer left the frame (or the window went away under it)
    bool leavePointer(Pointer& pointer) noexcept;

    enum class Look : std::uint8_t {
        Rest,
        Hover,
        Pressed,
        Inactive,
    };

    Look lookOf(const Pointer& pointer, Button button, bool active) noexcept;

    Piece facePiece(Button button, Look look) noexcept;

    // Maximize turns into Restore while the window is maximized
    Piece glyphPiece(Button button, Look look, bool maximized) noexcept;

    Piece glowPiece(Button button) noexcept;

    bool glows(Look look) noexcept;

}
