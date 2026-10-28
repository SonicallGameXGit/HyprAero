#include "host/frames.hpp"

#include <hyprland/protocols/wlr-layer-shell-unstable-v1.hpp>
#include <hyprland/src/config/shared/actions/ConfigActions.hpp>
#include <hyprland/src/desktop/Workspace.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/state/ViewHitTester.hpp>
#include <hyprland/src/desktop/state/ViewState.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/devices/IKeyboard.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/layout/algorithm/Algorithm.hpp>
// It has no include guard: included here only
#include <hyprland/src/layout/algorithm/tiled/dwindle/DwindleAlgorithm.hpp>
#include <hyprland/src/layout/space/Space.hpp>
#include <hyprland/src/layout/target/Target.hpp>
#include <hyprland/src/managers/KeybindManager.hpp>
#include <hyprland/src/managers/SeatManager.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/pointer/cursor/CursorShapeOverrideController.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/decorations/DecorationPositioner.hpp>
#include <hyprland/src/state/MonitorState.hpp>

#include <linux/input-event-codes.h>

#include <algorithm>
#include <array>
#include <cstdlib>
#include <format>
#include <variant>
#include <vector>

#include "core/command.hpp"
#include "core/fade.hpp"
#include "core/moving.hpp"
#include "core/status.hpp"
#include "core/tiling.hpp"
#include "host/frame.hpp"
#include "host/state.hpp"

namespace frames::host {

    namespace {

        constexpr std::string_view pluginVersion = FRAMES_VERSION;

        // The modifiers a keybind holds; Caps Lock and Num Lock are locks, not held, and Hyprland's binds ignore them too
        constexpr uint32_t heldModifiers = static_cast<uint32_t>(HL_MODIFIER_SHIFT) | static_cast<uint32_t>(HL_MODIFIER_CTRL) |
                                           static_cast<uint32_t>(HL_MODIFIER_ALT) | static_cast<uint32_t>(HL_MODIFIER_META);

        // Frames Hyprland has deleted (their windows closed) are dropped from the list
        void prune() {
            std::erase_if(state->frames, [](const WP<Frame>& frame) { return frame.expired(); });
        }

        WP<Frame> frameOf(const PHLWINDOW& window) {
            for (const WP<Frame>& frame : state->frames) {
                if (!frame.expired() && frame->belongsTo(window)) {
                    return frame;
                }
            }

            return {};
        }

        void addFrame(const PHLWINDOW& window) {
            if (window == nullptr || !validMapped(window) || window->isHidden()) {
                return;
            }

            // A window that asked for no frame at all (X11 menus, tooltips, splash screens)
            if (window->m_X11DoesntWantBorders || window->isX11OverrideRedirect()) {
                return;
            }

            prune();
            if (!frameOf(window).expired()) {
                return;
            }

            UP<Frame>       frame = makeUnique<Frame>(window, state->load);
            const WP<Frame> weak  = frame;
            if (HyprlandAPI::addWindowDecoration(state->handle, window, std::move(frame))) {
                state->frames.push_back(weak);
            }
        }

        void forEachFrame(const auto& action) {
            prune();
            for (const WP<Frame>& frame : state->frames) {
                if (!frame.expired()) {
                    action(*frame.get());
                }
            }
        }

        void readScale() {
            // Read from Hyprland's own environment, which its config's `env` sets; nothing else is read
            const char* const text  = std::getenv("QT_SCALE_FACTOR"); // NOLINT(concurrency-mt-unsafe): Hyprland's one thread
            double            scale = 1;
            if (text != nullptr) {
                const auto parsed = scaleFromText(text);
                if (parsed.has_value()) {
                    scale = *parsed;
                } else {
                    logLine(Log::WARN,
                            std::format("QT_SCALE_FACTOR is not a number from {} to {}; the frames keep their own size", smallestScale, largestScale));
                }
            }

            state->scale = scale;
        }

        Point pointOf(const Vector2D& vector) {
            return {.x = vector.x, .y = vector.y};
        }

        Box boxOf(const CBox& box) {
            return {.x = box.x, .y = box.y, .width = box.w, .height = box.h};
        }

        Layout::eRectCorner cornerOf(const Edges& edges) {
            unsigned corner = Layout::CORNER_NONE;
            if (edges.top) {
                corner |= Layout::CORNER_TOP;
            }

            if (edges.bottom) {
                corner |= Layout::CORNER_BOTTOM;
            }

            if (edges.left) {
                corner |= Layout::CORNER_LEFT;
            }

            if (edges.right) {
                corner |= Layout::CORNER_RIGHT;
            }

            return static_cast<Layout::eRectCorner>(corner);
        }

        // The cursor over an edge that resizes, through Hyprland's own override for window edges
        void showCursor(std::string_view shape) {
            if (state->cursor == shape) {
                return;
            }

            state->cursor = shape;
            if (shape.empty()) {
                ::Pointer::Cursor::overrideController->unsetOverride(::Pointer::Cursor::CURSOR_OVERRIDE_WINDOW_EDGE);
                return;
            }

            ::Pointer::Cursor::overrideController->setOverride(std::string(shape), ::Pointer::Cursor::CURSOR_OVERRIDE_WINDOW_EDGE);
        }

