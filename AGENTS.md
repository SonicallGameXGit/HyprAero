# AGENTS.md

Single source of truth for any AI agent (or human) working on HyprAero's design, and for the rules every HyprAero module shares. Read it fully before changing anything. If a decision here turns out to be wrong, change this file in the same change that breaks the rule; never let the code and this file disagree.

## 0. Shared rules (read first)

This project belongs to the Aero family. Before this file, read all of these, fully:

- `.aero/PRINCIPLES.md`: philosophy, architecture rules, testing, how to work, documentation duty
- `.aero/CODE_STYLE.md`: formatting and typing rules
- `.aero/STYLE.md`: visual style and shared tokens
- `.aero/FAMILY.md`: how members of the family relate

Inside a module the kit is at `design/.aero/`. This file only adds to the kit or narrows it. Where it is silent, the kit applies. Claude Code loads the kit and this file through `CLAUDE.md` (here, and in every module); any other agent must open them itself.

Working name: **HyprAero** (placeholder, final name not chosen). This branch has no identifiers of its own; it is the QML module `qs.design` of whichever module includes it.

## 1. What this is

The look of HyprAero, written once: the token singleton (`Theme.qml`, `.aero/STYLE.md` section 4 in QML), the drawing primitives every module builds on (buttons, glass, menus, flyout frames, glyphs, ...), the theme follower (`SystemTheme.qml`) and the Aero kit (`.aero/`). It is also the home of the rules all HyprAero modules share (sections 2, 4.3, 5).

It is not a program. It draws nothing on its own, keeps no state and talks to the system only to follow the colour scheme. Run a module to see it.

## 2. HyprAero's modules and this branch

HyprAero is one repository with one branch per module. Each module installs and runs on its own, without the others' code or resources:

| Branch | What it is |
| --- | --- |
| `main` | Landing page: the modules, what each needs, how to install |
| `design` | This branch |
| `bar` | The base desktop shell: taskbar, start menu, notification area, flyouts |
| `notifications` | The notification server and its balloons |

