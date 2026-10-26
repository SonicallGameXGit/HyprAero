# AGENTS.md

Single source of truth for any AI agent (or human) working on this project. Read it fully before changing anything. If a decision here turns out to be wrong, change this file in the same change that breaks the rule; never let the code and this file disagree.

## 0. Shared rules (read first)

This project belongs to the Aero family. Before this file, read all of these, fully:

- `design/.aero/PRINCIPLES.md`: philosophy, architecture rules, testing, how to work, documentation duty
- `design/.aero/CODE_STYLE.md`: formatting and typing rules (C++ is its section 5)
- `design/.aero/STYLE.md`: visual style and shared tokens
- `design/.aero/FAMILY.md`: how members of the family relate
- `design/AGENTS.md`: HyprAero's design (tokens, primitives) and the rules every HyprAero module shares: how the repository is built (a branch per module, `design/` a submodule), Windows' own assets, the glass exception, identifiers

This file only adds to them or narrows them. A deliberate exception is marked **Exception** and says why. Where this file is silent, they apply. Claude Code loads them through `CLAUDE.md`; any other agent must open the files itself. Where this file says `.aero/...`, it means `design/.aero/...`.

`design/` is a git submodule (the `design` branch), not a folder of this branch: a clone needs `--recurse-submodules` (or `git submodule update --init`), and a change to it is made and pushed on the `design` branch, then taken here by committing the new pointer (`design/AGENTS.md` section 2).

Working name: **HyprAero** (placeholder, final name not chosen); this branch is its `frames` module. Identifiers (`design/AGENTS.md` section 5): app id `app.hyprAero.frames`; Hyprland plugin `hypraero-frames` (`hypraero-frames.so`), its hyprctl command `hypraero-frames`, its config values `plugin:hypraero-frames:*` when it gets some; layer namespaces of the companion `hypraero-frames-<part>` (`hypraero-frames-icons`, the window that reads icons).

## 1. What this is

Windows 7's **window frames** for Hyprland: the glass frame around each window, its title and icon, the Maximize / Restore and Close buttons, the window menu, moving by the title and the other things Windows 7's frame did. Drawn by Hyprland itself through a plugin, so a frame stacks with its window and moves with it in the same frame.

It is not a window manager (Hyprland places the windows), not a GTK or Qt theme, and it does not change apps. Making apps that draw their own title bars look the same is a separate question (section 8).

## 2. Place in the family

- Role: **addition** (a module of HyprAero; the base is the `bar`).
- Works without: the bar and every other module.
- Optional integrations: none yet. Any (for example minimized windows shown by the bar) is designed with the owner and written here, versioned, with a fake (`.aero/FAMILY.md` section 4).
- Target host: **Hyprland** on Wayland, the exact version the plugin was built against (section 5.3).

## 3. Tech stack

| Layer | Choice | Why |
| --- | --- | --- |
| Frames | A **Hyprland plugin** in **C++** (`plugin/`), on Hyprland's plugin interface (`IHyprWindowDecoration`, `HyprlandAPI`) | Only code inside the compositor can draw a frame between two overlapping windows and move it with its window; a layer surface sits above or below every window and trails behind moves. Owner's decision (2026-10-25). |
| Language level | C++26, GCC | What Hyprland is built with: its interface passes C++ objects, so there is no ABI guarantee across compilers (`PluginAPI.hpp`). |
| Build | CMake + Ninja, Hyprland's headers through `pkg-config hyprland` | Hyprland's own plugins and headers work that way; no other dependency. |
| Tests | Plain C++ executables run by CTest, one header of checks (`plugin/tests/check.hpp`), built with AddressSanitizer and UndefinedBehaviorSanitizer | No test library to depend on; the sanitizers find the memory errors that would crash Hyprland. |
| Format, lint | `clang-format` (`.clang-format`), `clang-tidy` (`.clang-tidy`) | The style and the safety rules a tool can check, checked by the tool (`.aero/CODE_STYLE.md` section 5). |
| Companion | **Quickshell** (QML), `shell.qml` | What the frames need that QML draws better (the window menu, tooltips) with the design's own primitives, and what the plugin cannot get itself: the system's theme and the apps' icons (section 7). Owner's decision (2026-10-25). |
| Design | The `design` branch as a git submodule at `design/` | Shared with every HyprAero module without copies. |