        // Whether a drag of Hyprland's (a keybind's, an app's, ours) is going on: the pointer is its until it ends
        bool hyprlandDragging() {
            return g_layoutManager->dragController()->target() != nullptr;
        }

        PHLMONITOR screenAt(const Vector2D& point) {
            return ::State::monitorState()->query().vec(point).run();
        }

        // The workspace a screen shows: its special workspace while that is open over it
        PHLWORKSPACE shownWorkspace(const PHLMONITOR& screen) {
            if (screen == nullptr) {
                return nullptr;
            }

            return screen->m_activeSpecialWorkspace != nullptr ? screen->m_activeSpecialWorkspace : screen->m_activeWorkspace;
        }

        // Hyprland's dwindle layout, whose `preselect` and resizing by a side the drops and the lines are made for, with
        // nothing fullscreen or maximized over it
        bool dwindleLaysOut(const PHLWORKSPACE& workspace) {
            if (workspace == nullptr || workspace->m_space == nullptr || Fullscreen::controller()->hasFullscreen(workspace)) {
                return false;
            }

            const SP<Layout::CAlgorithm> algorithm = workspace->m_space->algorithm();
            if (algorithm == nullptr || algorithm->tiledAlgo().get() == nullptr) {
                return false;
            }

            return dynamic_cast<const Layout::Tiled::CDwindleAlgorithm*>(algorithm->tiledAlgo().get()) != nullptr;
        }

        // The windows a workspace's layout places, and the rooms it gives them
        struct Tiled {
            std::vector<Tile>         tiles   = {};
            std::vector<PHLWINDOWREF> windows = {};
        };

        Tiled tilesOf(const PHLWORKSPACE& workspace) {
            Tiled tiled = {};
            if (workspace == nullptr || workspace->m_space == nullptr) {
                return tiled;
            }

            for (const WP<Layout::ITarget>& weak : workspace->m_space->targets()) {
                const SP<Layout::ITarget> target = weak.lock();
                const PHLWINDOW           window = target == nullptr || target->floating() ? nullptr : target->window();
                if (window == nullptr || !validMapped(window) || window->isHidden()) {
                    continue;
                }

                tiled.tiles.push_back({
                    .node  = boxOf(target->position()),
                    .frame = boxOf(window->getWindowBoxUnified(Desktop::View::RESERVED_EXTENTS)),
                    .grips = !target->isPseudo(),
                });
                tiled.windows.push_back(window);
            }

            return tiled;
        }

        // The sides that resize a window: all of a floating one; in the layout, those it shares with another window
        Edges resizableSides(const PHLWINDOW& window) {
            const WindowFacts facts = Frame::factsOf(window);
            if (window == nullptr || !resizable(facts.placement, facts.fixed)) {
                return {};
            }

            if (facts.placement == Placement::Floating) {
                return allSides;
            }

            const PHLWORKSPACE workspace = window->m_workspace;
            if (workspace == nullptr || Fullscreen::controller()->hasFullscreen(workspace)) {
                return {};
            }

            const Tiled tiled = tilesOf(workspace);
            for (std::size_t index = 0; index < tiled.windows.size(); index++) {
                if (tiled.windows.at(index).lock() == window) {
                    return sharedSides(tiled.tiles, index);
                }
            }

            return {};
        }

        // The lines between windows in the layout under a point, with the windows they are held by
        struct LinesHere {
            Split                   split      = {};
            std::optional<HeldLine> vertical   = std::nullopt;
            std::optional<HeldLine> horizontal = std::nullopt;
        };

        std::optional<LinesHere> linesAt(const Vector2D& point) {
            const bool         smart     = state->smartResizing != nullptr && state->smartResizing->good() && **state->smartResizing;
            const PHLWORKSPACE workspace = shownWorkspace(screenAt(point));
            if (!smart || !dwindleLaysOut(workspace)) {
                return std::nullopt;
            }

            const Tiled tiled = tilesOf(workspace);
            const Split split = splitAt(tiled.tiles, pointOf(point), frameExtents(currentTokens(), state->scale).border);
            if (!split.vertical.has_value() && !split.horizontal.has_value()) {
                return std::nullopt;
            }

            const auto hold = [&](const SplitLine& line, bool vertical) {
                return HeldLine{
                    .window   = tiled.windows.at(line.tile),
                    .vertical = vertical,
                    .after    = line.after,
                    .offset   = (vertical ? point.x : point.y) - line.at,
                };
            };

            LinesHere here = {.split = split};
            if (split.vertical.has_value()) {
                here.vertical = hold(*split.vertical, true);
            }

            if (split.horizontal.has_value()) {
                here.horizontal = hold(*split.horizontal, false);
            }

            return here;
        }

        struct Target {
            WP<Frame> frame = {};
            Part      part  = Part::Outside;
            // The sides that resize its window
            Edges sides = {};
            // Something stands over the point: a popup holding the pointer, a layer surface, a window without a frame
            bool covered = false;
        };

        // A layer surface above the windows (a bar's menu, a notification) at a point
        bool layerAt(const Desktop::CViewHitTester& tester, const Vector2D& point) {
            const PHLMONITOR monitor = screenAt(point);
            if (monitor == nullptr) {
                return false;
            }

            for (const auto layer : {ZWLR_LAYER_SHELL_V1_LAYER_TOP, ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY}) {
                Vector2D local = {};
                PHLLS    found = nullptr;
                tester.layerSurfaceAt(point, &monitor->m_layerSurfaceLayers.at(layer), &local, &found);
                if (found != nullptr) {
                    return true;
                }
            }

            return false;
        }

