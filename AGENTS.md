# AGENTS.md

Single source of truth for any AI agent (or human) working on this project. Read it fully before changing anything. If a decision here turns out to be wrong, change this file in the same change that breaks the rule; never let the code and this file disagree.

## 0. Shared rules (read first)

This project belongs to the Aero family. Before this file, read all of these, fully:

- `.aero/PRINCIPLES.md`: philosophy, architecture rules, testing, how to work, documentation duty
- `.aero/CODE_STYLE.md`: formatting and typing rules
- `.aero/STYLE.md`: visual style and shared tokens
- `.aero/FAMILY.md`: how members of the family relate

This file only adds to them or narrows them. Where it is silent, the kit applies. Claude Code loads the kit through `CLAUDE.md`; any other agent must open the files itself.

Working name: **HyprAero** (placeholder, final name not chosen). Identifiers (case follows the host, see `.aero/FAMILY.md` section 2): app id `app.hyprAero.shell`; layer namespaces `hypraero-<module>` (`hypraero-bar`, `hypraero-drop`, `hypraero-notifications`, ...); config folder `~/.config/hypraero/`.

## 1. What this is

The **base desktop shell** of the Aero family: the bar, workspace switcher, app launcher, notifications, volume / system panels and the other pieces that make up a Hyprland desktop, restyled in Windows Aero and rebuilt on **Quickshell**.

It is a rewrite, not a port. It replaces an existing AGS + Astal shell (section 8). It is not a window manager, not a compositor and not a settings app for Hyprland itself.

## 2. Place in the family

- Role: **base**. Other apps (the mail client and later ones) are additions and never require this shell.
- Works without: any other member.
- Optional integrations: none defined yet. Any interface offered to other members is written here, versioned, with a fake for tests (`.aero/FAMILY.md` section 4).
- Target host: **Hyprland** on Wayland, Linux, any distribution. It must degrade gracefully when an optional service is missing (tray host, notifications daemon, audio server, Bluetooth, battery) and say so instead of crashing.

## 3. Tech stack

| Layer | Choice | Why |
| --- | --- | --- |
| Shell framework | **Quickshell** (QML) | Owner's decision. Native Qt rendering, layer-shell windows, real Hyprland and system integrations, no GJS. |
| Language | **QML** with typed properties; **TypeScript is not used** here. Logic that outgrows QML goes into plain JS modules or, if it must, a C++ plugin, after asking the owner. | QML is what Quickshell is. |
| Compositor | **Hyprland**, through Quickshell's own Hyprland module | Workspaces, windows, keyboard layout and events. |
| Services | Quickshell's built-in modules where they exist (tray, notifications server, PipeWire, MPRIS, UPower, Bluetooth, networking) | Reuse before writing. |

Specific libraries and any dependency beyond Quickshell itself are chosen when the relevant module is first built, with the reason recorded in section 9.

Quickshell documentation: https://quickshell.org/docs/ . Check the installed version's docs before using an API; do not rely on memory.

## 4. Architecture

### 4.1 Layout (proposed, created when first needed; do not add empty folders)

```
HyprAero/
    AGENTS.md
    CLAUDE.md                   imports the kit and this file
    README.md                   user manual; source of truth for visible behaviour
    .aero/                      the shared kit; never edited for this project's sake
    shell.qml                   entry point: creates the modules
    design/                     the token singleton (`Theme.qml`) and the primitives
    services/                   state and logic, no drawing (singletons)
    modules/                    one folder per piece of the shell (bar, launcher, notifications, ...)
    config/                     runtime config schema, validation, defaults
    assets/                     fonts, backdrops, icons
```

### 4.2 Rules

- **Services and modules are separate.** `services/` holds state and decisions and draws nothing; `modules/` draws and reads services. A module never talks to Hyprland, D-Bus or the system directly, only through a service.
- **Every module is optional.** Each can be turned off in the config without breaking the others.
- **One token file.** `design/Theme.qml` is the only place visual values are written (`.aero/STYLE.md` section 4, camelCase property names). Primitives live in `design/` and are reused by every module.
- **Config is validated on load**, a bad value falls back to its default and tells the user (notification or log), never crashes the shell.
- **Not the same as the AGS version, technically.** Nothing is copied from the old code. Its README and behaviour are the reference for *what the shell should do*; how it is done is decided fresh under these rules.

