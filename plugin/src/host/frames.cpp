#include "host/frames.hpp"

#include <hyprland/protocols/wlr-layer-shell-unstable-v1.hpp>
#include <hyprland/src/config/shared/actions/ConfigActions.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/state/ViewHitTester.hpp>
#include <hyprland/src/desktop/state/ViewState.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/devices/IKeyboard.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
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
#include "core/moving.hpp"
#include "core/status.hpp"
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

        bool canResize(const PHLWINDOW& window) {
            const WindowFacts facts = Frame::factsOf(window);
            return window != nullptr && resizable(facts.placement, facts.fixed);
        }

        // Whether a drag of Hyprland's (a keybind's, an app's, ours) is going on: the pointer is its until it ends
        bool hyprlandDragging() {
            return g_layoutManager->dragController()->target() != nullptr;
        }

        struct Target {
            WP<Frame> frame = {};
            Part      part  = Part::Outside;
        };

        // The frame and its part under a point of the screen, if nothing stands over it
        Target targetAt(const Vector2D& point) {
            // A menu or another popup holds the pointer: it is theirs until it closes
            if (g_pSeatManager->m_seatGrab != nullptr) {
                return {};
            }

            // Windows with their frames and the room they reserve around them, floating ones too
            constexpr auto searched =
                static_cast<uint16_t>(static_cast<unsigned>(Desktop::View::RESERVED_EXTENTS) | static_cast<unsigned>(Desktop::View::INPUT_EXTENTS) |
                                      static_cast<unsigned>(Desktop::View::ALLOW_FLOATING));
            const Desktop::CViewHitTester tester{*Desktop::viewState()};
            const PHLWINDOW               window = tester.windowAt(point, searched);
            if (window == nullptr) {
                return {};
            }

            const WP<Frame> frame = frameOf(window);
            if (frame.expired()) {
                return {};
            }

            const Part part = frame->partAt(point);
            if (part == Part::Outside || part == Part::Client) {
                return {.frame = frame, .part = part};
            }

            // A layer surface above the windows (a bar's menu, a notification) comes before the frame
            const PHLMONITOR monitor = window->m_monitor.lock();
            if (monitor != nullptr) {
                for (const auto layer : {ZWLR_LAYER_SHELL_V1_LAYER_TOP, ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY}) {
                    Vector2D local = {};
                    PHLLS    found = nullptr;
                    tester.layerSurfaceAt(point, &monitor->m_layerSurfaceLayers.at(layer), &local, &found);
                    if (found != nullptr) {
                        return {};
                    }
                }
            }

            return {.frame = frame, .part = part};
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

        void damageScreen(const PHLMONITOR& screen) {
            if (screen != nullptr) {
                g_pHyprRenderer->damageBox(screen->logicalBoxMinusReserved());
            }
        }

        void logFailure(const Config::Actions::ActionResult& result, std::string_view what, const PHLWINDOW& window) {
            if (!result.has_value()) {
                logLine(Log::WARN, std::format("could not {} a window of class {}", what, plainText(window->m_class, maxClassLength)));
            }
        }

        // Ends a drag of Hyprland's only when it is the one this grab began, never someone else's
        void endOurDrag(const Grab& grab) {
            const SP<Layout::ITarget> dragged = grab.dragged.lock();
            if (grab.dragging && dragged != nullptr && g_layoutManager->dragController()->target() == dragged) {
                g_layoutManager->endDragTarget();
            }
        }

        void dropGrab() {
            if (!state->grab.has_value()) {
                return;
            }

            damageScreen(state->grab->snapScreen.lock());
            state->grab.reset();
        }

        // The pointer went far enough from a press on the caption: the window moves from here, out of the layout first
        void startMove(Grab& grab, const Vector2D& point) {
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

        // While the caption is held: the move starts past the threshold, then the top of a screen offers the layout
        // `grab` is state->grab's; once dropGrab() ran it is gone and nothing touches it again
        void followGrab(Grab& grab, const Vector2D& point) {
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

            const PHLWINDOW  window = grab.frame->window();
            const PHLMONITOR screen = ::State::monitorState()->query().vec(point).run();
            const bool       snaps  = window != nullptr && screen != nullptr && !Frame::factsOf(window).fixed &&
                                      atSnapEdge(pointOf(point), boxOf(screen->logicalBox()), state->scale);
            const PHLMONITOR before = grab.snapScreen.lock();
            const PHLMONITOR now    = snaps ? screen : nullptr;
            if (before != now) {
                damageScreen(before);
                damageScreen(now);
                grab.snapScreen = now;
            }
        }

        void pointerMoved(const Vector2D& point) {
            prune();
            if (state->grab.has_value()) {
                followGrab(*state->grab, point);
                return;
            }

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
            if (target.frame.expired()) {
                showCursor("");
                return;
            }

            // A Maximize that cannot be clicked does not light up
            const PHLWINDOW   window = target.frame->window();
            const WindowFacts facts  = Frame::factsOf(window);
            const bool        dead   = target.part == Part::Maximize && !canToggle(facts.placement, facts.fixed);
            target.frame->pointerMoved(dead ? Button::None : buttonAt(target.part));

            const bool resizes = target.part == Part::Edge && !hyprlandDragging() && canResize(window);
            showCursor(resizes ? resizeCursor(target.frame->edgesAt(point)) : "");
        }

        void pressed(Event::SCallbackInfo& info) {
            // A drag of Hyprland's is going on, or a keybind's press (`bindm = SUPER, mouse:272, movewindow`): theirs
            if (hyprlandDragging() || (g_pInputManager->getModsFromAllKBs() & heldModifiers) != 0) {
                return;
            }

            const Vector2D point  = g_pInputManager->getMouseCoordsInternal();
            const Target   target = targetAt(point);
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
                state->grab = Grab{.frame = target.frame, .kind = GrabKind::Move, .start = point, .outer = *outer, .placement = facts.placement};
                return;
            }

            // An edge: Hyprland resizes, by the sides this point means, as Windows does (not by the nearest corner)
            const Layout::eRectCorner corner = cornerOf(target.frame->edgesAt(point));
            const SP<Layout::ITarget> layout = window->layoutTarget();
            if (!resizable(facts.placement, facts.fixed) || corner == Layout::CORNER_NONE || layout == nullptr) {
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

        // `grab` is a copy: dropGrab() lets go of state->grab
        void releasedGrab(const Grab& grab) {
            dropGrab();
            endOurDrag(grab);

            // Let go at the top of a screen: back into the layout
            const PHLWINDOW window = grab.frame.expired() ? nullptr : grab.frame->window();
            if (grab.kind == GrabKind::Move && grab.snapScreen.lock() != nullptr && window != nullptr && validMapped(window) && window->m_isFloating) {
                logFailure(Config::Actions::floatWindow(Config::Actions::TOGGLE_ACTION_DISABLE, window), "tile", window);
            }
        }

        void released(Event::SCallbackInfo& info) {
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
            if (event.button != BTN_LEFT) {
                return;
            }

            if (event.state == WL_POINTER_BUTTON_STATE_PRESSED) {
                pressed(info);
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
                ours = state->grab.has_value() || !state->holding.expired();
                if (state->grab.has_value()) {
                    const Grab grab = *state->grab;
                    dropGrab();
                    endOurDrag(grab);
                }

                showCursor("");
                state->holding = {};
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
        state->blurEnabled = std::make_unique<CConfigValue<Config::BOOL>>("decoration:blur:enabled");
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