        // The frame and its part under a point of the screen, if nothing stands over it
        Target targetAt(const Vector2D& point) {
            // A menu or another popup holds the pointer: it is theirs until it closes
            if (g_pSeatManager->m_seatGrab != nullptr) {
                return {.covered = true};
            }

            // Windows with their frames and the room they reserve around them, floating ones too
            constexpr auto searched =
                static_cast<uint16_t>(static_cast<unsigned>(Desktop::View::RESERVED_EXTENTS) | static_cast<unsigned>(Desktop::View::INPUT_EXTENTS) |
                                      static_cast<unsigned>(Desktop::View::ALLOW_FLOATING));
            const Desktop::CViewHitTester tester{*Desktop::viewState()};
            const PHLWINDOW               window = tester.windowAt(point, searched);
            if (window == nullptr) {
                return {.covered = layerAt(tester, point)};
            }

            const WP<Frame> frame = frameOf(window);
            if (frame.expired()) {
                return {.covered = true};
            }

            const Edges sides = resizableSides(window);
            const Part  part  = frame->partAt(point, sides);
            if (part == Part::Outside || part == Part::Client) {
                return {.frame = frame, .part = part, .sides = sides};
            }

            // A layer surface above the windows comes before the frame
            if (layerAt(tester, point)) {
                return {.covered = true};
            }

            return {.frame = frame, .part = part, .sides = sides};
        }

        // Lines are held in the gaps between windows in the layout and on those windows' edges, under nothing else
        bool linesReachable(const Target& target) {
            if (target.covered) {
                return false;
            }

            if (target.frame.expired()) {
                return true;
            }

            const PHLWINDOW window = target.frame->window();
            return window != nullptr && !window->m_isFloating && (target.part == Part::Edge || target.part == Part::Outside);
        }

        // The cursor over a point: both arrows over a line, a resize cursor over an edge that resizes, else none
        std::string_view cursorAt(const Target& target, const Vector2D& point) {
            if (hyprlandDragging()) {
                return "";
            }

            if (linesReachable(target)) {
                const auto here = linesAt(point);
                if (here.has_value()) {
                    return splitCursor(here->split);
                }
            }

            if (target.frame.expired() || target.part != Part::Edge) {
                return "";
            }

            return resizeCursor(commonSides(target.frame->edgesAt(point), target.sides));
        }

        // As on Windows, a press on a frame activates its window
        void activate(const PHLWINDOW& window) {
            if (Desktop::focusState()->window() != window) {
                Desktop::focusState()->fullWindowFocus(window, Desktop::FOCUS_REASON_CLICK);
            }

            if (window->m_isFloating) {
                Desktop::windowState()->raise(window);
            }
        }

        void damageArea(const Box& area) {
            g_pHyprRenderer->damageBox(CBox{area.x, area.y, area.width, area.height});
        }

        void logFailure(const Config::Actions::ActionResult& result, std::string_view what, const PHLWINDOW& window) {
            if (!result.has_value()) {
                logLine(Log::WARN, std::format("could not {} a window of class {}", what, plainText(window->m_class, maxClassLength)));
            }
        }

        // The preview shown goes, fading out from wherever its fade is
        void hidePreview() {
            if (!state->preview.has_value()) {
                return;
            }

            const double now     = nowMs();
            Preview      leaving = *state->preview;
            state->preview.reset();
            leaving.fade = fadeFrom(opacityAt(leaving.fade, now, fadeTime()), false, now);

            // One fading out at a time: an older one goes at once
            if (state->leaving.has_value()) {
                damageArea(state->leaving->area);
            }

            state->leaving = leaving;
            damageArea(leaving.area);
        }

        void showPreview(const WP<Frame>& drawer, const PHLMONITOR& screen, const Box& area) {
            hidePreview();
            state->preview = Preview{.drawer = drawer, .screen = screen, .area = area, .fade = fadeFrom(0, true, nowMs())};
            damageArea(area);
        }

        // While a preview fades, each frame of its screen draws it again, as Hyprland's own animations damage what they
        // move before each frame
        void fadePreviews(const PHLMONITOR& monitor) {
            const double now  = nowMs();
            const double time = fadeTime();
            if (state->leaving.has_value() && (state->leaving->drawer.expired() || settled(state->leaving->fade, now, time))) {
                damageArea(state->leaving->area);
                state->leaving.reset();
            }

            // The moved window closed
            if (state->preview.has_value() && state->preview->drawer.expired()) {
                damageArea(state->preview->area);
                state->preview.reset();
            }

            for (const std::optional<Preview>& preview : {state->preview, state->leaving}) {
                if (preview.has_value() && preview->screen.lock() == monitor && !settled(preview->fade, now, time)) {
                    damageArea(preview->area);
                }
            }
        }

        bool sameDrop(const Drop& first, const Drop& second) {
            return first.kind == second.kind && first.side == second.side && first.window.lock() == second.window.lock() &&
                   first.screen.lock() == second.screen.lock() && first.beside.lock() == second.beside.lock();
        }

        void clearDrop() {
            state->drop.reset();
            hidePreview();
        }

