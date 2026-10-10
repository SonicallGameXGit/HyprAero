# AGENTS.md

Single source of truth for any AI agent (or human) working on this project. Read it fully before changing anything. If a decision here turns out to be wrong, change this file in the same change that breaks the rule; never let the code and this file disagree.

## 0. Shared rules (read first)

This project belongs to the Aero family. Before this file, read all of these, fully:

- `.aero/PRINCIPLES.md`: philosophy, architecture rules, testing, how to work, documentation duty
- `.aero/CODE_STYLE.md`: formatting and typing rules
- `.aero/STYLE.md`: visual style and shared tokens
- `.aero/FAMILY.md`: how members of the family relate

This file only adds to them or narrows them. Where it is silent, the kit applies. Claude Code loads the kit through `CLAUDE.md`; any other agent must open the files itself.

Working name: **HyprAero** (placeholder, final name not chosen). Identifiers (case follows the host, see `.aero/FAMILY.md` section 2): app id `app.hyprAero.shell`; layer namespaces `hypraero-<module>` (`hypraero-bar`, `hypraero-notifications`, ...); config folder `~/.config/hypraero/`.

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
```

- Anything with decisions in it (launcher ranking, config validation, workspace/window grouping, notification text) is written as a plain `.js` module with no QML or Quickshell imports, so `node --test` covers it; QML only calls it. This is the shell's version of "logic separate from presentation".
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

Tokens live in: `design/Theme.qml` (singleton; only the tokens in use so far, both themes, Slate is chosen by the system colour scheme). Primitives live in: `design/` (`GlassPanel`, `ControlButton`).

## 8. Reference: the previous shell

Location: `/home/sonicall/Downloads/AGSTest` (AGS + Astal, TypeScript, SCSS). Read-only reference, outside this repository. Useful files: `README.md` (complete user manual of the old behaviour), `widget/` (Bar, VolumeIndicator, Notifications), `service/`, `config.ts` (config schema), `style.scss`.

Its technology is explicitly **not** carried over: no GJS, Astal, GTK widgets, SCSS or TypeScript code is copied or translated line by line. Its own `AGENTS.md` and style rules are superseded by the kit.

## 9. Roadmap and current state

Works today: a bar per screen (bottom, glass, namespace `hypraero-bar`) with workspace buttons: click to switch, focused one accent, workspaces with windows normal, empty ones flat. Workspaces 1-10 are always shown; clicking an empty one creates it (Hyprland does that on focus). The theme follows the system colour scheme live. No config, no other modules yet.

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