## 4. Architecture

### 4.1 Layout (created when first needed; do not add empty folders)

```
HyprAero/                       (the frames branch)
    AGENTS.md  CLAUDE.md  README.md  DECISIONS.md  .gitignore  .gitmodules
    .clang-format  .clang-tidy  the C++ style and safety rules a tool checks
    design/                     submodule: tokens, primitives, the kit (design/.aero/), rules shared by every module
    shell.qml                   the companion's entry point: the theme and the apps' icons, sent to the plugin
    companion/                  the companion's pieces: plugin.js (the door's requests, node-tested), AppIcons, IconReader
    resources/                  Windows 7's pictures the plugin embeds (frame/) and its generic icon (icons/); README.md
    tools/cut-pictures.py       makes resources/ from the owner's Windows 7 references, pixel for pixel
    plugin/
        CMakeLists.txt          the plugin (hypraero-frames.so) and the tests
        tools/tokens.cmake      turns design/Theme.qml's tokens into build/generated/generated/tokens.hpp
        src/main.cpp            the entry points Hyprland calls, and nothing else
        src/core/               plain C++ without Hyprland's headers: every decision, tested (safety, status, layout,
                                buttons, text, command, icons; tokens.hpp and pieces.hpp are data)
        src/host/               code that talks to Hyprland: state (the one State, run / runAlways), frame (one
                                window's decoration), frames (listeners, input, the hyprctl command), pictures
        tests/                  one executable per core file (<name>Test.cpp), check.hpp
    build/                      git-ignored: what CMake builds
```

### 4.2 Rules

- **Decisions in `core/`, Hyprland in `host/`.** What a frame looks like for a window, where its parts are, what a click on a point means, how a title is cleaned: plain functions in `src/core/` with tests, including the inputs that break things (empty, huge, invalid bytes, sizes of 0 and negative). `core/` never includes a Hyprland header; the entry points and `host/` only translate between Hyprland and `core/` and hold as little logic as possible, because they cannot be tested outside Hyprland.
- **The companion talks to the plugin through one door**: the plugin's hyprctl command (`hyprctl hypraero-frames ...`), parsed by a function in `core/` that is tested with good and bad messages. Nothing else crosses between them. The plugin works without the companion (without what the companion gives, section 7). The interface (version 1: status, `theme`, `icon`, `missing`) is written in `plugin/src/core/command.hpp`; `companion/plugin.js` is its other side. A change to it raises `interfaceVersion` and changes both sides in the same commit.
- **The design is not written here.** Tokens and primitives are the `design` branch's; the plugin gets its values from `design/Theme.qml` (section 7), never typed again in C++. A token the plugin needs is added to `.aero/STYLE.md` and `Theme.qml` first, then named in `plugin/tools/tokens.cmake`, which fails the build when one is missing.

## 5. Project-specific rules

### 5.1 The plugin must never take Hyprland down

The plugin runs inside Hyprland's process. A crash, a hang or broken memory in it ends the user's whole session and every unsaved piece of work in every app. **Less, but safe**: a feature that cannot be made safe is left out or proposed another way, never shipped "mostly working". This section outranks every feature. Owner's rule (2026-10-25).

**Every entry point is guarded.**

- Every function Hyprland calls (`pluginInit`, `pluginExit`, each method of a decoration, every event listener, dispatcher, hyprctl command and Lua function) is a thin wrapper in `main.cpp` or `host/`, declared `noexcept`, that runs its work through `run` (or `runAlways`, for what must work while the plugin is off: its status, unloading). They catch every exception, of any type, and nothing escapes into Hyprland. `clang-tidy`'s `bugprone-exception-escape` checks that a `noexcept` function cannot throw.
- **The safety switch** (`core/safety.hpp`): the first exception caught turns the plugin off for the session. From then on every guarded entry point does nothing and gives Hyprland its harmless answer (no input taken, nothing drawn), the windows look as without the plugin, the log says where and why, one Hyprland notification says it happened, and `hyprctl hypraero-frames` tells why. It comes back only when the plugin is loaded again. Reason: after an unexpected error the plugin's state cannot be trusted; a window without a frame is better than a wrong frame, and far better than a crash.
- **Exception**: `pluginInit` throws to refuse a load (another Hyprland version, loaded twice). That is Hyprland's own way: it catches it, logs "crashed in init" and unloads the plugin without calling `pluginExit`. Nothing is registered before those checks, and whatever init made before a later failure is undone before the throw.
- Our own code never throws (`.aero/CODE_STYLE.md` section 5: errors are values). The guard is for what we did not foresee: a standard library call, a bug.

