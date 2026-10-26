#pragma once

#include <cstdint>
#include <string_view>

// The design's tokens the frames use (design/.aero/STYLE.md "Window frames"). No value is written here: the build
// reads them from design/Theme.qml into generated/tokens.hpp (plugin/tools/tokens.cmake), so the design stays
// the one place they are decided.
namespace frames {

    enum class Theme : std::uint8_t {
        Aero,
        Slate,
    };

    // Straight (not premultiplied) alpha, each part from 0 to 1
    struct Color {
        float red   = 0;
        float green = 0;
        float blue  = 0;
        float alpha = 0;
    };

    // Theme.qml writes colours as '#aarrggbb'
    constexpr Color hexColor(std::uint32_t argb) noexcept {
        constexpr float most = 255.0F;
        return {
            .red   = static_cast<float>((argb >> 16U) & 0xffU) / most,
            .green = static_cast<float>((argb >> 8U) & 0xffU) / most,
            .blue  = static_cast<float>(argb & 0xffU) / most,
            .alpha = static_cast<float>((argb >> 24U) & 0xffU) / most,
        };
    }

    struct Tokens {
        int   frameBorder            = 0;
        int   frameCaption           = 0;
        int   frameRadius            = 0;
        int   frameButtonsTop        = 0;
        int   frameButtonsRight      = 0;
        int   frameIconLeft          = 0;
        int   frameIconSize          = 0;
        int   frameTitleGap          = 0;
        Color frameGlassTint         = {};
        Color frameGlassTintInactive = {};
        Color frameEdgeOuter         = {};
        Color frameEdgeOuterInactive = {};
        Color frameEdgeInner         = {};
        Color frameEdgeInnerInactive = {};
        Color frameClientEdgeLight   = {};
        Color frameClientEdgeDark    = {};
        Color frameTitleText         = {};
        float frameTitleGlow         = 0;
        int   fontSizeSmall          = 0;
        // font-ui's candidates as one comma-separated list, which Pango reads as "the first of these it has"
        std::string_view fontUi = "";
    };

}
