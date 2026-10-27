#include "core/window.hpp"

#include <cmath>

namespace frames {

    namespace {

        // zxdg_toplevel_decoration_v1's modes
        constexpr std::uint32_t modeClientSide = 1;
        constexpr std::uint32_t modeServerSide = 2;

        // Hyprland's sizes are fractions after scaling; this close is the same size
        constexpr double sameSize = 0.5;

        bool usable(const Size& size) {
            return std::isfinite(size.width) && std::isfinite(size.height) && size.width > 0 && size.height > 0;
        }

    }

    Placement placementOf(bool floating, bool maximized) noexcept {
        if (maximized) {
            return Placement::Maximized;
        }

        return floating ? Placement::Floating : Placement::InLayout;
    }

    bool showsRestore(Placement placement) noexcept {
        return placement != Placement::Floating;
    }

    bool rounded(Placement placement) noexcept {
        return placement == Placement::Floating;
    }

    Toggle toggleFor(Placement placement) noexcept {
        switch (placement) {
        case Placement::Floating:
            return Toggle::Tile;
        case Placement::InLayout:
            return Toggle::Float;
        case Placement::Maximized:
            break;
        }

        return Toggle::Unmaximize;
    }

    bool fixedSize(std::optional<Size> smallest, std::optional<Size> largest) noexcept {
        if (!smallest.has_value() || !largest.has_value() || !usable(*smallest) || !usable(*largest)) {
            return false;
        }

        return std::abs(smallest->width - largest->width) < sameSize && std::abs(smallest->height - largest->height) < sameSize;
    }

    bool canToggle(Placement placement, bool fixed) noexcept {
        return !fixed || placement != Placement::Floating;
    }

    bool resizable(Placement placement, bool fixed) noexcept {
        return !fixed && placement != Placement::Maximized;
    }

    DecorationRequest decorationRequestFrom(bool asked, std::uint32_t mode) noexcept {
        if (!asked) {
            return DecorationRequest::Never;
        }

        if (mode == modeClientSide) {
            return DecorationRequest::ClientSide;
        }

        if (mode == modeServerSide) {
            return DecorationRequest::ServerSide;
        }

        return DecorationRequest::NoPreference;
    }

    bool wantsServerFrame(DecorationRequest request) noexcept {
        return request == DecorationRequest::ServerSide || request == DecorationRequest::NoPreference;
    }

}