**Hyprland's objects can go away between any two calls.**

- Never keep a strong pointer (`PHLWINDOW`, `PHLMONITOR`, `SP<...>`) to a Hyprland object past the call it came in; that keeps a dead window half alive. Keep weak references (`PHLWINDOWREF`, `WP<...>`) and check them (`expired()`) every time, right before use.
- A raw pointer or reference Hyprland passes is used inside that call only.
- Hyprland's state is changed only through its interface: decorations through `addWindowDecoration` / `removeWindowDecoration`, actions (close, fullscreen, move) through its dispatchers. Members its headers happen to expose are read, never written.
- **No function hooks.** `createFunctionHook`, `findFunctionsByName` and anything else that patches or calls Hyprland's internals have no stability guarantee (Hyprland's own warning in `PluginAPI.hpp`) and are the usual way plugins crash after an update. A feature that would need one is proposed to the owner with the risk and written in the decision log before any code.

**Nothing blocks, nothing runs beside Hyprland.**

- One thread: everything runs on Hyprland's thread, inside its calls. No `std::thread`, `std::async`, or timers of our own.
- No file, process, socket or D-Bus work inside a call from Hyprland, no `system()`, and never `hyprctl` from inside the plugin: Hyprland runs `pluginInit` synchronously and waits, so a call back to itself hangs the session.
- The work per frame is bounded: drawing only uses what was prepared before (a title turned into a picture when it changes, not every frame), with limits on how much is kept.

**Everything from outside is untrusted.**

- A window's title and class come from any app, possibly a hostile one: cut to a fixed length, invalid UTF-8 replaced, never used as a format string, before anything else sees them.
- Sizes and scales from Hyprland are checked before use: a size of 0, a negative or a huge one draws nothing or is capped, never divides by zero or allocates without a limit.
- What the companion sends is untrusted text: parsed by a tested `core/` function with a length limit; a bad message gets an error answer and changes nothing.
- A value Hyprland passes as `std::any` is read with the pointer form of `std::any_cast`; a type we do not expect is ignored.
- The log and every error never contain a window's title (it can be a mail's subject or a chat's message, `.aero/PRINCIPLES.md` section 4): a window is named by its class and address.

**Drawing.**

- Only through Hyprland's render interface and its own texture and render types, and only from inside the calls in which Hyprland draws. No raw OpenGL calls.
- A frame that cannot be drawn (missing texture, bad size) is skipped for that frame, not forced.

**Memory and unloading.**

- RAII only (`.aero/CODE_STYLE.md` section 5). Everything the plugin keeps lives in the one `State` made in `pluginInit` and destroyed in `pluginExit`; the pointer to it is the only global holding anything, empty while the plugin is not loaded. Beside it there is one counter, `loads` (`host/state.hpp`), raised by each load.
- Hyprland deletes a hidden window's decorations only when that window is shown again, which can be after the plugin was unloaded. So the library is linked with `-z nodelete` (its code stays mapped until Hyprland exits), and a frame remembers the load that made it: one from an earlier load does nothing and touches nothing but itself. The cost: a rebuilt `hypraero-frames.so` loaded again under the same path runs the old code until Hyprland restarts.
- Unloading is complete: `pluginExit` removes every decoration, listener, command and dispatcher it added, so nothing of ours can be called after the library is gone. Load, unload and load again, with windows open, is part of the checks of every change to `host/` (section 6).

**Reviews.**

- A change to `main.cpp` or `host/` is read against this section, rule by rule, before it is reported done, and the report says which rules it touched and how.
- When in doubt whether something is safe, it is not done; it is asked.

### 5.2 Never in the owner's running session

An agent never loads the plugin into the Hyprland the owner is working in, not even "to try". It is tested in a separate Hyprland (section 6), and loading it into the real session is the owner's own step.

### 5.3 Each Hyprland version

