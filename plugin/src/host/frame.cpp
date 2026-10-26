#include "host/frame.hpp"

#include <hyprland/src/desktop/Workspace.hpp>
#include <hyprland/src/desktop/rule/windowRule/WindowRuleApplicator.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/decorations/DecorationPositioner.hpp>
#include <hyprland/src/render/pass/BorderPassElement.hpp>
#include <hyprland/src/render/pass/RectPassElement.hpp>
#include <hyprland/src/render/pass/TexPassElement.hpp>

#include <algorithm>
#include <array>
#include <cmath>
#include <utility>

#include "core/text.hpp"
#include "host/state.hpp"

namespace frames::host {

    namespace {

        constexpr std::string_view displayName = "hypraero-frames";
        // A frame of an earlier load, still on a window Hyprland has not let go of yet
        constexpr std::string_view staleName = "hypraero-frames (unloaded)";

        constexpr uint32_t allEdges = static_cast<uint32_t>(DECORATION_EDGE_TOP) | static_cast<uint32_t>(DECORATION_EDGE_BOTTOM) |
                                      static_cast<uint32_t>(DECORATION_EDGE_LEFT) | static_cast<uint32_t>(DECORATION_EDGE_RIGHT);
        // Hyprland's own border is 10000: the frame goes around it, never between it and the window
        constexpr uint32_t framePriority = 9000;

        // A monitor's scale past this is not a real one; nothing is drawn rather than huge pictures made
        constexpr double largestScale = 10;
        constexpr int    textWeight   = 400;

        CHyprColor colorOf(const Color& color, float alpha) {
            return {color.red, color.green, color.blue, color.alpha * alpha};
        }

        Box inset(const Box& box, double by) {
            return {.x = box.x + by, .y = box.y + by, .width = box.width - by * 2, .height = box.height - by * 2};
        }

        void addTexture(const SP<Render::ITexture>& texture, const CBox& box, float alpha, const CBox& clip) {
            if (texture == nullptr || box.w <= 0 || box.h <= 0) {
                return;
            }

            CTexPassElement::SRenderData data;
            data.tex     = texture;
            data.box     = box;
            data.a       = alpha;
            data.clipBox = clip;
            g_pHyprRenderer->addPassElement(makeUnique<CTexPassElement>(data));
        }

    }

    Frame::Frame(const PHLWINDOW& window, std::uint64_t loadNumber) : IHyprWindowDecoration(window), owner(window), load(loadNumber) {
        ;
    }

    bool Frame::mine() const {
        return state != nullptr && state->load == load;
    }

    PHLWINDOW Frame::window() const {
        return owner.lock();
    }

    bool Frame::belongsTo(const PHLWINDOW& window) const {
        return window != nullptr && owner.lock() == window;
    }

    bool Frame::wantsFrame(const PHLWINDOW& window) const {
        if (window == nullptr || !validMapped(window) || window->m_X11DoesntWantBorders || window->m_ruleApplicator == nullptr) {
            return false;
        }

        // Hyprland's `decorate` window rule turns the frame off for an app
        return window->m_ruleApplicator->decorate().valueOrDefault();
    }

    CBox Frame::outerBox(const PHLWINDOW& window) const {
        CBox box = assigned;
        box.translate(g_pDecorationPositioner->getEdgeDefinedPoint(allEdges, owner));

        // While a workspace slides in or out, its windows are drawn moved by this much
        const PHLWORKSPACE workspace = window->m_workspace;
        if (workspace != nullptr && !window->m_pinned) {
            box.translate(workspace->m_renderOffset->value());
        }

        return box;
    }

    SDecorationPositioningInfo Frame::getPositioningInfo() noexcept {
        SDecorationPositioningInfo info;
        run("frame positioning", [&] {
            const PHLWINDOW window = owner.lock();
            if (!mine() || !wantsFrame(window)) {
                return;
            }

            const Tokens& tokens = currentTokens();
            info.policy          = DECORATION_POSITION_STICKY;
            info.edges           = allEdges;
            info.priority        = framePriority;
            info.reserved        = true;
            info.desiredExtents  = {{static_cast<double>(tokens.frameBorder), static_cast<double>(tokens.frameCaption)},
                                    {static_cast<double>(tokens.frameBorder), static_cast<double>(tokens.frameBorder)}};
        });

        return info;
    }

