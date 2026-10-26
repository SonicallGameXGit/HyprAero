#include "core/layout.hpp"

#include <cmath>

namespace frames {

    namespace {

        // Larger than any screen; a size past it is a bug or a lie, not a window
        constexpr double largest = 100000;

        // The button's face, and above it up to the frame's top edge, as on Windows: the pointer thrown at the top
        // of the screen still hits it
        Box hitBox(const Box& face) {
            return {.x = face.x, .y = 0, .width = face.width, .height = face.y + face.height};
        }

        bool usable(double size) {
            return std::isfinite(size) && size > 0 && size <= largest;
        }

    }

    bool contains(const Box& box, double x, double y) noexcept {
        return x >= box.x && x < box.x + box.width && y >= box.y && y < box.y + box.height;
    }

    std::optional<FrameLayout> layoutFrame(double outerWidth, double outerHeight, const Tokens& tokens) noexcept {
        if (!usable(outerWidth) || !usable(outerHeight)) {
            return std::nullopt;
        }

        const double border  = tokens.frameBorder;
        const double caption = tokens.frameCaption;
        if (border < 2 || caption < border || outerWidth <= border * 2 || outerHeight <= caption + border) {
            return std::nullopt;
        }

        FrameLayout layout = {};
        layout.outer       = {.x = 0, .y = 0, .width = outerWidth, .height = outerHeight};
        layout.client      = {.x = border, .y = caption, .width = outerWidth - border * 2, .height = outerHeight - caption - border};
        layout.strips      = {{
            {.x = 0, .y = 0, .width = outerWidth, .height = caption},
            {.x = 0, .y = caption, .width = border, .height = layout.client.height},
            {.x = outerWidth - border, .y = caption, .width = border, .height = layout.client.height},
            {.x = 0, .y = outerHeight - border, .width = outerWidth, .height = border},
        }};

        const PieceInfo& closeFace    = pieceInfo(Piece::FaceCloseRest);
        const PieceInfo& maximizeFace = pieceInfo(Piece::FaceMaximizeRest);
        layout.close                  = {
            .x      = outerWidth - tokens.frameButtonsRight - closeFace.width,
            .y      = static_cast<double>(tokens.frameButtonsTop),
            .width  = static_cast<double>(closeFace.width),
            .height = static_cast<double>(closeFace.height),
        };
        layout.maximize = {
            .x      = layout.close.x - maximizeFace.width,
            .y      = static_cast<double>(tokens.frameButtonsTop),
            .width  = static_cast<double>(maximizeFace.width),
            .height = static_cast<double>(maximizeFace.height),
        };
        layout.showButtons = layout.maximize.x >= border;

        // The icon and the words sit in the caption's band below the top edge
        const double band  = caption - border;
        const double right = layout.showButtons ? layout.maximize.x : outerWidth - border;
        const double size  = tokens.frameIconSize;
        layout.icon        = {.x = static_cast<double>(tokens.frameIconLeft), .y = border + std::floor((band - size) / 2), .width = size, .height = size};
        layout.showIcon    = size > 0 && layout.icon.x + size <= right;

        const double titleLeft = layout.icon.x + size + tokens.frameTitleGap;
        layout.title           = {.x = titleLeft, .y = border, .width = right - tokens.frameTitleGap - titleLeft, .height = band};
        layout.showTitle       = layout.showIcon && layout.title.width >= 1;

        return layout;
    }

    Part partAt(const FrameLayout& layout, double x, double y) noexcept {
        if (!contains(layout.outer, x, y)) {
            return Part::Outside;
        }

        if (contains(layout.client, x, y)) {
            return Part::Client;
        }

        if (layout.showButtons && contains(hitBox(layout.maximize), x, y)) {
            return Part::Maximize;
        }

        if (layout.showButtons && contains(hitBox(layout.close), x, y)) {
            return Part::Close;
        }

        if (y < layout.client.y) {
            return Part::Caption;
        }

        return Part::Edge;
    }

    Box glyphBox(const Box& face, double glyphWidth, double glyphHeight) noexcept {
        return {
            .x      = face.x + std::floor((face.width - glyphWidth + 1) / 2),
            .y      = face.y + std::floor((face.height - 1 - glyphHeight) / 2),
            .width  = glyphWidth,
            .height = glyphHeight,
        };
    }

    Box titleGlowBox(const FrameLayout& layout, double textWidth) noexcept {
        const PieceInfo& glow = pieceInfo(Piece::GlowTitle);
        return {
            .x      = layout.title.x - titleGlowReach,
            .y      = layout.title.y + std::floor((layout.title.height - glow.height) / 2),
            .width  = textWidth + titleGlowReach * 2,
            .height = static_cast<double>(glow.height),
        };
    }

    Box buttonGlowBox(const Box& face, const Margins& margins) noexcept {
        return {
            .x      = face.x - margins.left,
            .y      = face.y - margins.top,
            .width  = face.width + margins.left + margins.right,
            .height = face.height + margins.top + margins.bottom,
        };
    }

    std::array<Slice, 9> nineSlice(double sourceWidth, double sourceHeight, const Margins& margins, const Box& target) noexcept {
        std::array<Slice, 9> slices = {};
        if (sourceWidth <= 0 || sourceHeight <= 0 || target.width <= 0 || target.height <= 0) {
            return slices;
        }

        // Margins that do not fit the target shrink together, so a small target still shows both sides
        const double across = margins.left + margins.right;
        const double down   = margins.top + margins.bottom;
        const double scaleX = across > target.width ? target.width / across : 1;
        const double scaleY = down > target.height ? target.height / down : 1;

        const std::array<double, 3> sourceX = {0, static_cast<double>(margins.left), sourceWidth - margins.right};
        const std::array<double, 3> sourceW = {static_cast<double>(margins.left), sourceWidth - margins.left - margins.right,
                                               static_cast<double>(margins.right)};
        const std::array<double, 3> sourceY = {0, static_cast<double>(margins.top), sourceHeight - margins.bottom};
        const std::array<double, 3> sourceH = {static_cast<double>(margins.top), sourceHeight - margins.top - margins.bottom,
                                               static_cast<double>(margins.bottom)};

        const double                left    = margins.left * scaleX;
        const double                right   = margins.right * scaleX;
        const double                top     = margins.top * scaleY;
        const double                bottom  = margins.bottom * scaleY;
        const std::array<double, 3> targetX = {target.x, target.x + left, target.x + target.width - right};
        const std::array<double, 3> targetW = {left, target.width - left - right, right};
        const std::array<double, 3> targetY = {target.y, target.y + top, target.y + target.height - bottom};
        const std::array<double, 3> targetH = {top, target.height - top - bottom, bottom};

        for (std::size_t row = 0; row < 3; row++) {
            for (std::size_t column = 0; column < 3; column++) {
                const bool empty = sourceW.at(column) <= 0 || sourceH.at(row) <= 0 || targetW.at(column) <= 0 || targetH.at(row) <= 0;
                if (empty) {
                    continue;
                }

                slices.at(row * 3 + column) = {
                    .source = {.x = sourceX.at(column), .y = sourceY.at(row), .width = sourceW.at(column), .height = sourceH.at(row)},
                    .target = {.x = targetX.at(column), .y = targetY.at(row), .width = targetW.at(column), .height = targetH.at(row)},
                };
            }
        }

        return slices;
    }

}