        // Dwindle's own drop puts a window beside the tiled one under the pointer, on the focused screen's workspace
        bool besideDropsIn(const PHLWORKSPACE& workspace) {
            return dwindleLaysOut(workspace) && shownWorkspace(Desktop::focusState()->monitor()) == workspace;
        }

        // Where letting go of a moved window at a point would put it. `besideOnly`: a window Hyprland took out of the
        // layout to move, which Hyprland itself puts back where it is let go of, so the top of the screen means nothing.
        std::optional<Drop> dropAt(const PHLWINDOW& window, const Vector2D& point, bool besideOnly) {
            if (window == nullptr || !validMapped(window) || Frame::factsOf(window).fixed) {
                return std::nullopt;
            }

            const PHLMONITOR screen = screenAt(point);
            if (screen == nullptr) {
                return std::nullopt;
            }

            if (!besideOnly && atSnapEdge(pointOf(point), boxOf(screen->logicalBox()), state->scale)) {
                return Drop{.window = window, .kind = DropKind::Layout, .screen = screen, .area = boxOf(screen->logicalBoxMinusReserved())};
            }

            const PHLWORKSPACE workspace = shownWorkspace(screen);
            if (!besideDropsIn(workspace)) {
                return std::nullopt;
            }

            for (const WP<Layout::ITarget>& weak : workspace->m_space->targets()) {
                const SP<Layout::ITarget> target = weak.lock();
                const PHLWINDOW           tiled  = target == nullptr || target->floating() ? nullptr : target->window();
                if (tiled == nullptr || tiled == window || !validMapped(tiled) || tiled->isHidden()) {
                    continue;
                }

                // Measured on the window as it shows, the side it takes from its room, where the layout will put it
                const Box box = boxOf(tiled->getWindowBoxUnified(Desktop::View::RESERVED_EXTENTS));
                if (!contains(box, point.x, point.y)) {
                    continue;
                }

                const std::optional<Side> side = dropSideAt(box, pointOf(point), state->scale);
                if (!side.has_value()) {
                    return std::nullopt;
                }

                return Drop{
                    .window = window,
                    .kind   = DropKind::Beside,
                    .screen = screen,
                    .beside = tiled,
                    .side   = *side,
                    .area   = dropArea(boxOf(target->position()), *side),
                };
            }

            return std::nullopt;
        }

        // While a window is moved: where letting go would put it, shown by its preview
        void followDrop(const PHLWINDOW& window, const Vector2D& point, bool besideOnly) {
            const std::optional<Drop> found = dropAt(window, point, besideOnly);
            if (!found.has_value()) {
                clearDrop();
                return;
            }

            const bool same = state->drop.has_value() && sameDrop(*state->drop, *found);
            state->drop     = found;
            if (!same || !state->preview.has_value()) {
                showPreview(frameOf(window), found->screen.lock(), found->area);
                return;
            }

            // The same place, perhaps grown or shrunk with the layout: it moves with it, without fading again
            const Box& shown = state->preview->area;
            if (shown.x != found->area.x || shown.y != found->area.y || shown.width != found->area.width || shown.height != found->area.height) {
                damageArea(shown);
                state->preview->area = found->area;
                damageArea(found->area);
            }
        }

        void layoutMessage(const PHLWORKSPACE& workspace, std::string_view message) {
            // The workspace's own layout, as Hyprland's `layoutmsg` dispatcher sends it to the focused one's
            if (!workspace->m_space->layoutMsg(message).has_value()) {
                logLine(Log::WARN, std::format("the layout did not take `{}`", message));
            }
        }

        // Puts a window let go of where its drop says, once the drag that moved it has ended, through Hyprland's own
        // `togglefloating`, which places it beside the tiled window under the pointer
        void dropWindow(const PHLWINDOW& window, const Drop& drop) {
            if (window == nullptr || !validMapped(window) || !window->m_isFloating || drop.window.lock() != window) {
                return;
            }

            if (drop.kind == DropKind::Layout) {
                logFailure(Config::Actions::floatWindow(Config::Actions::TOGGLE_ACTION_DISABLE, window), "tile", window);
                return;
            }

            const PHLWINDOW    beside    = drop.beside.lock();
            const PHLWORKSPACE workspace = window->m_workspace;
            if (beside == nullptr || beside->m_workspace != workspace || !besideDropsIn(workspace)) {
                return;
            }

            // Dwindle's preselect says on which side; taken back after, should the window not have gone in
            layoutMessage(workspace, preselectFor(drop.side));
            logFailure(Config::Actions::floatWindow(Config::Actions::TOGGLE_ACTION_DISABLE, window), "tile", window);
            layoutMessage(workspace, preselectNone);
        }

        // Ends a drag of Hyprland's only when it is the one this grab began, never someone else's
        void endOurDrag(const Grab& grab) {
            const SP<Layout::ITarget> dragged = grab.dragged.lock();
            if (grab.dragging && dragged != nullptr && g_layoutManager->dragController()->target() == dragged) {
                g_layoutManager->endDragTarget();
            }
        }

        void dropGrab() {
            state->grab.reset();
            clearDrop();
        }

