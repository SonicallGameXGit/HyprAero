#pragma once

#include <cstdint>
#include <optional>

// What a window's state means for its frame. The host reads the state from Hyprland and the app; these decide.
namespace frames {

    enum class Placement : std::uint8_t {
        Floating,
        // Tiled by Hyprland's layout: what a maximized window was on Windows
        InLayout,
        // Hyprland's own maximize (`fullscreen 1`)
        Maximized,
    };

    Placement placementOf(bool floating, bool maximized) noexcept;

    // Maximize shows Restore while the window is not floating
    bool showsRestore(Placement placement) noexcept;

    // Rounded corners only on a floating window: in the layout a frame meets its neighbours and the screen edge to edge
    bool rounded(Placement placement) noexcept;

    enum class Toggle : std::uint8_t {
        Float,
        Tile,
        Unmaximize,
    };

    // What a click on Maximize / Restore does
    Toggle toggleFor(Placement placement) noexcept;

    struct Size {
        double width  = 0;
        double height = 0;
    };

    // An app that allows exactly one size: its window is not resized and does not go into the layout
    bool fixedSize(std::optional<Size> smallest, std::optional<Size> largest) noexcept;

    // Whether Maximize / Restore can be clicked. A fixed window that is in the layout anyway can still leave it.
    bool canToggle(Placement placement, bool fixed) noexcept;

    // Whether the frame's edges resize the window
    bool resizable(Placement placement, bool fixed) noexcept;

    // What a Wayland app said about its title bar through xdg-decoration
    enum class DecorationRequest : std::uint8_t {
        // It never asked (GTK, Firefox): by the protocol, it draws its own
        Never,
        // It asked, then took it back (`unset_mode`): the compositor chooses
        NoPreference,
        ClientSide,
        ServerSide,
    };

    // From what Hyprland kept: whether the app asked at all, and zxdg_toplevel_decoration_v1's mode (0 for none)
    DecorationRequest decorationRequestFrom(bool asked, std::uint32_t mode) noexcept;

    // Whether a Wayland app wants the frame: not when it draws its own title bar
    bool wantsServerFrame(DecorationRequest request) noexcept;

}
