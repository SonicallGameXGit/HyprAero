#include "host/frame.hpp"

#include <hyprland/src/desktop/Workspace.hpp>
#include <hyprland/src/desktop/rule/windowRule/WindowRuleApplicator.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/view/WLSurface.hpp>
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
#include "host/titleBars.hpp"

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
        constexpr double largestMonitorScale = 10;
        constexpr int    textWeight          = 400;

        CHyprColor colorOf(const Color& color, float alpha) {
            return {color.red, color.green, color.blue, color.alpha * alpha};
        }

        Box inset(const Box& box, double by) {
            return {.x = box.x + by, .y = box.y + by, .width = box.width - by * 2, .height = box.height - by * 2};
        }

        Box boxOf(const CBox& box) {
            return {.x = box.x, .y = box.y, .width = box.w, .height = box.h};
        }

        CBox cboxOf(const Box& box) {
            return {box.x, box.y, box.width, box.height};
        }

        std::optional<Size> sizeOf(const std::optional<Vector2D>& size) {
            if (!size.has_value()) {
                return std::nullopt;
            }

            return Size{.width = size->x, .height = size->y};
        }

        // Where Hyprland draws what the app drew inside the window's room, as its renderer places it
        // (CSurfacePassElement::getTexBox): a drawing smaller than the room is moved into it and kept at its size
        std::optional<Box> drawnBox(const PHLWINDOW& window, const CBox& room) {
            const auto surface = window->wlSurface();
            if (surface == nullptr || surface->resource() == nullptr) {
                return std::nullopt;
            }

            if (!surface->small() || surface->m_fillIgnoreSmall) {
                return boxOf(room);
            }

            const Vector2D correction = surface->correctSmallVec();
            const Vector2D size       = surface->getViewporterCorrectedSize();
            const Vector2D reported   = window->getReportedSize();
            if (reported.x <= 0 || reported.y <= 0) {
                return std::nullopt;
            }

            return Box{
                .x      = room.x + correction.x,
                .y      = room.y + correction.y,
                .width  = size.x * (room.w / reported.x),
                .height = size.y * (room.h / reported.y),
            };
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

        // A 1 pixel line just outside `box` (logical, as Hyprland's border draws it), on a box already on the device
        void addLine(const CBox& box, const Color& color, double round, double outerRound, double scale, float alpha, const PHLWINDOWREF& window) {
            if (box.w <= 0 || box.h <= 0) {
                return;
            }

            CBorderPassElement::SBorderData data;
            data.box        = box;
            data.grad1      = Config::CGradientValueData(colorOf(color, 1));
            data.round      = static_cast<int>(std::round(std::max(round, 0.0) * scale));
            data.outerRound = static_cast<int>(std::round(std::max(outerRound, 0.0) * scale));
            data.borderSize = 1;
            data.a          = alpha;
            data.window     = window;
            g_pHyprRenderer->addPassElement(makeUnique<CBorderPassElement>(data));
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

    WindowFacts Frame::factsOf(const PHLWINDOW& window) {
        if (window == nullptr) {
            return {};
        }

        const bool maximized = Fullscreen::controller()->getFullscreenModes(window).internal == Fullscreen::FSMODE_MAXIMIZED;
        return {
            .placement = placementOf(window->m_isFloating, maximized),
            .fixed     = fixedSize(sizeOf(window->minSize()), sizeOf(window->maxSize())),
        };
    }

    bool Frame::framed(const PHLWINDOW& window) const {
        if (window == nullptr || !validMapped(window) || window->m_X11DoesntWantBorders || window->m_ruleApplicator == nullptr) {
            return false;
        }

        // An app that draws its own title bar (Chromium and Electron apps, GTK, Firefox) gets no second one
        if (!window->m_isX11 && !wantsServerFrame(decorationRequestOf(window))) {
            return false;
        }

        // Hyprland's `decorate` window rule turns the frame off for an app
        return window->m_ruleApplicator->decorate().valueOrDefault();
    }

    std::optional<Box> Frame::outerBox(const PHLWINDOW& window) const {
        CBox box = assigned;
        box.translate(g_pDecorationPositioner->getEdgeDefinedPoint(allEdges, owner));

        // Around what the app drew, which can be less than the room Hyprland gave its window
        const CBox room  = window->getWindowMainSurfaceBox();
        const auto drawn = drawnBox(window, room);
        Box        outer = boxOf(box);
        if (drawn.has_value()) {
            outer = fitToSurface(outer, boxOf(room), *drawn);
        }

        // While a workspace slides in or out, its windows are drawn moved by this much
        const PHLWORKSPACE workspace = window->m_workspace;
        if (workspace != nullptr && !window->m_pinned) {
            const Vector2D offset = workspace->m_renderOffset->value();
            outer.x += offset.x;
            outer.y += offset.y;
        }

        return outer;
    }

    std::optional<Box> Frame::outerNow() const {
        const PHLWINDOW window = owner.lock();
        if (!framed(window)) {
            return std::nullopt;
        }

        return outerBox(window);
    }

    std::optional<FrameLayout> Frame::layoutNow() const {
        const auto outer = outerNow();
        if (!outer.has_value()) {
            return std::nullopt;
        }

        return layoutFrame(outer->width, outer->height, currentTokens(), state->scale);
    }

    SDecorationPositioningInfo Frame::getPositioningInfo() noexcept {
        SDecorationPositioningInfo info;
        run("frame positioning", [&] {
            const PHLWINDOW window = owner.lock();
            reserved               = mine() && framed(window);
            reservedScale          = mine() ? state->scale : 0;
            if (!reserved) {
                return;
            }

            const Extents extents = frameExtents(currentTokens(), state->scale);
            info.policy           = DECORATION_POSITION_STICKY;
            info.edges            = allEdges;
            info.priority         = framePriority;
            info.reserved         = true;
            info.desiredExtents   = {{extents.border, extents.caption}, {extents.border, extents.border}};
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
        if (!framed(window) || monitor == nullptr) {
            return;
        }

        const double monitorScale = monitor->m_scale;
        if (!std::isfinite(monitorScale) || monitorScale <= 0 || monitorScale > largestMonitorScale) {
            return;
        }

        const Tokens& tokens = currentTokens();
        const auto    outer  = outerBox(window);
        if (!outer.has_value()) {
            return;
        }

        // The frame follows its app's drawing: when that shrank, what the frame covered before is drawn again
        const bool moved = !drawnOuter.has_value() || drawnOuter->x != outer->x || drawnOuter->y != outer->y || drawnOuter->width != outer->width ||
                           drawnOuter->height != outer->height;
        if (moved) {
            if (drawnOuter.has_value()) {
                g_pHyprRenderer->damageBox(cboxOf(*drawnOuter));
            }

            drawnOuter = outer;
        }

        drawSnapMarker(monitor, alpha, tokens);

        const auto layout = layoutFrame(outer->width, outer->height, tokens, state->scale);
        if (!layout.has_value()) {
            return;
        }

        const double   scale  = layout->scale;
        const Vector2D origin = Vector2D{outer->x, outer->y} - monitor->m_position + window->m_floatingOffset;
        const auto     device = [&](const Box& box) {
            CBox placed = {origin.x + box.x, origin.y + box.y, box.width, box.height};
            placed.scale(monitorScale).round();
            return placed;
        };

        const WindowFacts facts     = factsOf(window);
        const bool        active    = Desktop::focusState()->window() == window;
        const CBox        frameClip = device(layout->outer);
        const double      radius    = rounded(facts.placement) ? tokens.frameRadius * scale : 0;

        // The glass: four strips around the window, never under it, so a see-through window keeps its own look
        const bool blur = state->blurEnabled != nullptr && state->blurEnabled->good() && **state->blurEnabled;
        for (const Box& strip : layout->strips) {
            CRectPassElement::SRectData glass;
            glass.box     = frameClip;
            glass.color   = colorOf(active ? tokens.frameGlassTint : tokens.frameGlassTintInactive, alpha);
            glass.round   = static_cast<int>(std::round(radius * monitorScale));
            glass.blur    = blur;
            glass.blurA   = alpha;
            glass.clipBox = device(strip);
            g_pHyprRenderer->addPassElement(makeUnique<CRectPassElement>(glass));
        }

        // Windows 7's streaks over the glass, moving with the window
        const PieceInfo& streaks = pieceInfo(Piece::Reflection);
        for (const Box& strip : layout->strips) {
            addTexture(pictureTexture(state->pictures, Piece::Reflection),
                       device({.x = 0, .y = 0, .width = streaks.width * scale, .height = streaks.height * scale}), alpha, device(strip));
        }

        // The lines: the dark outer edge and the light one inside it, then the light and the dark one around the window
        addLine(device(inset(layout->outer, 1)), active ? tokens.frameEdgeOuter : tokens.frameEdgeOuterInactive, radius - 1, radius, monitorScale, alpha,
                owner);
        addLine(device(inset(layout->outer, 2)), active ? tokens.frameEdgeInner : tokens.frameEdgeInnerInactive, radius - 2, radius - 1, monitorScale, alpha,
                owner);
        addLine(device(inset(layout->client, -1)), tokens.frameClientEdgeLight, 0, 0, monitorScale, alpha, owner);
        addLine(device(layout->client), tokens.frameClientEdgeDark, 0, 0, monitorScale, alpha, owner);

        const double pixels = scale * monitorScale;
        if (layout->showIcon) {
            addTexture(iconFor(window, pixels), device(layout->icon), alpha, frameClip);
        }

        if (layout->showTitle) {
            const CBox                 titleBox = device(layout->title);
            const SP<Render::ITexture> text     = titleFor(window, pixels, static_cast<int>(titleBox.w));
            if (text != nullptr && text->m_size.x > 0) {
                const CBox textBox = {titleBox.x, std::round(titleBox.y + (titleBox.h - text->m_size.y) / 2), text->m_size.x, text->m_size.y};
                addTexture(text, textBox, alpha, frameClip);
            }
        }

        if (!layout->showButtons) {
            return;
        }

        const bool                                  restore = showsRestore(facts.placement);
        const bool                                  toggles = canToggle(facts.placement, facts.fixed);
        const std::array<std::pair<Button, Box>, 2> buttons = {{
            {Button::Maximize, layout->maximize},
            {Button::Close, layout->close},
        }};
        const auto                                  enabled = [&](Button button) { return button != Button::Maximize || toggles; };

        // Glows first, so the face of the button beside one covers the part of its glow that reaches over it
        for (const auto& [button, face] : buttons) {
            if (!enabled(button) || !glows(lookOf(pointer, button, active))) {
                continue;
            }

            const Piece      piece = glowPiece(button);
            const PieceInfo& glow  = pieceInfo(piece);
            const auto       parts = nineSlice(glow.width, glow.height, glow.margins, buttonGlowBox(face, glow.margins, scale), scale);
            for (std::size_t index = 0; index < parts.size(); index++) {
                if (parts.at(index).target.width > 0) {
                    addTexture(sliceTexture(state->pictures, piece, index), device(parts.at(index).target), alpha, frameClip);
                }
            }
        }

        for (const auto& [button, face] : buttons) {
            const Look look = enabled(button) ? lookOf(pointer, button, active) : lookOf({}, button, active);
            addTexture(pictureTexture(state->pictures, facePiece(button, look)), device(face), alpha, frameClip);
        }

        for (const auto& [button, face] : buttons) {
            const Piece      piece = glyphPiece(button, lookOf(pointer, button, active), restore, enabled(button));
            const PieceInfo& glyph = pieceInfo(piece);
            addTexture(pictureTexture(state->pictures, piece), device(glyphBox(face, glyph.width * scale, glyph.height * scale, scale)), alpha, frameClip);
        }
    }

    void Frame::drawSnapMarker(const PHLMONITOR& monitor, float alpha, const Tokens& tokens) {
        // Under the window being moved and over everything else, as Windows 7 shows where a window will go
        if (!state->grab.has_value() || state->grab->frame.get() != this) {
            return;
        }

        const PHLMONITOR screen = state->grab->snapScreen.lock();
        if (screen == nullptr || screen != monitor) {
            return;
        }

        const CBox area = screen->logicalBoxMinusReserved();
        if (area.w <= 2 || area.h <= 2) {
            return;
        }

        const double monitorScale = monitor->m_scale;
        const Box    marker       = {.x = area.x - monitor->m_position.x, .y = area.y - monitor->m_position.y, .width = area.w, .height = area.h};
        const auto   device       = [&](const Box& box) {
            CBox placed = cboxOf(box);
            placed.scale(monitorScale).round();
            return placed;
        };

        const double                radius = tokens.frameRadius * usableScale(state->scale);
        const bool                  blur   = state->blurEnabled != nullptr && state->blurEnabled->good() && **state->blurEnabled;
        CRectPassElement::SRectData glass;
        glass.box   = device(marker);
        glass.color = colorOf(tokens.frameGlassTint, alpha);
        glass.round = static_cast<int>(std::round(radius * monitorScale));
        glass.blur  = blur;
        glass.blurA = alpha;
        g_pHyprRenderer->addPassElement(makeUnique<CRectPassElement>(glass));

        addLine(device(inset(marker, 1)), tokens.frameEdgeOuter, radius - 1, radius, monitorScale, alpha, owner);
        addLine(device(inset(marker, 2)), tokens.frameEdgeInner, radius - 2, radius - 1, monitorScale, alpha, owner);
    }

    SP<Render::ITexture> Frame::iconFor(const PHLWINDOW& window, double pixels) {
        // The 32 pixel picture where a 16 pixel icon is drawn larger, as Windows does above 100%
        const int wanted = pixels > 1 ? 32 : 16;
        if (iconTexture != nullptr && iconChanges == state->icons.changes && iconSize == wanted) {
            return iconTexture;
        }

        iconChanges = state->icons.changes;
        iconSize    = wanted;

        auto pixelData = findIcon(state->icons, window->m_class, wanted);
        int  size      = wanted;
        if (pixelData.empty() && wanted == 32) {
            pixelData = findIcon(state->icons, window->m_class, 16);
            size      = 16;
        }

        iconTexture = pixelData.empty() ? nullptr : makeIconTexture(pixelData, size);
        if (iconTexture == nullptr) {
            iconTexture = pictureTexture(state->pictures, wanted == 32 ? Piece::Application32 : Piece::Application16);
        }

        return iconTexture;
    }

    SP<Render::ITexture> Frame::titleFor(const PHLWINDOW& window, double pixels, int maxWidth) {
        const bool same = !titleDirty && titlePixels == pixels && titleWidth == maxWidth && titleTheme == state->theme;
        if (same) {
            return titleTexture;
        }

        // Made only when something it depends on changed, never every frame (AGENTS.md section 5.1)
        titleDirty   = false;
        titlePixels  = pixels;
        titleWidth   = maxWidth;
        titleTheme   = state->theme;
        titleTexture = nullptr;

        const std::string text = cleanTitle(window->m_title);
        if (text.empty() || maxWidth < 1) {
            return nullptr;
        }

        const Tokens& tokens = currentTokens();
        const int     size   = static_cast<int>(std::round(tokens.fontSizeSmall * pixels));
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

            const auto outer = outerBox(window);
            if (!outer.has_value()) {
                return;
            }

            const auto layout = layoutFrame(outer->width, outer->height, currentTokens(), state->scale);
            if (!layout.has_value()) {
                return;
            }

            for (const Box& strip : layout->strips) {
                g_pHyprRenderer->damageBox(CBox{outer->x + strip.x, outer->y + strip.y, strip.width, strip.height});
            }
        });
    }

    void Frame::damageCaption() {
        const PHLWINDOW window = owner.lock();
        if (window == nullptr || !validMapped(window)) {
            return;
        }

        const auto outer = outerBox(window);
        if (!outer.has_value()) {
            return;
        }

        g_pHyprRenderer->damageBox(CBox{outer->x, outer->y, outer->width, frameExtents(currentTokens(), state->scale).caption});
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
        const auto      outer  = outerNow();
        if (window == nullptr || !outer.has_value()) {
            return Part::Outside;
        }

        const auto layout = layoutFrame(outer->width, outer->height, currentTokens(), state->scale);
        if (!layout.has_value()) {
            return Part::Outside;
        }

        const WindowFacts facts = factsOf(window);
        return frames::partAt(*layout, point.x - outer->x, point.y - outer->y, resizable(facts.placement, facts.fixed));
    }

    Edges Frame::edgesAt(const Vector2D& point) const {
        const auto outer = outerNow();
        if (!outer.has_value()) {
            return {};
        }

        const auto layout = layoutFrame(outer->width, outer->height, currentTokens(), state->scale);
        if (!layout.has_value()) {
            return {};
        }

        return frames::edgesAt(*layout, point.x - outer->x, point.y - outer->y);
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

    void Frame::refresh() {
        const PHLWINDOW window = owner.lock();
        if (window == nullptr || !validMapped(window)) {
            return;
        }

        if (framed(window) == reserved && state->scale == reservedScale) {
            return;
        }

        g_pDecorationPositioner->repositionDeco(this);
        window->updateWindowDecos();
        lookChanged();
    }

    void Frame::forgetTextures() {
        titleTexture = nullptr;
        iconTexture  = nullptr;
    }

}