        // The pointer went far enough from a press on the caption: the window moves from here, out of the layout first
        void startMove(Grab& grab, const Vector2D& point) {
            // A press that moved the window is no first half of a double click
            state->lastClick.reset();

            const PHLWINDOW window = grab.frame.expired() ? nullptr : grab.frame->window();
            if (window == nullptr || !validMapped(window) || hyprlandDragging()) {
                dropGrab();
                return;
            }

            const WindowFacts facts = Frame::factsOf(window);
            if (facts.placement == Placement::Maximized) {
                logFailure(Config::Actions::fullscreenWindow(Fullscreen::FSMODE_MAXIMIZED, true, window), "restore", window);
            }

            if (!window->m_isFloating) {
                logFailure(Config::Actions::floatWindow(Config::Actions::TOGGLE_ACTION_ENABLE, window), "float", window);
            }

            // Out of the layout the window takes its floating size, under the pointer where it held the caption
            if (facts.placement != Placement::Floating && window->m_isFloating) {
                const Vector2D size  = window->size(Desktop::View::IGeometric::GEOMETRIC_GOAL);
                const Point    place = placeUnderPointer(grab.outer, pointOf(grab.start), pointOf(point), {.width = size.x, .height = size.y},
                                                         frameExtents(currentTokens(), state->scale));
                logFailure(Config::Actions::move({place.x, place.y}, false, window), "move", window);
            }

            const SP<Layout::ITarget> target = window->layoutTarget();
            if (target == nullptr || !window->m_isFloating) {
                dropGrab();
                return;
            }

            g_layoutManager->beginDragTarget(target, MBIND_MOVE);
            if (g_layoutManager->dragController()->target() != target) {
                dropGrab();
                return;
            }

            grab.dragging = true;
            grab.dragged  = target;
        }

        // Moves a held line to the pointer through the layout's own resize by a side, as Hyprland's drag does; false
        // when its window has left the layout
        bool moveLine(const HeldLine& line, const Vector2D& point) {
            const PHLWINDOW           window = line.window.lock();
            const SP<Layout::ITarget> target = window == nullptr || !validMapped(window) ? nullptr : window->layoutTarget();
            if (target == nullptr || target->floating() || target->space() == nullptr) {
                return false;
            }

            const double pointer = line.vertical ? point.x : point.y;
            const auto   shift   = lineShift(lineOf(boxOf(target->position()), line.vertical, line.after), pointer, line.offset);
            if (!shift.has_value()) {
                return true;
            }

            const Edges side = line.vertical ? Edges{.left = !line.after, .right = line.after} : Edges{.top = !line.after, .bottom = line.after};
            g_layoutManager->resizeTarget(line.vertical ? Vector2D{*shift, 0.0} : Vector2D{0.0, *shift}, target, cornerOf(side));
            return true;
        }

        // As Hyprland's own drag, the windows take their new places at once instead of sliding there
        void placeAtOnce(const HeldLine& line) {
            const PHLWINDOW           window = line.window.lock();
            const SP<Layout::ITarget> held   = window == nullptr ? nullptr : window->layoutTarget();
            if (held == nullptr || held->space() == nullptr) {
                return;
            }

            const std::vector<WP<Layout::ITarget>> targets = held->space()->targets();
            for (const WP<Layout::ITarget>& weak : targets) {
                const SP<Layout::ITarget> target = weak.lock();
                if (target != nullptr && !target->floating()) {
                    target->warpPositionSize();
                }
            }
        }

        void moveLines(const Grab& grab, const Vector2D& point) {
            const bool vertical   = !grab.vertical.has_value() || moveLine(*grab.vertical, point);
            const bool horizontal = vertical && (!grab.horizontal.has_value() || moveLine(*grab.horizontal, point));
            if (!vertical || !horizontal) {
                dropGrab();
                return;
            }

            const std::optional<HeldLine>& held = grab.vertical.has_value() ? grab.vertical : grab.horizontal;
            if (held.has_value()) {
                placeAtOnce(*held);
            }
        }

        // While the caption is held: the move starts past the threshold, then where letting go puts the window is shown.
        // While a line is held, it follows the pointer.
        // `grab` is state->grab's; once dropGrab() ran it is gone and nothing touches it again
        void followGrab(Grab& grab, const Vector2D& point) {
            if (grab.kind == GrabKind::Split) {
                moveLines(grab, point);
                return;
            }

            if (grab.frame.expired()) {
                dropGrab();
                return;
            }

            if (grab.kind == GrabKind::Resize) {
                return;
            }

            if (!grab.dragging) {
                if (pastThreshold(pointOf(grab.start), pointOf(point), dragThreshold(grab.placement, state->scale))) {
                    startMove(grab, point);
                }

                return;
            }

            // Hyprland ended the drag itself (the window closed, a fullscreen window took the workspace)
            const SP<Layout::ITarget> dragged = grab.dragged.lock();
            if (dragged == nullptr || g_layoutManager->dragController()->target() != dragged) {
                dropGrab();
                return;
            }

            followDrop(grab.frame->window(), point, false);
        }

        // Hyprland's own move of a window (a keybind's, `bindm = SUPER, mouse:272, movewindow`): where letting go
        // would put it, by the pointer as for a move by the caption
        void followHyprlandDrag(const Vector2D& point) {
            const auto&               drag    = g_layoutManager->dragController();
            const SP<Layout::ITarget> dragged = drag->target();
            const PHLWINDOW           window  = dragged == nullptr || drag->mode() != MBIND_MOVE ? nullptr : dragged->window();
            if (window == nullptr || !window->m_isFloating) {
                if (state->drop.has_value()) {
                    clearDrop();
                }

                return;
            }

            followDrop(window, point, drag->draggingTiled());
        }