## 5. Project-specific rules

- **Exception (glass):** the shell runs on Hyprland, which can blur what is behind a layer surface. Panels draw their glass tint, borders and shine themselves and **also** may ask the compositor for blur (Hyprland layer rules, namespace-based). Without compositor blur the panel must still be readable and recognisably Aero (a more opaque tint, defined as its own token in both themes). Reason: the shell always runs on Hyprland, which makes the blur reliable; `.aero/STYLE.md` section 3 allows relying on it only when documented like this. The Hyprland rules a user needs to add go into `README.md`.
- Layer surfaces use a **namespace per module** (`hypraero-bar`, `hypraero-notifications`, ...) so the user's compositor rules can target them.
- **Customisation** follows `.aero/PRINCIPLES.md` section 3: bar position (default: bottom, as in Windows 7), icon and bar size, which modules and items show, order and behaviour are all settings. The Aero look is not: no setting changes button style, rounding or gloss.
- Respect the system: reduced-motion and reduced-transparency preferences, keyboard focus, and multiple monitors (a bar per screen; popups open on the screen that asked).
- The shell must never grab keyboard focus when it does not need it; popups that do (launcher) release it on close, on Escape and on click outside.
- Startup is fast and silent; a failing module logs and stays out of the way.
- No telemetry, no network calls other than what a visible feature needs (for example, a weather widget fetching weather), each opt-in.

## 6. Checks and running

Proposed, not yet exercised on a real module (confirm when the first one lands):

```bash
qmlformat --inplace <files>    # formatting (Qt's own; it cannot enforce every rule of CODE_STYLE.md section 3, those stay a review item)
qmllint <files>                # QML errors and warnings, must be clean
node --test                    # plain-JS logic (parsers, ranking, config validation) without launching the shell
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml -import tests/qml/fakes    # QML behaviour of single components (pointer handling), against fake services
```

