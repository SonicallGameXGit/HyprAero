#pragma once

#include <hyprland/src/desktop/DesktopTypes.hpp>

#include "core/window.hpp"

// What a Wayland app asked about its title bar. Hyprland answers every app "the compositor draws it" and keeps the
// request in a table its header marks private; this is the one place the plugin reads it (AGENTS.md section 5.1,
// the exception for xdg-decoration). Read-only, inside a call from Hyprland.
namespace frames::host {

    // Never for an X11 window or one that is not an xdg toplevel
    DecorationRequest decorationRequestOf(const PHLWINDOW& window);

}