        // Any button ends Hyprland's own move: CKeybindManager::ensureMouseBindState, the first thing Hyprland does with
        // every button. It is ended here the same way, through the same function, so the drop can follow it; the button
        // then goes on to Hyprland, which finds no drag left.
        // `drop` is a copy: clearDrop() lets go of state->drop
        void finishHyprlandDrag(const Drop& drop) {
            clearDrop();

            const auto&               drag    = g_layoutManager->dragController();
            const SP<Layout::ITarget> dragged = drag->target();
            const PHLWINDOW           window  = drop.window.lock();
            if (dragged == nullptr || window == nullptr || dragged->window() != window || drag->mode() != MBIND_MOVE) {
                return;
            }

            // A window Hyprland took out of the layout goes back by Hyprland's own drop when its drag ends, beside the
            // window under the pointer; only the side is the frames'
            if (!drag->draggingTiled()) {
                CKeybindManager::changeMouseBindMode(MBIND_INVALID);
                dropWindow(window, drop);
                return;
            }

            const PHLWINDOW    beside    = drop.beside.lock();
            const PHLWORKSPACE workspace = window->m_workspace;
            if (drop.kind != DropKind::Beside || beside == nullptr || beside->m_workspace != workspace || !besideDropsIn(workspace)) {
                return;
            }

            layoutMessage(workspace, preselectFor(drop.side));
            CKeybindManager::changeMouseBindMode(MBIND_INVALID);
            layoutMessage(workspace, preselectNone);
        }

        void pointerMoved(const Vector2D& point) {
            prune();
            if (state->grab.has_value()) {
                followGrab(*state->grab, point);
                return;
            }

            followHyprlandDrag(point);

            const Target target = targetAt(point);

            // While a button is held, only its frame follows the pointer
            if (!state->holding.expired()) {
                state->holding->pointerMoved(target.frame.get() == state->holding.get() ? buttonAt(target.part) : Button::None);
                return;
            }

            if (!state->underPointer.expired() && state->underPointer.get() != target.frame.get()) {
                state->underPointer->pointerLeft();
            }

            state->underPointer = target.frame;
            showCursor(cursorAt(target, point));
            if (target.frame.expired()) {
                return;
            }

            // A Maximize that cannot be clicked does not light up
            const WindowFacts facts = Frame::factsOf(target.frame->window());
            const bool        dead  = target.part == Part::Maximize && !canToggle(facts.placement, facts.fixed);
            target.frame->pointerMoved(dead ? Button::None : buttonAt(target.part));
        }

        void toggle(const PHLWINDOW& window) {
            const WindowFacts facts = Frame::factsOf(window);
            if (!canToggle(facts.placement, facts.fixed)) {
                return;
            }

            // Through the same actions as Hyprland's own dispatchers (`togglefloating`, `fullscreen 1`)
            switch (toggleFor(facts.placement)) {
            case Toggle::Float:
                logFailure(Config::Actions::floatWindow(Config::Actions::TOGGLE_ACTION_ENABLE, window), "float", window);
                return;
            case Toggle::Tile:
                logFailure(Config::Actions::floatWindow(Config::Actions::TOGGLE_ACTION_DISABLE, window), "tile", window);
                return;
            case Toggle::Unmaximize:
                break;
            }

            logFailure(Config::Actions::fullscreenWindow(Fullscreen::FSMODE_MAXIMIZED, true, window), "restore", window);
        }

        void pressed(const IPointer::SButtonEvent& event, Event::SCallbackInfo& info) {
            // Only two presses in a row make a double click
            const std::optional<LastClick> previous = state->lastClick;
            state->lastClick.reset();

            // A drag of Hyprland's is going on, or a keybind's press (`bindm = SUPER, mouse:272, movewindow`): theirs
            if (hyprlandDragging() || (g_pInputManager->getModsFromAllKBs() & heldModifiers) != 0) {
                return;
            }

            const Vector2D point  = g_pInputManager->getMouseCoordsInternal();
            const Target   target = targetAt(point);

            // A line between windows in the layout: it moves both, neither the app nor Hyprland sees the press
            if (linesReachable(target)) {
                const auto here = linesAt(point);
                if (here.has_value()) {
                    info.cancelled = true;
                    state->grab    = Grab{.kind = GrabKind::Split, .start = point, .vertical = here->vertical, .horizontal = here->horizontal};
                    showCursor(splitCursor(here->split));
                    return;
                }
            }

            if (target.frame.expired() || target.part == Part::Outside || target.part == Part::Client) {
                return;
            }

            const PHLWINDOW window = target.frame->window();
            if (window == nullptr) {
                return;
            }

            // The frame is ours: neither the app nor Hyprland's resize_on_border sees the press
            info.cancelled = true;
            activate(window);

            const WindowFacts facts = Frame::factsOf(window);
            if (target.part == Part::Maximize || target.part == Part::Close) {
                const bool dead = target.part == Part::Maximize && !canToggle(facts.placement, facts.fixed);
                if (!dead && target.frame->pointerPressed(buttonAt(target.part))) {
                    state->holding = target.frame;
                }

                return;
            }

            const auto outer = target.frame->outerNow();
            if (!outer.has_value()) {
                return;
            }

            if (target.part == Part::Caption) {
                // As on Windows, the second press of a double click on the caption maximizes or restores
                const Click click = {.timeMs = event.timeMs, .point = pointOf(point)};
                if (previous.has_value() && previous->frame.get() == target.frame.get() && doubleClick(previous->click, click, state->scale)) {
                    state->ownRelease = true;
                    toggle(window);
                    return;
                }

                state->lastClick = LastClick{.frame = target.frame, .click = click};
                state->grab      = Grab{.frame = target.frame, .kind = GrabKind::Move, .start = point, .outer = *outer, .placement = facts.placement};
                return;
            }

            // An edge: Hyprland resizes, by the sides this point means that can move, as Windows does (not by the nearest
            // corner)
            const Layout::eRectCorner corner = cornerOf(commonSides(target.frame->edgesAt(point), target.sides));
            const SP<Layout::ITarget> layout = window->layoutTarget();
            if (corner == Layout::CORNER_NONE || layout == nullptr) {
                return;
            }

            g_layoutManager->beginDragTarget(layout, MBIND_RESIZE, corner);
            if (g_layoutManager->dragController()->target() == layout) {
                state->grab = Grab{
                    .frame     = target.frame,
                    .kind      = GrabKind::Resize,
                    .start     = point,
                    .outer     = *outer,
                    .placement = facts.placement,
                    .dragging  = true,
                    .dragged   = layout,
                };
            }
        }