- Anything with decisions in it (launcher ranking, config validation, workspace/window grouping, notification text) is written as a plain `.js` module with no QML or Quickshell imports, so `node --test` covers it; QML only calls it. This is the shell's version of "logic separate from presentation".
- A component that only needs Qt Quick and services can be tested headless with `qmltestrunner` (`tests/qml/`): the services it imports are replaced by fakes in `tests/qml/fakes/qs/services/`, which only need what the tested component uses. Quickshell types (windows, Hyprland) are not available there.
- Drawing and system integration (layer surfaces, tray, PipeWire) cannot be unit tested; they are checked by running the shell and reading its log. Report them as "run and observed", never as "tested".
- Editor support: `qmlls` (in Qt's bin folder, `/usr/lib/qt6/bin/qmlls`) gives completion and diagnostics.

Run: `qs --path=./` from the project root. Build: none (there is nothing to build). Logs: `qs log`; stop: `qs kill`. Other forms of `qs` (named configs in `~/.config/quickshell/`) are not used; do not add variants.

## 7. Design

The **style** is fully in `.aero/STYLE.md`. This section is the **design** of the shell: what is placed where and how it behaves. The old shell is the base, not the template: keep what worked, change what the owner finds wrong, ask when unsure.

### 7.1 Pieces carried over from the old shell (behaviour to preserve in spirit)

- **Top bar**: workspaces, tray, keyboard-layout indicator, clock with calendar.
- **Workspaces**: shows the focused workspace, the main app icon of each workspace and a second indicator for multi-window ones; hovering a workspace lists its windows (icon, name, close button), and windows can be dragged between workspaces; windows can be given a display name and icon override.
- **App launcher**: opens anchored near the workspaces, keyboard navigable, ranks results by usage.
- **Volume panel**: interactive (drag and scroll), shown from a screen-edge zone.
- **Notifications**: a notification window with action buttons and reliable app-icon resolution; configurable from a JSON file.
- **Runtime config and state files** for the things above.

### 7.2 Direction

- The Windows 7 language is the target: a taskbar-like bar with glossy glass, a start-menu-like launcher, a calendar / clock flyout, a volume flyout, Aero balloon-style notifications. The bar defaults to the bottom edge and its position is a user setting (section 5).
- Anything above that is new needs a proposal first (`.aero/PRINCIPLES.md` section 2).

Tokens live in: `design/Theme.qml` (singleton; only the tokens in use so far, both themes, Slate is chosen by the system colour scheme). Primitives live in: `design/` (`GlassPanel`, `ControlButton` with kinds normal / accent / tool / danger and a `highlighted` state, `DotIcon`, `GenericAppIcon`, `AppIconImage`, `CloseGlyph`, `ReturnGlyph`, `DropZone`).

## 8. Reference: the previous shell

Location: `/home/sonicall/Downloads/AGSTest` (AGS + Astal, TypeScript, SCSS). Read-only reference, outside this repository. Useful files: `README.md` (complete user manual of the old behaviour), `widget/` (Bar, VolumeIndicator, Notifications), `service/`, `config.ts` (config schema), `style.scss`.

Its technology is explicitly **not** carried over: no GJS, Astal, GTK widgets, SCSS or TypeScript code is copied or translated line by line. Its own `AGENTS.md` and style rules are superseded by the kit.

## 9. Roadmap and current state

Works today: a bar per screen (bottom, glass, namespace `hypraero-bar`) with centered workspace buttons (48px bar): click to switch; each button shows a dot (empty), the app icon (one app) or the biggest app's icon with the second biggest as a small badge; a highlight slides and stretches to the current workspace; hovering a workspace with windows opens a popup of live window previews (icon, title, picture) biggest first, sitting on top of the bar. Each preview card lights up on hover, goes to its window on click (workspace and focus; the pointer is not moved) and has a close button that asks the app to close. A card can be dragged to move its window to another workspace (the view stays): onto a button, beside the buttons (leftmost / rightmost free workspace) or higher up the screen (lowest free one), with the target button lit during the drag. A workspace button with windows can be dragged the same way to move the whole workspace (renumbered when the target is free, so its layout stays). Every drag leaves a glass "Put back" slot where it was taken from; dropping back on it changes nothing. A strip at the right end of the bar (Windows 7's "Show desktop" place) goes to the first workspace without windows. Workspaces 1-10 are always shown; clicking an empty one creates it (Hyprland does that on focus). The theme follows the system colour scheme live. No config, no other modules yet.

Not built yet, roughly in this order (steps 1 and most of 2-3 are done; the bar still lacks clock and tray):

1. Verify Quickshell is installed and a minimal `shell.qml` runs on Hyprland; write the run command into section 6.
2. `design/Theme.qml` from `.aero/STYLE.md`, both themes, plus the first primitives (glass window, button, icon).
3. Bar with workspaces, clock, tray.
4. Notifications (server and balloon).
5. Launcher.
6. Volume / system flyouts.
7. Config file and settings window.

## 10. Decision log

Newest last. One line per decision: date, decision, reason.

