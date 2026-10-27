#include "core/layout.hpp"

#include <charconv>
#include <cmath>

namespace frames {

    namespace {

        // Larger than any screen; a size past it is a bug or a lie, not a window
        constexpr double largest = 100000;

        // How much of a drawing may stand past its room and still count as fitting: Hyprland's sizes are fractions
        constexpr double fitSlack = 0.5;

        // The button's face, and above it up to the frame's top edge, as on Windows: the pointer thrown at the top
        // of the screen still hits it
        Box hitBox(const Box& face) {
            return {.x = face.x, .y = 0, .width = face.width, .height = face.y + face.height};
        }

        bool usable(double size) {
            return std::isfinite(size) && size > 0 && size <= largest;
        }

        bool finite(const Box& box) {
            return std::isfinite(box.x) && std::isfinite(box.y) && std::isfinite(box.width) && std::isfinite(box.height);
        }

        Box pieceBox(Piece piece, double x, double y, double scale) {
            const PieceInfo& info = pieceInfo(piece);
            return {.x = x, .y = y, .width = info.width * scale, .height = info.height * scale};
        }

    }

    bool contains(const Box& box, double x, double y) noexcept {
        return x >= box.x && x < box.x + box.width && y >= box.y && y < box.y + box.height;
    }

    double usableScale(double scale) noexcept {
        if (!std::isfinite(scale) || scale < smallestScale || scale > largestScale) {
            return 1;
        }

        return scale;
    }

    std::optional<double> scaleFromText(std::string_view text) noexcept {
        double     scale  = 0;
        const auto parsed = std::from_chars(text.data(), text.data() + text.size(), scale, std::chars_format::fixed);
        if (parsed.ec != std::errc{} || parsed.ptr != text.data() + text.size()) {
            return std::nullopt;
        }

        if (!std::isfinite(scale) || scale < smallestScale || scale > largestScale) {
            return std::nullopt;
        }

        return scale;
    }

    Extents frameExtents(const Tokens& tokens, double scale) noexcept {
        const double usable = usableScale(scale);
        return {.border = std::round(tokens.frameBorder * usable), .caption = std::round(tokens.frameCaption * usable)};
    }

    std::optional<FrameLayout> layoutFrame(double outerWidth, double outerHeight, const Tokens& tokens, double scale) noexcept {
        if (!usable(outerWidth) || !usable(outerHeight)) {
            return std::nullopt;
        }

        const double  pixel   = usableScale(scale);
        const Extents extents = frameExtents(tokens, pixel);
        const double  border  = extents.border;
        const double  caption = extents.caption;
        if (border < 2 || caption < border || outerWidth <= border * 2 || outerHeight <= caption + border) {
            return std::nullopt;
        }

        FrameLayout layout = {};
        layout.outer       = {.x = 0, .y = 0, .width = outerWidth, .height = outerHeight};
        layout.client      = {.x = border, .y = caption, .width = outerWidth - border * 2, .height = outerHeight - caption - border};
        layout.extents     = extents;
        layout.scale       = pixel;
        layout.strips      = {{
            {.x = 0, .y = 0, .width = outerWidth, .height = caption},
            {.x = 0, .y = caption, .width = border, .height = layout.client.height},
            {.x = outerWidth - border, .y = caption, .width = border, .height = layout.client.height},
            {.x = 0, .y = outerHeight - border, .width = outerWidth, .height = border},
        }};

        const double top      = tokens.frameButtonsTop * pixel;
        const double closeX   = outerWidth - tokens.frameButtonsRight * pixel - pieceInfo(Piece::FaceCloseRest).width * pixel;
        layout.close          = pieceBox(Piece::FaceCloseRest, closeX, top, pixel);
        const double maximize = closeX - pieceInfo(Piece::FaceMaximizeRest).width * pixel;
        layout.maximize       = pieceBox(Piece::FaceMaximizeRest, maximize, top, pixel);
        layout.showButtons    = layout.maximize.x >= border;

        // The icon and the words sit in the middle of the caption's height
        const double right = layout.showButtons ? layout.maximize.x : outerWidth - border;
        const double size  = tokens.frameIconSize * pixel;
        const double gap   = tokens.frameTitleGap * pixel;
        layout.icon        = {.x = tokens.frameIconLeft * pixel, .y = std::floor((caption - size) / 2), .width = size, .height = size};
        layout.showIcon    = size > 0 && layout.icon.x + size <= right;

        const double titleLeft = layout.icon.x + size + gap;
        layout.title           = {.x = titleLeft, .y = 0, .width = right - gap - titleLeft, .height = caption};
        layout.showTitle       = layout.showIcon && layout.title.width >= 1;

        return layout;
    }