- Every module branch includes this branch as a **git submodule** at `design/` (`branch = design`), so its files are imported as `qs.design`, exactly as before the split. Nothing of this branch is copied into a module.
- A module is its own Quickshell shell root and its own `qs` process. Modules talk to each other only through documented, versioned interfaces (`qs ipc`, D-Bus, Hyprland's own state such as layer namespaces and reserved areas), written in the `AGENTS.md` of the side that offers them, with a fake for tests (`.aero/FAMILY.md` section 4). Without the other side a module still works, and the missing feature says so.
- A module takes a change of this branch when it moves its pointer (`git submodule update --remote design`, then commits `design`). Nothing reaches a module silently.
- Changing this branch from inside a module: `cd design && git switch design && git pull` first (a submodule sits on a bare commit), commit and push here, then commit the new pointer in the module.
- Repository settings that keep it consistent: `submodule.recurse = true` and `push.recurseSubmodules = on-demand` (a module never points at a design commit GitHub does not have).

## 3. Tech stack

| Layer | Choice | Why |
| --- | --- | --- |
| Framework | **Quickshell** (QML), Qt Quick only in primitives | What every module is built on. |
| Logic | Plain JS library scripts (`.pragma library`), no QML or Quickshell imports | `node --test` covers them without Qt. |

## 4. Architecture

### 4.1 Layout

```
design/                         (this branch's root; a module sees it at design/)
    AGENTS.md  CLAUDE.md  README.md  DECISIONS.md
    .aero/                      the shared kit, copied unchanged between family projects
    Theme.qml                   the tokens (singleton, both themes)
    SystemTheme.qml             follows the system colour scheme (portal, gdbus)
    <Primitive>.qml             one file per primitive (section 7)
    *.js                        plain logic of the primitives: avatar, balloonShape, clockHands, colorScheme, iconColor, trayGlyphs
    tests/                      node tests of the JS (*.test.mjs)
    tests/qml/                  qmltestrunner tests of primitives, with fakes/ standing in for Quickshell
```

### 4.2 Rules

- **Self-contained.** A file here imports only Qt, Quickshell and files of this folder. Never `qs.services`, `qs.modules` or `../services/...`: those belong to a module, and this branch must load in any of them. A primitive that needs a module's service belongs to that module (as `DragSource` stays in the bar).
- **The one reach outside:** `WindowsIcon.qml` reads `../resources/icons/` (and its `frames.js`), which inside a module is the module's own `resources/icons/` (section 4.3). Only a module that uses `WindowsIcon` needs that folder.
- **Tokens first.** A visual value is a token in `Theme.qml`, added to `.aero/STYLE.md` first (`.aero/STYLE.md` sections 4-5), in the same commit when both change.
- **Logic out of QML.** A decision a primitive makes (a hash, an angle, a colour from pixels, a parsed line) is a function in a `.js` file with a node test.
- **Changing a primitive's interface or removing a token** can break a module that still uses it: look in every module branch (`git grep <name> <branch>`) before, and say in `DECISIONS.md` what a module has to change.

### 4.3 Windows' own assets (icons, sounds, cursors)

HyprAero imitates Windows 7, and the owner keeps Windows' originals for it. **Every agent reads this before drawing an icon, adding a sound or a cursor, in any module.**

- **Where they are:** on the owner's machine only, git-ignored, in the bar's working folder: `assets/windows-ui-assets-main/` (a copy of https://github.com/bartekl1/windows-ui-assets: icons of Windows XP to 11 as `Icons/<version>/ico/<dll>/ICON<n>_1.ico`, sounds as `Sounds/<version>/*.wav`, cursors, wallpapers; `Tables/<version> Icons.md` shows every icon with its number) and `assets/windows7-sp1/` (Windows 7's other system files taken out of Microsoft's Service Pack 1 package; its `README.md` says how, and its `tools/` hold `icoex.py` and `sheet.py`). Beside them, `assets/aero/` is an export of the owner's design file (`.aero/STYLE.md` "The owner's design file"); its `windows-7-ui-elements/images/` holds the Windows 7 bitmaps of that file, among them DWM's atlas of the caption buttons and the frame's glass, which the frames module cuts its pictures from. To look through icons, render a contact sheet of the `.ico` files (Pillow, in the scratchpad) rather than reading the tables' Markdown. A file neither has (`hotplug.dll`) needs the Windows 7 install image: ask the owner.
- **Look there first.** For anything Windows 7 has a picture, sound or cursor for, use Windows 7's own (then Vista's). Windows' state pictures are whole icons; use the one Windows made for that state rather than laying a sign over another. Draw an imitation only when no original can be found, and say so in the decision log and in the report, naming the Windows file it would come from.
- **Each module copies what it uses into its own `resources/`**, which is committed; code never loads from `assets/`. Icons go to `resources/icons/<name>-<size>.png`, one file for each 32-bit frame the `.ico` has up to 48 px, taken as it is (`Image.open(ico).ico.getimage((size, size), 32).save(png)`, outside the repository), and `resources/icons/frames.js` lists them; `WindowsIcon` draws an icon at the frame made for its size. Sounds go to `resources/sounds/`, cursors to `resources/cursors/`. A name says what the picture is (`shield-warning`), not where it is used. Every file gets a line in the module's `resources/README.md`: name, source file and number, frames, what uses it. A changed copy is made from the original by a script and listed with what was changed.
- **Pictures, not tokens.** An original icon is used as it is in both themes, as Windows did; what is drawn around it still takes the tokens. A picture whose light edges read as a bright outline on Slate's dark panes gets a Slate copy made from the original by a script, and the JS that names the picture takes `Theme.slate`. This is HyprAero's exception to `.aero/STYLE.md`'s "icons drawn from the icon materials" for pictures Windows had; the start orb stays drawn.
- **Sounds:** a piece whose Windows 7 counterpart made a sound plays that sound, and sounds can be turned off (`.aero/PRINCIPLES.md` section 3). How they are played is chosen with the owner when the first one is added.
- **Licence:** these files are Microsoft's, kept for this personal project at the owner's request (2026-10-18). Copy only what a module uses, never the whole collection.

## 5. Rules shared by every module

- **Exception (glass):** HyprAero runs on Hyprland, which can blur what is behind a layer surface. Panels draw their glass tint, borders and shine themselves and **also** may ask the compositor for blur (Hyprland layer rules, namespace-based). Without compositor blur a panel must still be readable and recognisably Aero. Reason: HyprAero always runs on Hyprland; `.aero/STYLE.md` section 3 allows relying on it when documented like this. The rules a user needs go into the module's `README.md`.
- **Identifiers** (case follows the host, `.aero/FAMILY.md` section 2): app id `app.hyprAero.<module>`; layer namespaces `hypraero-<module>` or `hypraero-<module>-<part>`; IPC targets named after what they control. All modules share the config folder `~/.config/hypraero/` and the state folder `$XDG_STATE_HOME/hypraero/` (default `~/.local/state/hypraero/`), and each reads and writes only its own files there. Each module's `AGENTS.md` lists its identifiers.
- Respect the system: reduced-motion and reduced-transparency preferences, keyboard focus, multiple monitors. Never grab the keyboard without need. Startup is fast and silent; a failing piece logs and stays out of the way. No telemetry, no network calls but what a visible feature needs, each opt-in.
- **Not the same as the old AGS shell, technically** (`/home/sonicall/Downloads/AGSTest`, read-only, outside the repository): its `README.md` and behaviour say what HyprAero should do; nothing of its code is copied or translated.

## 6. Checks and running

```bash
node --test                    # the plain-JS logic
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml -import tests/qml/fakes    # primitives' behaviour
qmllint <files>                # QML errors and warnings, must be clean
```

- `tests/qml/fakes/` stands in for Quickshell: `Singleton` (a `QtObject` holding children), `Quickshell.Io`'s `Process` and `SplitParser` (never run anything, so the theme stays light) and `Quickshell.Widgets`' `IconImage`. `tests/qml/fakes/qs/design/qmldir` lists the real files as `qs.design`; add a line for each primitive a test needs. `Theme` and `SystemTheme` must both be listed as singletons there: a primitive finds them through its own folder, and Qt only treats a `pragma Singleton` file found that way as a singleton when a qmldir has registered that file as one.
- Drawing is not unit tested; looks are compared in offscreen renders of a module (its `AGENTS.md` section 6), never by restarting the running shell.

Run: nothing to run here; run a module. Build: none.

## 7. Design

The style is fully in `.aero/STYLE.md`; the layout and behaviour of each piece is in its module's `AGENTS.md`.

Tokens live in: `Theme.qml` (singleton; only the tokens in use so far, both themes; Slate is chosen by the system colour scheme through `SystemTheme`). Primitives live in this folder:

- Glass and surfaces: `GlassPanel` (kinds `window`, the family's pale glass, and `taskbar`, the shell's darker chrome), `BarGlass` (Windows 7's taskbar strip), `GlassText` (words in a glass's text colour), `GlassShine` (Windows 7's sharp-edged gloss over the top-left of the taskbar's glass buttons), `EtchedLine` (Windows 7's separator, fading out at both ends), `FlyoutFrame` (Windows 7's flyout over the notification area: a window-glass frame, a white body, the links in a band along the bottom), `GroupFrame` (Windows 7's group box: a rounded 2px frame the group's name breaks, its first letter underlined as the accelerator).
- Controls: `ControlButton` (kinds normal / accent / tool / danger and, on the taskbar glass, glass / glassTool; `highlighted`, `current`, keyboard focus, a flat grey disabled look), `CheckBox` (Windows 7's: a light gap and a sunken square inside the box), `RadioButton` (the check box's materials made round), `ChoiceBox` (a drop-down list whose list is a `MenuPanel`), `SearchField`, `TextField` (the search field's look without the magnifier; `hidden` for keys), `LinkText` (also light on the taskbar glass, `onGlass`), `ScrollBar` (Windows 7's vertical scrollbar: sunken track, a thumb with its own gloss running left to right, grip lines; drag, or press the track to page), `Slider` (Windows 7's trackbar: a sunken channel, a ramp, ticks, an aqua thumb, a plain grey one while `quiet` and without the keyboard; vertical, or turned for horizontal), `DropZone`.
- Menus, dialogs, tips: `MenuPanel` (Windows 7's icon margin closed by an etched line; items bold, indented on a tree line, with an icon, a tick and a submenu arrow), `PopupMenu` (a `MenuPanel` in a grabbing popup window, fading in rising and out sinking), `TaskDialog`, `Tooltip` (Windows 7's white to grey-blue face), `Balloon` (Windows 7's notification balloon: the tooltip's face and shadow, a stem standing against its wall on the top or bottom edge, `balloonShape.js`; a bold title with a 16px icon (or the generic app icon), a 48px picture left of the words, a flat close button, action buttons wrapping along the bottom; it only draws and reports clicks).
- Taskbar pieces: `TaskbarButton` (Windows 7's taskbar button: only the icon at rest, fading side lines, a bottom light and a light in the icon's colour following the pointer; `open` and `current` give an open app's button, `TaskbarItemFace`), `StartOrb` with `HyprlandMark` (a `highlighted` state lit like hover), `IconColorReader` (an icon's main colour, read from its pixels on a hidden canvas, `iconColor.js`), `AnalogClock` (drawn from the `clock-*` tokens, `clockHands.js`), `PictureFrame` (Windows 7's user tile: a silver glossy band, its sides bowed out), `Avatar` (`avatar.js`).
- Pictures and glyphs: `WindowsIcon` (one of Windows' own icons from the module's `resources/icons/`, at the frame Windows drew for its size; section 4.3), `StatusBadge` (a drawn corner sign: error cross, warning triangle, available star, busy disc, check, muted sign), `BatteryPicture` (the flyouts' 32px glossy pictures), `PixelGlyph` drawing the grids of `trayGlyphs.js` (`BatteryGlyph`, `DriveGlyph`, `BluetoothGlyph`, with pixel badges on their corner: the notification area's system icons not yet taken from Windows), `DotIcon`, `GenericAppIcon`, `AppIconImage`, `PowerIcon`, `CloseGlyph`, `MaximizeGlyph` (maximize, or restore's two boxes), `ReturnGlyph`, `ChevronGlyph`, `CaretGlyph` (a folding group's thin caret), `CheckGlyph`, `SearchGlyph`, `SortGlyph`, `StarGlyph`, `GripGlyph` (the dotted grip at the ends of the pins).

## 8. Roadmap and current state

Works today: every token and primitive above, both themes, used by the bar and (`Balloon`) the notifications module.

Next: whatever a module needs drawn next, added here when it is first drawn.

## 9. Decision log

The log lives in `DECISIONS.md`, one line per decision, newest last: `date - decision - reason`. Grep it for the topic before changing a rule. Design decisions made before this branch existed (up to 2026-10-24) are in the `bar` branch's `DECISIONS.md`.
