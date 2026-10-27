#include "check.hpp"
#include "core/buttons.hpp"

namespace {

    using frames::Button;
    using frames::Look;
    using frames::Piece;

    void clickActsOnRelease() {
        frames::Pointer pointer = {};
        check::that(frames::movePointer(pointer, Button::Close), "moving onto Close changes its look");
        check::that(!frames::movePointer(pointer, Button::Close), "moving on it again does not");
        check::that(frames::pressPointer(pointer, Button::Close), "a press on Close is the frame's");
        check::that(frames::lookOf(pointer, Button::Close, true) == Look::Pressed, "Close looks pressed");
        check::that(frames::releasePointer(pointer, Button::Close) == Button::Close, "let go on Close: close");
        check::that(pointer.pressed == Button::None, "nothing is held after");
        check::that(frames::lookOf(pointer, Button::Close, true) == Look::Hover, "and Close looks lit again");
    }

    void draggedOffDoesNothing() {
        frames::Pointer pointer = {};
        frames::pressPointer(pointer, Button::Maximize);
        frames::movePointer(pointer, Button::None);
        check::that(frames::lookOf(pointer, Button::Maximize, true) == Look::Hover, "held and dragged off, it only looks lit");
        check::that(frames::releasePointer(pointer, Button::None) == Button::None, "let go elsewhere: nothing");

        frames::pressPointer(pointer, Button::Maximize);
        check::that(frames::releasePointer(pointer, Button::Close) == Button::None, "let go on the other button: nothing");
        check::that(frames::lookOf(pointer, Button::Maximize, true) == Look::Rest, "and the pressed one rests");
    }

    void pressesElsewhereAreNotTheFrames() {
        frames::Pointer pointer = {};
        check::that(!frames::pressPointer(pointer, Button::None), "a press on the caption goes on to Hyprland");
        check::that(frames::releasePointer(pointer, Button::None) == Button::None, "and its release does nothing");
    }

    void whileOtherButtonIsHeldNoHover() {
        frames::Pointer pointer = {};
        frames::pressPointer(pointer, Button::Close);
        frames::movePointer(pointer, Button::Maximize);
        check::that(frames::lookOf(pointer, Button::Maximize, true) == Look::Rest, "a button is not lit while another is held");
    }

    void leaving() {
        frames::Pointer pointer = {};
        frames::movePointer(pointer, Button::Close);
        check::that(frames::leavePointer(pointer), "leaving the frame unlights Close");
        check::that(!frames::leavePointer(pointer), "leaving twice changes nothing");
    }

    void inactiveWindows() {
        const frames::Pointer pointer = {};
        check::that(frames::lookOf(pointer, Button::Close, false) == Look::Inactive, "an inactive window's buttons are pale");
        check::that(frames::facePiece(Button::Close, Look::Inactive) == Piece::FaceCloseInactive, "with the pale face");
        check::that(frames::glyphPiece(Button::Close, Look::Inactive, false, true) == Piece::GlyphCloseInactive, "and the pale glyph");

        frames::Pointer over = {};
        frames::movePointer(over, Button::Close);
        check::that(frames::lookOf(over, Button::Close, false) == Look::Hover, "under the pointer it lights up anyway");
    }

    void pieces() {
        check::that(frames::facePiece(Button::Maximize, Look::Pressed) == Piece::FaceMaximizePressed, "Maximize pressed");
        check::that(frames::glyphPiece(Button::Maximize, Look::Rest, true, true) == Piece::GlyphRestore, "in the layout, it shows Restore");
        check::that(frames::glyphPiece(Button::Maximize, Look::Rest, false, true) == Piece::GlyphMaximize, "else Maximize");
        check::that(frames::glyphPiece(Button::Maximize, Look::Rest, false, false) == Piece::GlyphMaximizeInactive, "one that cannot be clicked is pale");
        check::that(frames::glyphPiece(Button::Maximize, Look::Rest, true, false) == Piece::GlyphRestoreInactive, "Restore too");
        check::that(frames::glowPiece(Button::Close) == Piece::GlowClose && frames::glowPiece(Button::Maximize) == Piece::GlowMaximize,
                    "the red and the blue glow");
        check::that(frames::glows(Look::Hover) && frames::glows(Look::Pressed) && !frames::glows(Look::Rest), "lit buttons glow");
        check::that(frames::buttonAt(frames::Part::Close) == Button::Close && frames::buttonAt(frames::Part::Caption) == Button::None, "parts to buttons");
    }

}

int main() {
    clickActsOnRelease();
    draggedOffDoesNothing();
    pressesElsewhereAreNotTheFrames();
    whileOtherButtonIsHeldNoHover();
    leaving();
    inactiveWindows();
    pieces();
    return check::result("buttons");
}