    void Frame::onPositioningReply(const SDecorationPositioningReply& reply) noexcept {
        run("frame positioning reply", [&] { assigned = reply.assignedGeometry; });
    }

    void Frame::draw(PHLMONITOR monitor, float const& alpha) noexcept {
        run("frame draw", [&] {
            if (mine()) {
                drawFrame(monitor, alpha);
            }
        });
    }

    void Frame::drawFrame(const PHLMONITOR& monitor, float alpha) {
        const PHLWINDOW window = owner.lock();
        if (!wantsFrame(window) || monitor == nullptr) {
            return;
        }

        const double scale = monitor->m_scale;
        if (!std::isfinite(scale) || scale <= 0 || scale > largestScale) {
            return;
        }

        const Tokens& tokens = currentTokens();
        const CBox    outer  = outerBox(window);
        const auto    layout = layoutFrame(outer.w, outer.h, tokens);
        if (!layout.has_value()) {
            return;
        }

        const Vector2D origin = outer.pos() - monitor->m_position + window->m_floatingOffset;
        const auto     device = [&](const Box& box) {
            CBox placed = {origin.x + box.x, origin.y + box.y, box.width, box.height};
            placed.scale(scale).round();
            return placed;
        };

        const bool active    = Desktop::focusState()->window() == window;
        const CBox frameClip = device(layout->outer);

        // The glass: four strips around the window, never under it, so a see-through window keeps its own look
        const bool blur = state->blurEnabled != nullptr && state->blurEnabled->good() && **state->blurEnabled;
        for (const Box& strip : layout->strips) {
            CRectPassElement::SRectData glass;
            glass.box     = frameClip;
            glass.color   = colorOf(active ? tokens.frameGlassTint : tokens.frameGlassTintInactive, alpha);
            glass.round   = static_cast<int>(std::round(tokens.frameRadius * scale));
            glass.blur    = blur;
            glass.blurA   = alpha;
            glass.clipBox = device(strip);
            g_pHyprRenderer->addPassElement(makeUnique<CRectPassElement>(glass));
        }

        // Windows 7's streaks over the glass, moving with the window
        const PieceInfo& streaks = pieceInfo(Piece::Reflection);
        for (const Box& strip : layout->strips) {
            addTexture(pictureTexture(state->pictures, Piece::Reflection),
                       device({.x = 0, .y = 0, .width = static_cast<double>(streaks.width), .height = static_cast<double>(streaks.height)}), alpha,
                       device(strip));
        }

        // The lines: the dark outer edge and the light one inside it, then the light and the dark one around the window
        const double radius = tokens.frameRadius;
        const auto   line   = [&](const Box& inside, const Color& color, double round, double outerRound) {
            CBorderPassElement::SBorderData data;
            data.box        = device(inside);
            data.grad1      = Config::CGradientValueData(colorOf(color, 1));
            data.round      = static_cast<int>(std::round(std::max(round, 0.0) * scale));
            data.outerRound = static_cast<int>(std::round(std::max(outerRound, 0.0) * scale));
            data.borderSize = 1;
            data.a          = alpha;
            data.window     = owner;
            if (data.box.w > 0 && data.box.h > 0) {
                g_pHyprRenderer->addPassElement(makeUnique<CBorderPassElement>(data));
            }
        };
        line(inset(layout->outer, 1), active ? tokens.frameEdgeOuter : tokens.frameEdgeOuterInactive, radius - 1, radius);
        line(inset(layout->outer, 2), active ? tokens.frameEdgeInner : tokens.frameEdgeInnerInactive, radius - 2, radius - 1);
        line(inset(layout->client, -1), tokens.frameClientEdgeLight, 0, 0);
        line(layout->client, tokens.frameClientEdgeDark, 0, 0);

        if (layout->showIcon) {
            addTexture(iconFor(window, scale), device(layout->icon), alpha, frameClip);
        }

        if (layout->showTitle) {
            const CBox                 titleBox = device(layout->title);
            const SP<Render::ITexture> text     = titleFor(window, scale, static_cast<int>(titleBox.w));
            if (text != nullptr && text->m_size.x > 0) {
                if (tokens.frameTitleGlow > 0) {
                    const PieceInfo& glow  = pieceInfo(Piece::GlowTitle);
                    const auto       parts = nineSlice(glow.width, glow.height, glow.margins, titleGlowBox(*layout, text->m_size.x / scale));
                    for (std::size_t index = 0; index < parts.size(); index++) {
                        if (parts.at(index).target.width > 0) {
                            addTexture(sliceTexture(state->pictures, Piece::GlowTitle, index), device(parts.at(index).target), alpha * tokens.frameTitleGlow,
                                       frameClip);
                        }
                    }
                }

                const CBox textBox = {titleBox.x, std::round(titleBox.y + (titleBox.h - text->m_size.y) / 2), text->m_size.x, text->m_size.y};
                addTexture(text, textBox, alpha, frameClip);
            }
        }

        if (!layout->showButtons) {
            return;
        }

        const bool                                  maximized = Fullscreen::controller()->getFullscreenModes(window).internal == Fullscreen::FSMODE_MAXIMIZED;
        const std::array<std::pair<Button, Box>, 2> buttons   = {{
            {Button::Maximize, layout->maximize},
            {Button::Close, layout->close},
        }};

        // Glows first, so the face of the button beside one covers the part of its glow that reaches over it
        for (const auto& [button, face] : buttons) {
            if (!glows(lookOf(pointer, button, active))) {
                continue;
            }

            const Piece      piece = glowPiece(button);
            const PieceInfo& glow  = pieceInfo(piece);
            const auto       parts = nineSlice(glow.width, glow.height, glow.margins, buttonGlowBox(face, glow.margins));
            for (std::size_t index = 0; index < parts.size(); index++) {
                if (parts.at(index).target.width > 0) {
                    addTexture(sliceTexture(state->pictures, piece, index), device(parts.at(index).target), alpha, frameClip);
                }
            }
        }

        for (const auto& [button, face] : buttons) {
            addTexture(pictureTexture(state->pictures, facePiece(button, lookOf(pointer, button, active))), device(face), alpha, frameClip);
        }

        for (const auto& [button, face] : buttons) {
            const Piece      piece = glyphPiece(button, lookOf(pointer, button, active), maximized);
            const PieceInfo& glyph = pieceInfo(piece);
            addTexture(pictureTexture(state->pictures, piece), device(glyphBox(face, glyph.width, glyph.height)), alpha, frameClip);
        }
    }