- 2026-10-10 - Rebuild the desktop shell on Quickshell instead of AGS + Astal, restyled in Windows Aero. Reason: owner's decision; the old stack is the thing being left.
- 2026-10-10 - Shared rules live in a portable kit (`.aero/`), the project `AGENTS.md` only adds to them, `CLAUDE.md` imports both. Reason: the shell is the base of a family of apps (the mail client and more); one copy-paste must carry the principles, code style, visual style and family rules everywhere.
- 2026-10-10 - Style is taken from the mail client's tokens (Aero light, Slate dark); the old shell contributes behaviour only. Reason: owner's request - style and design are separate things.
- 2026-10-10 - QML code style is the TypeScript style carried over as far as QML's syntax allows (owner confirmed; the rule is general for any language without its own section). Reason: one style everywhere.
- 2026-10-10 - Identifier case follows the host: `app.hyprAero.shell` for app ids, `hypraero-<module>` for layer namespaces and config folders. Reason: owner's request, Hyprland configs use lowercase kebab.
- 2026-10-10 - Bar defaults to the bottom and its position is a setting; placement, sizes and behaviour are configurable, the Aero look is not. Reason: owner's rule "full control while user-friendly" within the family identity.
- 2026-10-10 - Run with `qs --path=./`; checks proposed as `qmlformat`, `qmllint` and `node --test` for logic kept in plain JS. Reason: Quickshell has no build step; decisions kept out of QML are testable without the shell.
- 2026-10-10 - Workspace switching dispatches the Lua form `hl.dsp.focus({ workspace = N })`, isolated in `services/Workspaces.qml`. Reason: Hyprland 0.56 with a Lua config rejects the old `workspace N` text; legacy `.conf` hosts would need a second implementation behind the same function.
- 2026-10-10 - First version is only the bar with workspace buttons; the glass blur fallback token and reduced-transparency support are postponed. Reason: owner asked for the minimum first.
- 2026-10-10 - Workspaces 1-10 are always shown, as the owner's Hyprland binds exactly those. Reason: matches the old bar and the shortcuts; more appear only while they exist or have focus.
- 2026-10-10 - Theme follows the system through the freedesktop portal (`gdbus` call + monitor, parsed in `services/colorScheme.js`), not Qt's `styleHints.colorScheme`. Reason: Qt reported no preference on this setup; the portal is what GTK and browsers follow. Without gdbus or a portal the bar stays Aero light.
- 2026-10-10 - Workspace icons: apps are ranked by their biggest window (`services/workspaceList.js`), icons come from the desktop entry, then an icon named like the window class, then a drawn generic window. Reason: owner's rule from the old bar; the fallback keeps apps without an icon visible instead of blank.
- 2026-10-10 - The current-workspace marker is one highlight that slides and stretches (leading edge faster than the trailing one, 120 / 220ms), instead of the old bar's physics bubble. Reason: soft, not bouncy (`.aero/STYLE.md` motion), and it reads as one object moving.
- 2026-10-10 - Bar height 48px. Reason: owner asked for a bit higher; room for 28px icons plus a 16px badge.
- 2026-10-10 - Hover popup lists a workspace's windows (not one row per app), biggest window first, ordered in `services/workspaceList.js`. Reason: owner asked for the list sorted by size; titles tell two windows of one app apart. Closing, dragging and name overrides from the old bar are not built yet.
- 2026-10-10 - The hover popup is Windows 7 style thumbnail cards with live previews (Quickshell `ScreencopyView` on the window's Wayland handle), anchored to the bar's top edge instead of the button. Reason: owner asked for the original taskbar look and for no overlap with the bar. Cards are not clickable yet, so they have no hover highlight.
- 2026-10-10 - The preview popup window is created once, as wide as the bar, and never moves or resizes; only the glass panel inside glides between buttons (input mask limited to the panel). Window sizes for previews come from Hyprland, not from `ScreencopyView`, which reports none. Reason: re-placing a popup window made it flash in the screen corner, and the capture view stayed blank without an explicit size.
- 2026-10-10 - Preview cards keep a fixed picture height (120px) and take their width from the window's aspect ratio, clamped to 64-280px (16:9 until the size is known). Reason: owner asked; a fixed 200px width left bars around tall and wide windows.
- 2026-10-10 - A window hanging even 1px off its monitor (`hangsOffMonitor` in `services/workspaceList.js`) gets no live preview: each time the popup opens it captures one frame, reads it once through a hidden `Canvas` (256x256 copy) and crops to the box around the drawn pixels (`services/pictureBounds.js`); the card takes that part's proportions. Windows fully on screen stay live and are not scanned. Reason: Hyprland captures the whole window but leaves what it did not draw transparent, where that part lands does not follow the window's position (a probe showed a window off the bottom drawn in full), and a live picture of such a window slides during workspace animations; the owner chose a frozen, correct frame over a live one there.
- 2026-10-10 - The preview popup keeps two card sets (`modules/bar/PreviewCards.qml`): moving to another workspace loads its cards in the hidden set, keeps the old ones on screen until every new picture has arrived (at most 500ms), then crossfades (220ms); the set fading out stops capturing and is emptied afterwards. Reason: owner saw a blink of empty cards between workspaces; at most two sets capture at once, and only during a switch.
- 2026-10-10 - App icons are drawn through `design/AppIconImage.qml`: loaded at 256px and shrunk by the GPU with mipmaps. Reason: the icon theme shrinks a 256px-only icon (Vivaldi, Discord, Kitty) to the asked size in one step, which left jagged edges; compared side by side on screen, the mipmapped version matches a smoothly scaled file.
- 2026-10-10 - Closing from a preview card goes through the window's own Wayland handle (`toplevel.wayland.close()`, foreign-toplevel close), not a Hyprland dispatcher. Reason: it is the same polite request as the window's close button (apps can ask to save), and it can only reach that window; a probe showed `hl.dsp.window.close` with an argument it does not understand closes the active window instead.
- 2026-10-10 - Clicking a preview card dispatches `hl.dsp.focus({ window = 'address:0x...' })`, which switches the workspace too, and leaves the pointer where it is. The address is checked against `^0x[0-9a-fA-F]+$` before it goes into the Lua text. Reason: the owner tried moving the pointer to the middle of the window and found it a bad idea.
- 2026-10-10 - `ControlButton` takes its hover from a `HoverHandler` instead of the `MouseArea`. Reason: the close button sits inside the card button, and the card must stay lit (and the close button shown) while the pointer is on it.
- 2026-10-10 - The right-end strip goes to the lowest listed workspace without windows, or the one after the highest when all have windows (`firstEmptyWorkspace`); clicking it again does not bring the windows back as on Windows. Reason: owner's request; workspaces replace minimising, so "show desktop" means an empty workspace.
- 2026-10-11 - Dragging a preview card onto a workspace button moves the window there, as a real Wayland drag (`Drag.Automatic` from a `DragHandler`, the card grabbed as the drag picture, a `DropArea` on each button) carrying the address in the private format `application/x-hypraero-window`. Reason: the popup and the bar are separate surfaces and the pointer belongs to the popup while the button is held, so only a compositor drag reaches the bar and draws the card under the pointer; a private format means dropping on an app does nothing.
- 2026-10-11 - The move dispatches `hl.dsp.window.move({ workspace = N, window = 'address:0x...', follow = false })`; addresses pass `isWindowAddress` (`services/workspaceList.js`) first. Reason: a probe on Hyprland 0.56 showed `silent = true` (the old bar's form) is ignored and the view follows the window; `follow = false` keeps the view, which is what dropping a window away should do.
- 2026-10-11 - While a card is dragged the popup stays open and its cards are not rebuilt (`dragging` in `WorkspacePopup.qml`), then it re-reads the windows and closes unless the pointer is on it or a button. Reason: the card is the drag's source; destroying it mid-drag (the popup closing because the pointer left, or a window list change) would break the drag.
- 2026-10-11 - While a window is dragged, every screen gets a transparent full-screen overlay layer (`modules/bar/DropLayer.qml`, namespace `hypraero-drop`, shown only during the drag) that draws the card and takes the drop; the popup hides (kept alive, input mask emptied). The card is not the compositor's drag icon. Reason: owner asked for the card to stay where it was grabbed, and Hyprland 0.56.2 ignores the icon's hotspot (Qt sends `wl_surface.offset`, then `attach(buffer, 0, 0)`, whose 0, 0 overwrites the offset in Hyprland's attach handler); drops outside our own surfaces (over apps) could not be caught either. A press on the layer removes it, so a drag that ends without notice can never leave the screen covered.
- 2026-10-11 - Where a drop goes is `dropWorkspace` in `services/workspaceList.js`: within 48px of the bar over the buttons the pointer counts as on it (closest button), and within 240px beside them (left: the leftmost free workspace, right: the rightmost), further away the lowest free one; no free one means nothing happens. The target button is lit during the drag. Reason: owner's rules for the sides and for "up" (lowest free chosen by the owner); the lit button makes the outcome visible before the drop.
- 2026-10-11 - New kit token `drag-image-opacity` (0.75, both themes) for the dragged card. Reason: owner approved; an opaque card would hide the lit button under it.
- 2026-10-11 - The sides of the bar catch a drop up to 240px above it, the buttons only 48px. Reason: owner asked for a much taller area at the sides; over the buttons it stays short so "up" (lowest free workspace) is still reached after a short move.
- 2026-10-11 - Dragging a workspace button moves the whole workspace, with the same drop places and lit target as a card (`modules/bar/DragSource.qml` shared by both, state in `services/BarDrag.qml`). When the target number is free the workspace is renumbered (`hl.dsp.workspace.change_id`), otherwise its windows are moved one by one; `workspaceMovePlan` in `services/workspaceList.js` decides. Reason: owner asked to keep order, positions and sizes; renumbering keeps the workspace object itself (probe: same position and size after the change), while a move re-tiles each window. Hyprland refuses a taken id and an empty workspace exists only while shown, so the empty workspace on screen is first left for the source (probe: Hyprland drops it, the renumber then succeeds).
- 2026-10-11 - Moving the workspace on screen leaves the view on its old number, as moving a single window does. Reason: one rule for both drags, "you stay where you are".
- 2026-10-11 - The bar re-reads the workspaces on Hyprland's `changeworkspaceid` event. Reason: Quickshell 0.3.2 does not handle it; a probe showed the renumbered workspace's windows vanishing from the bar until a refresh.
- 2026-10-11 - The workspace buttons are not rebuilt during a drag (their count holds still). Reason: a button is the drag's source; rebuilding it mid-drag would break the drag.
- 2026-10-11 - `DragSource` sits under its button's `MouseArea` (z -1). Reason: placed above it, the `DragHandler` swallowed every click (owner found clicking a workspace with windows and a preview card did nothing; reproduced headless, a press and release never reached `clicked`); under it, clicks pass and a drag still takes over once the pointer moves. Covered by `tests/qml/tst_DragSource.qml`.
- 2026-10-11 - QML components that need only Qt Quick and services are tested headless with `qmltestrunner` against fake services (`tests/qml/fakes/`). Reason: the click bug above could not be caught by `node --test`, and testing it must not need the shell to run.
- 2026-10-11 - After a renumber (`changeworkspaceid`) the windows and monitors are re-read at once, and workspace numbers never come straight from Quickshell's objects: a placeholder with id -1 is numbered by its name (`workspaceNumber`), a window falls back to Hyprland's record of it, and "which workspaces exist" is the ones with windows, shown on a monitor or focused (`existingIds`), not Quickshell's list. Reason: owner saw both slots empty and the marker on the first button for seconds after a workspace move. Quickshell 0.3.2 matches workspaces by id, so the renumbered one is unknown to it: a window / monitor refresh links to a placeholder named after it with id -1, its QML workspace refresh can neither create nor drop workspaces (and answered before the placeholder existed in a probe), and the old object stays. Probe after the fix: the window showed on its new button within 0.4s.
- 2026-10-11 - Every drag out of the bar leaves a ghost where it was taken from (the picture at `drag-ghost-opacity` in a control frame, drawn by `DropLayer`); it gets the button hover face under the pointer, no workspace button is lit there, and a drop on it does nothing. The origin travels in `BarDrag` as the bar's screen plus a rectangle in bar coordinates (the popup reports its window's place in the bar, `barOffset`). Reason: owner's request, so a drag started by mistake can be undone; the hover face says "letting go here does something".
- 2026-10-11 - New kit token `drag-ghost-opacity` (0.35, both themes). Reason: owner chose the faded picture over an empty slot.
- 2026-10-11 - The ghost is a drop zone instead of a faded picture: a glass slot (`design/DropZone.qml` on `GlassPanel`) with the flat undo arrow (`design/ReturnGlyph.qml`) and "Put back" when it fits; lit, its edge takes the `focus-glow` ring and glow. The compositor frosts it through a blur rule on `hypraero-drop` (README.md); without the rule it is plain drawn glass. `drag-ghost-opacity` is removed from the kit again, unused. Reason: owner preferred a real ghost, after Vivaldi's tab drop zone (frosted, outlined, a label saying what the drop does), in Aero style.