        // `grab` is a copy: dropGrab() lets go of state->grab, and of the drop
        void releasedGrab(const Grab& grab) {
            const std::optional<Drop> drop = state->drop;
            dropGrab();
            endOurDrag(grab);

            const PHLWINDOW window = grab.frame.expired() ? nullptr : grab.frame->window();
            if (grab.kind == GrabKind::Move && drop.has_value()) {
                dropWindow(window, *drop);
            }
        }

        void released(Event::SCallbackInfo& info) {
            // The second press of a double click was the frame's, so its release is too
            if (state->ownRelease) {
                state->ownRelease = false;
                info.cancelled    = true;
                return;
            }

            // The press was the frame's, so the release is too: the app never saw either
            if (state->grab.has_value()) {
                info.cancelled  = true;
                const Grab grab = *state->grab;
                releasedGrab(grab);
                return;
            }

            if (state->holding.expired()) {
                return;
            }

            info.cancelled         = true;
            const WP<Frame> holder = state->holding;
            state->holding         = {};

            const Target    target = targetAt(g_pInputManager->getMouseCoordsInternal());
            const Button    act    = holder->pointerReleased(target.frame.get() == holder.get() ? buttonAt(target.part) : Button::None);
            const PHLWINDOW window = holder->window();
            if (window == nullptr || act == Button::None) {
                return;
            }

            if (act == Button::Close) {
                // As Hyprland's `killactive`: asks the app to close
                logFailure(Config::Actions::closeWindow(window), "close", window);
                return;
            }

            toggle(window);
        }

        void button(const IPointer::SButtonEvent& event, Event::SCallbackInfo& info) {
            // A drop shown while Hyprland moves a window follows the end of that move; the button goes on to Hyprland
            if (!state->grab.has_value() && state->drop.has_value()) {
                if (hyprlandDragging()) {
                    const Drop drop = *state->drop;
                    finishHyprlandDrag(drop);
                    return;
                }

                clearDrop();
            }

            if (event.button != BTN_LEFT) {
                return;
            }

            if (event.state == WL_POINTER_BUTTON_STATE_PRESSED) {
                pressed(event, info);
            } else {
                released(info);
            }
        }

        // The classes of the framed windows that have no icon yet
        std::vector<std::string> missingClasses() {
            std::vector<std::string> classes = {};
            forEachFrame([&](const Frame& frame) {
                const PHLWINDOW window = frame.window();
                if (window == nullptr || window->m_class.empty() || window->m_class.size() > maxClassLength) {
                    return;
                }

                if (findIcon(state->icons, window->m_class, 16).empty() && std::ranges::find(classes, window->m_class) == classes.end()) {
                    classes.push_back(window->m_class);
                }
            });

            return classes;
        }

        std::string answer(const Request& request, bool json) {
            if (std::holds_alternative<StatusRequest>(request)) {
                return statusText(state->safety, pluginVersion, json);
            }

            if (const auto* bad = std::get_if<BadRequest>(&request)) {
                return std::format("error: {}\n", bad->reason);
            }

            if (state->safety.off) {
                return "error: off since an error, `hyprctl hypraero-frames` says why\n";
            }

            if (const auto* theme = std::get_if<ThemeRequest>(&request)) {
                if (state->theme != theme->theme) {
                    state->theme = theme->theme;
                    forEachFrame([](Frame& frame) { frame.lookChanged(); });
                }

                return "ok\n";
            }

            if (const auto* icon = std::get_if<IconRequest>(&request)) {
                if (!keepIcon(state->icons, icon->className, icon->size, premultiply(icon->rgba))) {
                    return "error: no room for more icons\n";
                }

                forEachFrame([&](Frame& frame) {
                    const PHLWINDOW window = frame.window();
                    if (window != nullptr && window->m_class == icon->className) {
                        frame.damageEntire();
                    }
                });
                return "ok\n";
            }

            return missingText(state->theme, missingClasses());
        }

