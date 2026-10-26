#include "host/frames.hpp"

#include <hyprland/protocols/wlr-layer-shell-unstable-v1.hpp>
#include <hyprland/src/config/shared/actions/ConfigActions.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/state/ViewHitTester.hpp>
#include <hyprland/src/desktop/state/ViewState.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/managers/SeatManager.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/render/decorations/DecorationPositioner.hpp>

#include <linux/input-event-codes.h>

#include <algorithm>
#include <array>
#include <format>
#include <ranges>
#include <variant>
#include <vector>

#include "core/command.hpp"
#include "core/status.hpp"
#include "host/frame.hpp"
#include "host/state.hpp"

namespace frames::host {

    namespace {

        constexpr std::string_view pluginVersion = FRAMES_VERSION;

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

        void pointerMoved(const Vector2D& point) {
            prune();
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
            if (!target.frame.expired()) {
                target.frame->pointerMoved(buttonAt(target.part));
            }
        }

        void pressed(Event::SCallbackInfo& info) {
            const Target target = targetAt(g_pInputManager->getMouseCoordsInternal());
            if (target.frame.expired() || !target.frame->pointerPressed(buttonAt(target.part))) {
                // The caption and the edges are Hyprland's: it focuses the window, resizes by the edges
                return;
            }

            info.cancelled = true;
            state->holding = target.frame;

            // As on Windows, pressing a caption button activates its window
            const PHLWINDOW window = target.frame->window();
            if (window == nullptr) {
                return;
            }

            if (Desktop::focusState()->window() != window) {
                Desktop::focusState()->fullWindowFocus(window, Desktop::FOCUS_REASON_CLICK);
            }

            if (window->m_isFloating) {
                Desktop::windowState()->raise(window);
            }
        }

        void released(Event::SCallbackInfo& info) {
            if (state->holding.expired()) {
                return;
            }

            // The press was the frame's, so the release is too: the app never saw either
            info.cancelled         = true;
            const WP<Frame> holder = state->holding;
            state->holding         = {};

            const Target    target = targetAt(g_pInputManager->getMouseCoordsInternal());
            const Button    act    = holder->pointerReleased(target.frame.get() == holder.get() ? buttonAt(target.part) : Button::None);
            const PHLWINDOW window = holder->window();
            if (window == nullptr) {
                return;
            }

            if (act == Button::None) {
                return;
            }

            // Through the same actions as Hyprland's own dispatchers (`killactive` asks the app to close, `fullscreen 1`)
            const bool                          closing = act == Button::Close;
            const Config::Actions::ActionResult result =
                closing ? Config::Actions::closeWindow(window) : Config::Actions::fullscreenWindow(Fullscreen::FSMODE_MAXIMIZED, true, window);
            if (!result.has_value()) {
                logLine(Log::WARN,
                        std::format("could not {} a window of class {}", closing ? "close" : "maximize", plainText(window->m_class, maxClassLength)));
            }
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

    }

    void startFrames() {
        state->blurEnabled = std::make_unique<CConfigValue<Config::BOOL>>("decoration:blur:enabled");

        const std::size_t failed = decodePictures(state->pictures);
        if (failed > 0) {
            logLine(Log::WARN, std::format("{} of Windows 7's pictures could not be read; they are left out", failed));
        }

        auto& events = Event::bus()->m_events;
        state->listeners.push_back(events.window.open.listen([](const PHLWINDOW& window) { run("window opened", [&] { addFrame(window); }); }));
        state->listeners.push_back(events.window.title.listen([](const PHLWINDOW& window) {
            run("title changed", [&] {
                const WP<Frame> frame = frameOf(window);
                if (!frame.expired()) {
                    frame->titleChanged();
                }
            });
        }));
        state->listeners.push_back(events.window.active.listen([](const PHLWINDOW& /* window */, Desktop::eFocusReason /* reason */) {
            // The window that was active and the one that is now both change their look
            run("window activated", [] { forEachFrame([](Frame& frame) { frame.damageEntire(); }); });
        }));
        state->listeners.push_back(events.window.updateRules.listen([](const PHLWINDOW& window) {
            // The `decorate` rule may have turned the frame on or off
            run("window rules", [&] {
                const WP<Frame> frame = frameOf(window);
                if (!frame.expired()) {
                    g_pDecorationPositioner->repositionDeco(frame.get());
                    window->updateWindowDecos();
                }
            });
        }));
        state->listeners.push_back(events.window.fullscreen.listen([](const PHLWINDOW& window) {
            // Maximize turns into Restore and back
            run("window maximized", [&] {
                const WP<Frame> frame = frameOf(window);
                if (!frame.expired()) {
                    frame->lookChanged();
                }
            });
        }));
        state->listeners.push_back(
            events.input.mouse.move.listen([](Vector2D point, Event::SCallbackInfo& /* info */) { run("pointer moved", [&] { pointerMoved(point); }); }));
        state->listeners.push_back(events.input.mouse.button.listen(
            [](IPointer::SButtonEvent event, Event::SCallbackInfo& info) { run("pointer button", [&] { button(event, info); }); }));

        for (const PHLWINDOW& window : Desktop::windowState()->windows()) {
            addFrame(window);
        }
    }

    void stopFrames() noexcept {
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