The plugin refuses to load into any Hyprland but the one it was built against (`pluginInit` compares Hyprland's hash with its own). After a Hyprland update: compare the old and new headers the plugin includes (`/usr/include/hyprland`), read every change to what it uses, rebuild, run all checks of section 6 and the separate Hyprland. Only then may the owner load it. A changed interface is adapted to, never worked around with a hook.

### 5.4 The rest

- The glass exception, the rules for the system (reduced motion and transparency, keyboard, monitors) and the network are `design/AGENTS.md` section 5.
- No Minimize button: Hyprland has no minimized windows, and the owner has an idea for them to talk about later (2026-10-25).

## 6. Checks and running

Before declaring work finished, run what applies and report the real result:

```bash
cmake -S plugin -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_CXX_COMPILER=g++   # once, or after CMakeLists.txt changes
cmake --build build                                                     # the plugin and the tests; warnings are errors
ctest --test-dir build --output-on-failure                              # core tests under ASan and UBSan
clang-tidy -p build plugin/src/main.cpp plugin/src/*/*.cpp plugin/tests/*.cpp   # must say nothing
clang-format --dry-run --Werror plugin/src/*.cpp plugin/src/*/* plugin/tests/*  # must say nothing
node --test companion/tests/*.test.mjs                                  # the companion's side of the door
/usr/lib/qt6/bin/qmllint shell.qml companion/*.qml                      # judge only new warnings: it cannot see Quickshell's qs.* modules
```

- The build refuses any compiler but GCC (Hyprland's ABI). An editor's CMake integration that configured `build/` with clang needs `--fresh` with the line above.
- `/usr/bin/qmllint` on this machine exits without a word; Qt's own is `/usr/lib/qt6/bin/qmllint`.
- `clang-format` cannot add the trailing comma after the last element of a multi-line list, and nothing checks that a comment says why: those stay review items.
- **A separate Hyprland** for anything the plugin does inside Hyprland (loading, drawing, input, unloading): a second Hyprland nested in a window of the owner's session, with its own runtime folder, started with the owner's permission each time (it opens a window on their screen), never by restarting theirs. Steps, run first on 2026-10-25:
    - A short runtime folder (Wayland's socket path must stay under 108 bytes): `/tmp/claude-1000/hyn`.
    - A test config in the scratchpad: `general:border_size 0`, `decoration:rounding 0`, blur on, animations off, `debug:disable_logs false` (else Hyprland's log stops after start and the plugin's lines are not written), `exec-once = hyprpaper -c <a config showing Windows 7's wallpaper>`. `Hyprland --verify-config -c <it>` first.
    - `systemd-run --user --scope -q env -i HOME=$HOME PATH=$PATH XDG_RUNTIME_DIR=/tmp/claude-1000/hyn WAYLAND_DISPLAY=/run/user/1000/wayland-1 Hyprland -c <config> &`: its own scope, so it is not part of the owner's login session.
    - `hyprctl` with `XDG_RUNTIME_DIR=/tmp/claude-1000/hyn` and `HYPRLAND_INSTANCE_SIGNATURE` set to the one folder in `/tmp/claude-1000/hyn/hypr/`; `hyprctl dispatch exec kitty` opens windows in it, `hyprctl dispatch movecursor x y` moves its own pointer (never the owner's), `WAYLAND_DISPLAY=/tmp/claude-1000/hyn/wayland-1 grim <file>` photographs it. Clicks cannot be made without a tool that drives the owner's real input, so they are not tried.
    - `hyprctl plugin load <full path to build/hypraero-frames.so>`, the checks, `hyprctl plugin unload`, load again, then `hyprctl dispatch exit`; check that no Hyprland, hyprpaper or `qs` of it is left.
    - Hyprland without any screen does not start (`CBackend::create() failed!` with no Wayland and no DRM device, tried 2026-10-25), so there is no invisible way.
- What the separate Hyprland showed is reported as "run and observed", never as "tested".
- The companion is checked as the notifications module checks itself: a copy run offscreen on a private bus (`env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen dbus-run-session -- qs -p <folder>`), its log read. Reading icons needs a layer shell, so that part runs in the separate Hyprland (`hyprctl dispatch exec "qs -p <folder>"`).

Run: the companion `qs --path ./`; the plugin is loaded by Hyprland (`hyprctl plugin load`, section 5.2). Build: `cmake --build build`. Logs: Hyprland's log (lines start with `[hypraero-frames]`), `qs log` for the companion.

## 7. Design

The style is fully in `design/.aero/STYLE.md` ("Window frames" holds the frame's tokens). What is drawn today and what is still the target (section 8):

- **The frame** (drawn) is Windows 7's: window glass around the whole window, 8px on the sides and bottom and a 30px band along the top holding the app's icon and title, blurred by Hyprland behind it when its blur is on (`design/AGENTS.md` section 5), Windows 7's streaks over it, a dark outer and a light inner line, and a light and a dark line around the window itself. Lighter for the active window and paler for the others, as Windows 7 tells them apart. The title is in the frame's text colour, on Aero over Windows 7's white glow; it is cut short with "…" before the buttons.
- **The icon** (drawn): the app's own, 16px (32px where the monitor is scaled), sent by the companion; Windows 7's generic application icon until it comes or when the app has none.
- **Buttons** (drawn, hover and press, clicks): Maximize (Restore while maximized) and Close at the top right, Windows 7's caption buttons with their glows, Close red under the pointer, greyed on an inactive window. No Minimize (section 5.4). A click acts on release over the same button, through Hyprland's own close and maximize. Tooltips: not yet.
- **Behaviour** (target): dragging the title moves the window, a double click maximizes or restores it, the edges resize it (today Hyprland's `resize_on_border`), a right click on the title (or Alt+Space) opens the window menu (Restore, Move, Size, Maximize, Close).
- **Which windows**: today every window Hyprland decorates, except X11 windows that ask for no border; the per-app off switch is Hyprland's own `decorate` window rule. An app that draws its own title bar (GTK's header bars, libadwaita, some Electron apps) therefore gets a second one for now; what it gets instead is decided with the owner (section 8).
- **Who draws what**: the plugin draws the frame, its title, icon and buttons and takes their input, because only it can. The companion draws what opens over the screen: the window menu (`design/PopupMenu.qml`) and the tooltips (`design/Tooltip.qml`), and reads the apps' icons for the plugin.
- **Tokens** (decided 2026-10-25): `plugin/tools/tokens.cmake` turns the frame's tokens of `design/Theme.qml`, both themes, into a header at build time; the companion only tells the plugin which theme the system shows (`theme aero|slate`). Without the companion the plugin draws Aero.
- **Pictures**: the caption buttons, their glows, the title's glow and the streaks are Windows 7's own, cut from its DWM atlas and embedded in the plugin (`resources/README.md`; the exception is in `.aero/STYLE.md` "The owner's design file"). The glass, its lines and the title are drawn from the tokens.

Tokens live in: `design/Theme.qml`. Primitives live in: `design/` (listed in `design/AGENTS.md` section 7).

## 8. Roadmap and current state

Works today (version 0.2.0): the plugin builds against the installed Hyprland, refuses to load into another one, and answers `hyprctl hypraero-frames` (`hyprctl -j hypraero-frames` in JSON) with its version and whether it is on, and if off, why. Every entry point goes through the safety switch (`core/safety.*`). Every window gets Windows 7's frame with its icon, title, Maximize / Restore and Close (section 7), in Aero or Slate; the companion sends the theme and the apps' icons. Run and observed in the separate Hyprland on 2026-10-25: load with windows open, frames on tiled and floating windows, active and inactive, hover glows on both buttons, Restore while maximized, Slate, the companion's icons, bad requests answered with an error, unload (frames gone, Hyprland running) and load again. Not observed: clicks (section 6), a scaled monitor, a window going fullscreen, the safety switch turning the plugin off inside Hyprland.

Not built yet, roughly in this order, each decided with the owner first:

1. Tooltips on the buttons, from the companion.
2. Moving by the title, double click, the window menu from the companion.
3. Apps that draw their own title bars: proposals for the owner (a thin border only; a GTK3 theme drawing their header bars as Aero glass; `gtk-decoration-layout` to hide their own buttons; telling such windows apart in the plugin).
4. Measured colours for the inactive and Slate glass (today estimated, `DECISIONS.md`), and `aero.msstyles` if the owner can provide it.
5. Minimized windows: the owner's idea, to talk about.

## 9. Decision log

The log lives in `DECISIONS.md`, one line per decision, newest last: `date - decision - reason`. Grep it for the topic before changing a rule, and append new decisions there in the same change.