        // Ends a move or resize the frames began and gives the cursor back: at unload, and at the first pointer event
        // after the safety switch turned the plugin off, as Hyprland ends its own drags in its input, never while drawing.
        // Returns whether a press was the frames', so its release is not passed on.
        bool letGoOfPointer() noexcept {
            bool ours = false;
            runAlways("letting go of the pointer", [&] {
                ours = state->grab.has_value() || !state->holding.expired() || state->ownRelease;
                if (state->grab.has_value()) {
                    const Grab grab = *state->grab;
                    dropGrab();
                    endOurDrag(grab);
                }

                showCursor("");
                clearDrop();
                state->holding    = {};
                state->ownRelease = false;
                state->lastClick.reset();
            });

            return ours;
        }

        // A change to one window's frame, if it has one
        void withFrame(const PHLWINDOW& window, const auto& action) {
            const WP<Frame> frame = frameOf(window);
            if (!frame.expired()) {
                action(*frame.get());
            }
        }

    }

    void startFrames() {
        state->blurEnabled       = std::make_unique<CConfigValue<Config::BOOL>>("decoration:blur:enabled");
        state->smartResizing     = std::make_unique<CConfigValue<Config::BOOL>>("dwindle:smart_resizing");
        state->animationsEnabled = std::make_unique<CConfigValue<Config::BOOL>>("animations:enabled");
        readScale();

        const std::size_t failed = decodePictures(state->pictures);
        if (failed > 0) {
            logLine(Log::WARN, std::format("{} of Windows 7's pictures could not be read; they are left out", failed));
        }

        auto& events = Event::bus()->m_events;
        state->listeners.push_back(events.window.open.listen([](const PHLWINDOW& window) { run("window opened", [&] { addFrame(window); }); }));
        state->listeners.push_back(events.window.title.listen(
            [](const PHLWINDOW& window) { run("title changed", [&] { withFrame(window, [](Frame& frame) { frame.titleChanged(); }); }); }));
        state->listeners.push_back(events.window.active.listen([](const PHLWINDOW& /* window */, Desktop::eFocusReason /* reason */) {
            // The window that was active and the one that is now both change their look. An app may have changed its
            // mind about its title bar meanwhile; Hyprland says nothing when it does, so it is looked at here.
            run("window activated", [] {
                forEachFrame([](Frame& frame) {
                    frame.refresh();
                    frame.damageEntire();
                });
            });
        }));
        state->listeners.push_back(events.window.updateRules.listen(
            // The `decorate` rule may have turned the frame on or off
            [](const PHLWINDOW& window) { run("window rules", [&] { withFrame(window, [](Frame& frame) { frame.refresh(); }); }); }));
        state->listeners.push_back(events.window.fullscreen.listen(
            // Maximize turns into Restore and back
            [](const PHLWINDOW& window) { run("window maximized", [&] { withFrame(window, [](Frame& frame) { frame.lookChanged(); }); }); }));
        state->listeners.push_back(events.window.floating.listen(
            // In or out of the layout, by the frame's button, a keybind or anything else: Restore or Maximize, square or round
            [](const PHLWINDOW& window) { run("window floating", [&] { withFrame(window, [](Frame& frame) { frame.lookChanged(); }); }); }));
        state->listeners.push_back(events.config.reloaded.listen([] {
            // The config's `env` may have changed QT_SCALE_FACTOR
            run("config reloaded", [] {
                readScale();
                forEachFrame([](Frame& frame) { frame.refresh(); });
            });
        }));
        state->listeners.push_back(events.input.mouse.move.listen([](Vector2D point, Event::SCallbackInfo& /* info */) {
            if (!run("pointer moved", [&] { pointerMoved(point); })) {
                letGoOfPointer();
            }
        }));
        state->listeners.push_back(events.input.mouse.button.listen([](IPointer::SButtonEvent event, Event::SCallbackInfo& info) {
            if (!run("pointer button", [&] { button(event, info); }) && letGoOfPointer() && event.state == WL_POINTER_BUTTON_STATE_RELEASED) {
                info.cancelled = true;
            }
        }));

        state->listeners.push_back(
            // Before each frame of a screen, as Hyprland's own animations do: a fading preview is drawn again
            events.render.preChecks.listen([](PHLMONITOR monitor) { run("preview fade", [&] { fadePreviews(monitor); }); }));

        for (const PHLWINDOW& window : Desktop::windowState()->windows()) {
            addFrame(window);
        }
    }

    void stopFrames() noexcept {
        letGoOfPointer();
        runAlways("unload", [] {
            state->listeners.clear();
            forEachFrame([](Frame& frame) { frame.forgetTextures(); });
            state->frames.clear();
            state->underPointer = {};
            state->holding      = {};
            state->preview.reset();
            state->leaving.reset();
        });
    }

    std::string answerRequest(eHyprCtlOutputFormat format, const std::string& request) noexcept {
        std::string reply = "";
        const bool  ran   = runAlways("hyprctl command", [&] { reply = answer(parseRequest(request), format == FORMAT_JSON); });
        if (!ran || reply.empty()) {
            return "hypraero-frames: no answer, see Hyprland's log\n";
        }

        return reply;
    }

}
