#include "core/buttons.hpp"

namespace frames {

    Button buttonAt(Part part) noexcept {
        if (part == Part::Maximize) {
            return Button::Maximize;
        }

        if (part == Part::Close) {
            return Button::Close;
        }

        return Button::None;
    }

    bool movePointer(Pointer& pointer, Button at) noexcept {
        if (pointer.hovered == at) {
            return false;
        }

        pointer.hovered = at;
        return true;
    }

    bool pressPointer(Pointer& pointer, Button at) noexcept {
        pointer.hovered = at;
        pointer.pressed = at;
        return at != Button::None;
    }

    Button releasePointer(Pointer& pointer, Button at) noexcept {
        const Button pressed = pointer.pressed;
        pointer.pressed      = Button::None;
        pointer.hovered      = at;
        if (pressed != Button::None && pressed == at) {
            return pressed;
        }

        return Button::None;
    }

    bool leavePointer(Pointer& pointer) noexcept {
        // A held button stays held: the press is let go of later, wherever the pointer is then
        return movePointer(pointer, Button::None);
    }

    Look lookOf(const Pointer& pointer, Button button, bool active) noexcept {
        if (button == Button::None) {
            return active ? Look::Rest : Look::Inactive;
        }

        if (pointer.pressed == button) {
            return pointer.hovered == button ? Look::Pressed : Look::Hover;
        }

        if (pointer.hovered == button && pointer.pressed == Button::None) {
            return Look::Hover;
        }

        return active ? Look::Rest : Look::Inactive;
    }

    Piece facePiece(Button button, Look look) noexcept {
        if (button == Button::Close) {
            switch (look) {
            case Look::Hover:
                return Piece::FaceCloseHover;
            case Look::Pressed:
                return Piece::FaceClosePressed;
            case Look::Inactive:
                return Piece::FaceCloseInactive;
            case Look::Rest:
                break;
            }

            return Piece::FaceCloseRest;
        }

        switch (look) {
        case Look::Hover:
            return Piece::FaceMaximizeHover;
        case Look::Pressed:
            return Piece::FaceMaximizePressed;
        case Look::Inactive:
            return Piece::FaceMaximizeInactive;
        case Look::Rest:
            break;
        }

        return Piece::FaceMaximizeRest;
    }

    Piece glyphPiece(Button button, Look look, bool maximized) noexcept {
        const bool inactive = look == Look::Inactive;
        if (button == Button::Close) {
            return inactive ? Piece::GlyphCloseInactive : Piece::GlyphClose;
        }

        if (maximized) {
            return inactive ? Piece::GlyphRestoreInactive : Piece::GlyphRestore;
        }

        return inactive ? Piece::GlyphMaximizeInactive : Piece::GlyphMaximize;
    }

    Piece glowPiece(Button button) noexcept {
        return button == Button::Close ? Piece::GlowClose : Piece::GlowMaximize;
    }

    bool glows(Look look) noexcept {
        return look == Look::Hover || look == Look::Pressed;
    }

}