    SP<Render::ITexture> Frame::iconFor(const PHLWINDOW& window, double scale) {
        // The 32 pixel picture on a monitor that draws a 16 pixel icon larger, as Windows does above 100%
        const int wanted = scale > 1 ? 32 : 16;
        if (iconTexture != nullptr && iconChanges == state->icons.changes && iconSize == wanted) {
            return iconTexture;
        }

        iconChanges = state->icons.changes;
        iconSize    = wanted;

        auto pixels = findIcon(state->icons, window->m_class, wanted);
        int  size   = wanted;
        if (pixels.empty() && wanted == 32) {
            pixels = findIcon(state->icons, window->m_class, 16);
            size   = 16;
        }

        iconTexture = pixels.empty() ? nullptr : makeIconTexture(pixels, size);
        if (iconTexture == nullptr) {
            iconTexture = pictureTexture(state->pictures, wanted == 32 ? Piece::Application32 : Piece::Application16);
        }

        return iconTexture;
    }

    SP<Render::ITexture> Frame::titleFor(const PHLWINDOW& window, double scale, int maxWidth) {
        const bool same = !titleDirty && titleScale == scale && titleWidth == maxWidth && titleTheme == state->theme;
        if (same) {
            return titleTexture;
        }

        // Made only when something it depends on changed, never every frame (AGENTS.md section 5.1)
        titleDirty   = false;
        titleScale   = scale;
        titleWidth   = maxWidth;
        titleTheme   = state->theme;
        titleTexture = nullptr;

        const std::string text = cleanTitle(window->m_title);
        if (text.empty() || maxWidth < 1) {
            return nullptr;
        }

        const Tokens& tokens = currentTokens();
        const int     size   = static_cast<int>(std::round(tokens.fontSizeSmall * scale));
        titleTexture = g_pHyprRenderer->renderText(text, colorOf(tokens.frameTitleText, 1), size, false, std::string(tokens.fontUi), maxWidth, textWeight);
        return titleTexture;
    }