    Part partAt(const FrameLayout& layout, double x, double y, bool resizable) noexcept {
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

        if (y >= layout.client.y) {
            return Part::Edge;
        }

        // Along the caption the frame's outermost band resizes, as the sides do below it
        const double band   = layout.extents.border;
        const bool   onEdge = y < band || x < band || x >= layout.outer.width - band;
        if (resizable && onEdge) {
            return Part::Edge;
        }

        return Part::Caption;
    }

    Edges edgesAt(const FrameLayout& layout, double x, double y) noexcept {
        const double band  = layout.extents.border;
        const double reach = band * 2;
        const double width = layout.outer.width;
        const double high  = layout.outer.height;

        Edges edges = {.top = y < band, .bottom = y >= high - band, .left = x < band, .right = x >= width - band};

        // A corner reaches a little along both its sides, so it is not a single pixel to aim at
        if (edges.top || edges.bottom) {
            edges.left  = edges.left || x < reach;
            edges.right = edges.right || x >= width - reach;
        }

        if (edges.left || edges.right) {
            edges.top    = edges.top || y < reach;
            edges.bottom = edges.bottom || y >= high - reach;
        }

        // A window so small that both sides are in reach resizes by the top-left ones
        if (edges.left && edges.right) {
            edges.right = false;
        }

        if (edges.top && edges.bottom) {
            edges.bottom = false;
        }

        return edges;
    }

    Box fitToSurface(const Box& outer, const Box& window, const Box& surface) noexcept {
        if (!finite(outer) || !finite(window) || !finite(surface) || surface.width <= 0 || surface.height <= 0) {
            return outer;
        }

        const bool inside = surface.x >= window.x - fitSlack && surface.y >= window.y - fitSlack &&
                            surface.x + surface.width <= window.x + window.width + fitSlack &&
                            surface.y + surface.height <= window.y + window.height + fitSlack;
        if (!inside) {
            return outer;
        }

        return {
            .x      = outer.x + (surface.x - window.x),
            .y      = outer.y + (surface.y - window.y),
            .width  = outer.width - (window.width - surface.width),
            .height = outer.height - (window.height - surface.height),
        };
    }

    Box glyphBox(const Box& face, double glyphWidth, double glyphHeight, double pixel) noexcept {
        const double unit = usableScale(pixel);
        return {
            .x      = face.x + std::floor((face.width - glyphWidth + unit) / 2 / unit) * unit,
            .y      = face.y + std::floor((face.height - unit - glyphHeight) / 2 / unit) * unit,
            .width  = glyphWidth,
            .height = glyphHeight,
        };
    }

    Box buttonGlowBox(const Box& face, const Margins& margins, double scale) noexcept {
        const double unit = usableScale(scale);
        return {
            .x      = face.x - margins.left * unit,
            .y      = face.y - margins.top * unit,
            .width  = face.width + (margins.left + margins.right) * unit,
            .height = face.height + (margins.top + margins.bottom) * unit,
        };
    }

    std::array<Slice, 9> nineSlice(double sourceWidth, double sourceHeight, const Margins& margins, const Box& target, double scale) noexcept {
        std::array<Slice, 9> slices = {};
        if (sourceWidth <= 0 || sourceHeight <= 0 || target.width <= 0 || target.height <= 0) {
            return slices;
        }

        const double unit = usableScale(scale);

        // Margins that do not fit the target shrink together, so a small target still shows both sides
        const double across = (margins.left + margins.right) * unit;
        const double down   = (margins.top + margins.bottom) * unit;
        const double scaleX = across > target.width ? target.width / across : 1;
        const double scaleY = down > target.height ? target.height / down : 1;

        const std::array<double, 3> sourceX = {0, static_cast<double>(margins.left), sourceWidth - margins.right};
        const std::array<double, 3> sourceW = {static_cast<double>(margins.left), sourceWidth - margins.left - margins.right,
                                               static_cast<double>(margins.right)};
        const std::array<double, 3> sourceY = {0, static_cast<double>(margins.top), sourceHeight - margins.bottom};
        const std::array<double, 3> sourceH = {static_cast<double>(margins.top), sourceHeight - margins.top - margins.bottom,
                                               static_cast<double>(margins.bottom)};

        const double                left    = margins.left * unit * scaleX;
        const double                right   = margins.right * unit * scaleX;
        const double                top     = margins.top * unit * scaleY;
        const double                bottom  = margins.bottom * unit * scaleY;
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