    eDecorationType Frame::getDecorationType() noexcept {
        return DECORATION_CUSTOM;
    }

    void Frame::updateWindow(PHLWINDOW /* window */) noexcept {
        damageEntire();
    }

    void Frame::damageEntire() noexcept {
        run("frame damage", [&] {
            const PHLWINDOW window = owner.lock();
            if (!mine() || window == nullptr || !validMapped(window)) {
                return;
            }

            const CBox outer  = outerBox(window);
            const auto layout = layoutFrame(outer.w, outer.h, currentTokens());
            if (!layout.has_value()) {
                return;
            }

            for (const Box& strip : layout->strips) {
                g_pHyprRenderer->damageBox(CBox{outer.x + strip.x, outer.y + strip.y, strip.width, strip.height});
            }
        });
    }

    void Frame::damageCaption() {
        const PHLWINDOW window = owner.lock();
        if (window == nullptr || !validMapped(window)) {
            return;
        }

        const CBox outer = outerBox(window);
        g_pHyprRenderer->damageBox(CBox{outer.x, outer.y, outer.w, static_cast<double>(currentTokens().frameCaption)});
    }

    bool Frame::onInputOnDeco(eInputType /* type */, const Vector2D& /* coords */, std::any /* data */) noexcept {
        // The pointer is followed through Hyprland's input events instead (host/frames.cpp): those also come when it
        // leaves the frame or is let go of elsewhere
        return false;
    }

    eDecorationLayer Frame::getDecorationLayer() noexcept {
        return DECORATION_LAYER_UNDER;
    }

    uint64_t Frame::getDecorationFlags() noexcept {
        // Part of the window, so Hyprland's shadow goes around the whole frame
        return DECORATION_PART_OF_MAIN_WINDOW;
    }

    std::string Frame::getDisplayName() noexcept {
        try {
            return std::string(mine() ? displayName : staleName);
        } catch (...) {
            return {};
        }
    }

    Part Frame::partAt(const Vector2D& point) const {
        const PHLWINDOW window = owner.lock();
        if (!wantsFrame(window)) {
            return Part::Outside;
        }

        const CBox outer  = outerBox(window);
        const auto layout = layoutFrame(outer.w, outer.h, currentTokens());
        if (!layout.has_value()) {
            return Part::Outside;
        }

        return frames::partAt(*layout, point.x - outer.x, point.y - outer.y);
    }

    void Frame::pointerMoved(Button at) {
        if (movePointer(pointer, at)) {
            damageCaption();
        }
    }

    bool Frame::pointerPressed(Button at) {
        const bool taken = pressPointer(pointer, at);
        damageCaption();
        return taken;
    }

    Button Frame::pointerReleased(Button at) {
        const Button act = releasePointer(pointer, at);
        damageCaption();
        return act;
    }

    void Frame::pointerLeft() {
        if (leavePointer(pointer)) {
            damageCaption();
        }
    }

    bool Frame::holding() const {
        return pointer.pressed != Button::None;
    }

    void Frame::titleChanged() {
        titleDirty = true;
        damageCaption();
    }

    void Frame::lookChanged() {
        titleDirty = true;
        damageEntire();
    }

    void Frame::forgetTextures() {
        titleTexture = nullptr;
        iconTexture  = nullptr;
    }

}
