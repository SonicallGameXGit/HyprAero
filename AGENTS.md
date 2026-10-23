# AGENTS.md

Single source of truth for any AI agent (or human) working on this project. Read it fully before changing anything. If a decision here turns out to be wrong, change this file in the same change that breaks the rule; never let the code and this file disagree.

## 0. Shared rules (read first)

This project belongs to the Aero family. Before this file, read all of these, fully:

- `.aero/PRINCIPLES.md`: philosophy, architecture rules, testing, how to work, documentation duty
- `.aero/CODE_STYLE.md`: formatting and typing rules
- `.aero/STYLE.md`: visual style and shared tokens
- `.aero/FAMILY.md`: how members of the family relate

This file only adds to them or narrows them. Where it is silent, the kit applies. Claude Code loads the kit through `CLAUDE.md`; any other agent must open the files itself.

Working name: **HyprAero** (placeholder, final name not chosen). Identifiers (case follows the host, see `.aero/FAMILY.md` section 2): app id `app.hyprAero.shell`; layer namespaces `hypraero-<module>` (`hypraero-bar`, `hypraero-drop`, `hypraero-notifications`, ...); config folder `~/.config/hypraero/`; state folder `$XDG_STATE_HOME/hypraero/` (default `~/.local/state/hypraero/`); IPC target `startMenu` (`qs ipc --path <shell folder> call startMenu toggle|open|close`).

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
    assets/                     git-ignored, local reference only: `assets/aero/` (export of the owner's Figma mockups), `assets/windows-ui-assets-main/` (Windows' own icons, sounds, cursors; section 4.3)
    resources/                  files the shell loads that are not code: Windows' own icons (and later sounds, cursors) copied from `assets/`, indexed in `resources/README.md`
    tools/                      one-shot QML programs the shell runs as processes of their own (`qs -p`, offscreen)
```

### 4.2 Rules

- **Services and modules are separate.** `services/` holds state and decisions and draws nothing; `modules/` draws and reads services. A module never talks to Hyprland, D-Bus or the system directly, only through a service.
- **Every module is optional.** Each can be turned off in the config without breaking the others.
- **One token file.** `design/Theme.qml` is the only place visual values are written (`.aero/STYLE.md` section 4, camelCase property names). Primitives live in `design/` and are reused by every module.
- **Config is validated on load**, a bad value falls back to its default and tells the user (notification or log), never crashes the shell.
- **Not the same as the AGS version, technically.** Nothing is copied from the old code. Its README and behaviour are the reference for *what the shell should do*; how it is done is decided fresh under these rules.

### 4.3 Windows' own assets (icons, sounds, cursors)

The shell imitates Windows 7, and the owner keeps Windows' originals for it. **Every agent reads this before drawing an icon, adding a sound or a cursor.**

- **Where they are:** `assets/windows-ui-assets-main/` (git-ignored, on the owner's machine only; a copy of https://github.com/bartekl1/windows-ui-assets). Icons of Windows XP to 11 as `Icons/<version>/ico/<dll>/ICON<n>_1.ico` (every size Windows has, 16 to 256 px; the dlls themselves in `Icons/<version>/dll/`), sounds as `Sounds/<version>/*.wav`, cursors in `Cursors/<version>/`, wallpapers in `Wallpapers/<version>/`. `Tables/<version> Icons.md` shows every icon with its number, which is how an icon is named; the collection's `README.md` says where in Windows each kind comes from. To look through them, render a contact sheet of the `.ico` files (Pillow, in the scratchpad) rather than reading the tables' Markdown.
- **Windows 7's other system files:** that collection only has `imageres.dll` and `shell32.dll`. Icons Windows keeps elsewhere (the notification area's network icon, the network flyout's pictures and many more) come from `assets/windows7-sp1/` (git-ignored): Windows 7's own files taken out of Microsoft's Service Pack 1 package from Microsoft's update servers (its `README.md` gives the address, the SHA-1 and how to unpack it; nothing in it is run). Already there: `pnidui.dll` (network icon), `van.dll` (network flyout), `netcenter.dll`, `netshell.dll`, `sndvolsso.dll` (volume), `batmeter.dll` (battery), `bthprops.cpl` (Bluetooth), the dlls in `dll/` and every icon group of them as `ico/<file>/ICON<id>.ico` (numbered by resource id), with the tools that made them in `tools/` (`icoex.py` takes a dll's icons out, `sheet.py` draws a contact sheet). Another file SP1 updated is taken from the same package the same way; one it did not update (`hotplug.dll`, Safely Remove Hardware) needs the Windows 7 install image, so ask the owner for it.
- **Look there first.** For anything Windows 7 has a picture, sound or cursor for, use Windows 7's own, from the collection or `assets/windows7-sp1/` (then Vista's, which shares most of it). Windows' state pictures are whole icons (the network icon with its warning sign, each frame of an animation), so use the one Windows made for that state rather than laying a sign over another. Draw an imitation only when no original can be found, say so in the decision log and in the report, and name the Windows file it would come from.
- **Copy what is used into `resources/`**, which is committed; code never loads from `assets/` (it is not in the repository). Icons go to `resources/icons/<name>-<size>.png`, one file for each 32-bit frame the `.ico` has up to 48 px, taken as it is (Windows draws each size by hand; a smaller frame is never made by shrinking a bigger one), and `resources/icons/frames.js` is written again to list them; `design/WindowsIcon.qml` draws an icon at the frame made for its size. Taking a frame out (Pillow, outside the repository): `Image.open(ico).ico.getimage((size, size), 32).save(png)`. Sounds go to `resources/sounds/`, cursors to `resources/cursors/` when the first one is needed. A name says what the picture is (`shield-warning`, `network-wifi-3`), not where it is used. Every file gets a line in `resources/README.md`: name, source file and number, frames, what uses it. A changed copy of an original (recoloured, combined, cut) is made from the original file and listed the same way, with what was changed. Which picture a state shows is decided in plain JS (as `iconName` in `services/network.js`) and a node test checks every name it can give is in `frames.js`.
- **Pictures, not tokens.** An original icon is used as it is in both themes, as Windows did; what is drawn around it (frames, badges, bars) still takes the tokens. The exception is a picture Windows drew for its white panes whose light edges read as a bright outline on Slate's dark ones: it gets a Slate copy made from the original by a script kept in `assets/windows7-sp1/tools/` (as `signal-bars-slate-*`, by `slatebars.py`), listed in `resources/README.md`, and the JS that names the picture takes `Theme.slate`. Check every new picture on both themes' panes. This is the project's exception to `.aero/STYLE.md`'s "icons drawn from the icon materials" for pictures Windows had; the start orb stays drawn (`.aero/STYLE.md` "Start orb").
- **Sounds:** a piece whose Windows 7 counterpart made a sound (a notification balloon, a device plugged in or removed, low battery, an error dialog) plays that sound from `resources/sounds/`, and sounds can be turned off in the config (`.aero/PRINCIPLES.md` section 3). How they are played (Qt Multimedia or a player program) is chosen with the owner when the first one is added; no sound plays yet.
- **Licence:** these files are Microsoft's, kept for this personal project at the owner's request (decision log, 2026-10-18). Copy only what a feature uses, never the whole collection.

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
- A component that only needs Qt Quick and services can be tested headless with `qmltestrunner` (`tests/qml/`): the services it imports are replaced by fakes in `tests/qml/fakes/qs/services/`, which only need what the tested component uses. The real design files are reachable as `qs.design` (`tests/qml/fakes/qs/design/qmldir`; add a line for each one a test needs), with `Quickshell`'s `Singleton` stood in for so `Theme.qml` loads. Other Quickshell types (windows, Hyprland) are not available there.
- Drawing and system integration (layer surfaces, tray, PipeWire) cannot be unit tested; they are checked by running the shell and reading its log. Report them as "run and observed", never as "tested".
- `node --test` also runs the QML tools of `tools/` through real `qs` on Qt's offscreen platform (skipped when `qs` is missing), as the shell does.
- Looks are compared in offscreen renders of a copy of the shell in the scratchpad (a `shell.qml` that builds the pieces and saves `grabToImage` pictures), never by restarting the running shell. Shader effects (`MultiEffect`, `RectangularShadow`) draw there only on the GPU: `env -u WAYLAND_DISPLAY QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl QT_QPA_PLATFORM=offscreen qs -p <copy>`; the default offscreen renderer is Qt's software one, which leaves them out, and an effect shows in a grab of the item's parent, not of the item that carries it. `PanelWindow` needs Wayland, so a render of the bar swaps it for a `FloatingWindow` in the copy.
- Editor support: `qmlls` (in Qt's bin folder, `/usr/lib/qt6/bin/qmlls`) gives completion and diagnostics.

Run: `qs --path=./` from the project root. Build: none (there is nothing to build). Logs: `qs log`; stop: `qs kill`. Other forms of `qs` (named configs in `~/.config/quickshell/`) are not used; do not add variants.

## 7. Design

The **style** is fully in `.aero/STYLE.md`. This section is the **design** of the shell: what is placed where and how it behaves. The old shell is the base, not the template: keep what worked, change what the owner finds wrong, ask when unsure.

### 7.1 Pieces carried over from the old shell (behaviour to preserve in spirit)

- **Top bar**: workspaces, tray, keyboard-layout indicator, clock with calendar.
- **Workspaces**: shows the focused workspace, the main app icon of each workspace and a second indicator for multi-window ones; hovering a workspace lists its windows (icon, name, close button), and windows can be dragged between workspaces; windows can be given a display name and icon override.
- **App launcher**: opens anchored near the workspaces, keyboard navigable, ranks results by usage. Rebuilt as the start menu (section 9); its "Featured" / "Most used" sections and star toggles are kept, its ranking is replaced.
- **Volume panel**: interactive (drag and scroll), shown from a screen-edge zone.
- **Notifications**: a notification window with action buttons and reliable app-icon resolution; configurable from a JSON file.
- **Runtime config and state files** for the things above.

### 7.2 Direction

- The Windows 7 language is the target: a taskbar-like bar with glossy glass, a start-menu-like launcher, a calendar / clock flyout, a volume flyout, Aero balloon-style notifications. The bar defaults to the bottom edge and its position is a user setting (section 5).
- Anything above that is new needs a proposal first (`.aero/PRINCIPLES.md` section 2).

Tokens live in: `design/Theme.qml` (singleton; only the tokens in use so far, both themes, Slate is chosen by the system colour scheme). Primitives live in: `design/` (`GlassPanel` (kinds `window`, the family's pale glass, and `taskbar`, the shell's darker chrome), `BarGlass` (the bar's own glass, Windows 7's taskbar strip), `GlassText` (words in a glass's text colour), `EtchedLine` (Windows 7's separator, fading out at both ends), `ControlButton` with kinds normal / accent / tool / danger and, on the taskbar glass, glass / glassTool (lit as glass, `glass-button-*`), a `highlighted` state (looks hovered), a `current` state (the selected one on glass), keyboard focus and a flat grey disabled look, `DotIcon`, `GenericAppIcon`, `AppIconImage`, `CloseGlyph`, `MaximizeGlyph` (maximize, or restore's two boxes), `ReturnGlyph`, `ChevronGlyph`, `SearchGlyph`, `SortGlyph`, `StarGlyph`, `PowerIcon`, `Avatar`, `PictureFrame` (Windows 7's user tile: a silver glossy band, its sides bowed out, around a picture with rounded corners), `StartOrb` with `HyprlandMark` (a `highlighted` state lit like hover), `SearchField`, `MenuPanel` (Windows 7's icon margin closed by an etched line, separators starting after it; items can be bold, the default, or indented on a tree line, an app's actions; they can carry an icon, a tick (check mark or radio dot) and a submenu arrow), `CheckGlyph`, `CheckBox` (Windows 7's: a light gap and a sunken square inside the box, light blue under the pointer, deeper blue pressed), `ChoiceBox` (a drop-down list whose list is a `MenuPanel` of the owner), `LinkText` (also light on the taskbar glass, `onGlass`), `ScrollBar` (Windows 7's vertical scrollbar for a list: sunken track, a thumb with its own gloss running left to right (blue under the pointer and while held), grip lines; drag, or press the track to page), `TaskDialog`, `Tooltip` (Windows 7's white to grey-blue face), `DropZone`, `DragSource` (drags a window, workspace, app or tray icon out to the bar's drop layer), `GripGlyph` (the dotted grip at the ends of the pins), `AnalogClock` (the flyout's round clock, drawn from the `clock-*` tokens), `PopupMenu` (a `MenuPanel` in a grabbing popup window of its own, fading in rising and out sinking: the bar's right-click menus and the tray flyout's system icons), `TaskbarButton` (Windows 7's taskbar button: only the icon at rest, fading side lines, a bottom light and a light in the icon's colour following the pointer under it, a darker middle pressed; `open` and `current` give an open app's button, `TaskbarItemFace`), `GlassShine` (Windows 7's sharp-edged gloss over the top-left of the taskbar's glass buttons and the Show desktop block), `IconColorReader` (an icon's main colour, read from its pixels on a hidden canvas, `services/iconColor.js`), `FlyoutFrame` (Windows 7's flyout over the notification area: a window-glass frame, a white body, the links in a band along the bottom; the clock, volume, network, power and hidden-icons flyouts), `Slider` (Windows 7's trackbar: a sunken channel, a ramp widening towards the most, ticks, an aqua thumb pointing at the ramp, a plain grey one while `quiet` and without the keyboard; vertical, or turned for horizontal), `GroupFrame` (Windows 7's group box: a rounded 2px frame the group's name breaks, its first letter underlined as the accelerator), `BatteryPicture` (the flyouts' 32px glossy pictures), `CaretGlyph` (a folding group's thin caret), `RadioButton` (the check box's materials made round), `TextField` (the search field's look without the magnifier; `hidden` for keys), `WindowsIcon` (one of Windows' own icons from `resources/icons/`, at the frame Windows drew for its size; section 4.3), `StatusBadge` (a drawn corner sign: error cross, warning triangle, available star, busy disc, check, muted sign), and the notification area's system icons not yet taken from Windows (the network's and the volume's are Windows' own, through `WindowsIcon`) as Windows 7's 16px pixel drawings (`PixelGlyph` drawing the grids of `design/trayGlyphs.js`: `BatteryGlyph`, `DriveGlyph`, `BluetoothGlyph`, with pixel badges on their corner)).

## 8. Reference: the previous shell

Location: `/home/sonicall/Downloads/AGSTest` (AGS + Astal, TypeScript, SCSS). Read-only reference, outside this repository. Useful files: `README.md` (complete user manual of the old behaviour), `widget/` (Bar, VolumeIndicator, Notifications), `service/`, `config.ts` (config schema), `style.scss`.

Its technology is explicitly **not** carried over: no GJS, Astal, GTK widgets, SCSS or TypeScript code is copied or translated line by line. Its own `AGENTS.md` and style rules are superseded by the kit.

## 9. Roadmap and current state

Works today: a bar per screen (bottom, glass, namespace `hypraero-bar`) with centered workspace buttons (48px bar): click to switch; each button shows a dot (empty), the app icon (one app) or the biggest app's icon with the second biggest as a small badge, or only the icon the user gave the workspace (empty too, then without the open button's face); the buttons (and the pins) are Windows 7's taskbar buttons (`design/TaskbarButton.qml`: a light in the icon's main colour, `services/iconColor.js`, follows the pointer), one with windows an open app's button, the current one brighter, fading in and out; hovering a workspace with windows opens a popup of live window previews (icon, title, picture) biggest first, sitting on top of the bar. Each preview card lights up on hover, goes to its window on click (workspace and focus; the pointer is not moved) and has a maximize / restore button (floats a tiled window, tiles a floating one) and a close button that asks the app to close. Resting on a card (`bar.peekDelay`, 500ms) or, for twice as long, on a workspace button peeks (`services/Peek.qml`, `services/peek.js`, `modules/bar/PeekLayer.qml`, `PeekScene.qml`, `PeekWindow.qml`, layer `hypraero-peek`): the workspace drawn as if shown, live, windows at their real places, the hovered one lit and the rest darkened (a fullscreen or lone tiled window is lifted out in a glass frame instead), faded between pictures. A card can be dragged to move its window to another workspace (the view stays): onto a button, beside the buttons (leftmost / rightmost free workspace) or higher up the screen (lowest free one), with the target button lit during the drag. A workspace button with windows is dragged sideways to reorder it among the others, as Windows 7 reorders its buttons (`modules/bar/WorkspaceStrip.qml`: the others glide aside, it stops at the pins and the tray, it glides into its slot; `Workspaces.reorder` renumbers the workspaces between through a spare number, `reorderPlan` in `services/workspaceList.js`, so each keeps its layout); covering a third of another button for 400ms it joins it instead, as a browser tab (`joinCandidate`, the moving unchanged; that one lights up, let go its windows go there, `Workspaces.moveWorkspace`). Every other drag leaves a glass "Put back" slot where it was taken from; dropping back on it changes nothing. A block at the right end of the bar, drawn as Windows 7's "Show desktop", goes to the first workspace without windows. Workspaces 1-10 are always shown; clicking an empty one creates it (Hyprland does that on focus). The theme follows the system colour scheme live.

A start orb at the bar's left end (drawn, Hyprland mark), bigger than the bar and centred on it as in Vista, opens the start menu (`modules/startmenu/`, both popups of `hypraero-bar`; the menu sits on the orb's top), Windows 7's layout read from the top: a white pane with "Featured" and the starred apps (by use), a dark line, "Most used" and the other used apps (by use), another line and the rest (A to Z), the search field under it, each row with the app's description (or program) under its name; search ranks by where the text is found, then use; a star on each row features it, an app with desktop actions has an arrow button joined to its row that shows them in the right column in place of the places, the menu growing wider (`ActionsPane`; opened by a click or by resting on the arrow, kept while the pointer is on the app or on them, switched at once onto another app with actions, closed a moment after leaving), a right click offers the actions, featuring, "Forget usage" and "Change icon...". An app row can be dragged out with the same drop places as a preview card to start the app on that workspace, the view staying (Hyprland is asked, and new windows of the app are moved there for a while in case it cannot tell); the menu stays open with a "Put back" ghost in the row's place, and a drop anywhere on it puts the app back. The list's scrollbar can be hovered, dragged and pressed. Config file `~/.config/hypraero/config.json` (`services/Config.qml`, validated live), with `startMenu.touchControls` (drag scrolls, hold picks up) and `startMenu.countFocus`. The right column on the glass: user picture (or drawn avatar; the pointed place's icon; a click chooses a new one in zenity's file chooser, saved as `~/.face` cut square and shrunk to 256px by `tools/shrinkPicture.qml`), name (home), the XDG folders, Computer, Terminal, and "Shut down" with a menu (Restart, Sleep, Lock, Log out); leaving the session asks first in a task dialog. Keyboard: typing searches, arrows move (through the open actions once they have the keyboard), Tab (or Right / Left with no text) opens and closes actions, Enter starts, Escape clears then closes. Right of the orb, between two dotted grips, the pinned apps (Vista's Quick Launch, `modules/bar/PinBar.qml`, `services/Pins.qml`, kept in `pins.json` in the state folder): click starts, right click gives the app, its actions, "Change icon..." and "Unpin from bar"; an app from the start menu, a preview card or a pin dropped there is pinned at the glowing mark (a pin moves). A preview card's right click gives Focus, Fit into layout, Float freely, Pin to bar, Change icon... and Close (`design/PopupMenu.qml`); a workspace button's gives Go to workspace and Change icon.... Usage is "frecency" (`services/appUsage.js`), counted from launches and from focus (`services/Apps.qml`), kept in the state folder.

The Icon Manager (`modules/icons/IconManager.qml`, Windows 7's "Change Icon", a window of its own; `services/IconOverrides.qml`, decisions in `services/iconOverrides.js`), opened by "Change icon..." in those menus, gives an app (desktop entry id: its pin, its start menu row, every window of it), a window (Hyprland address, forgotten when it closes) or a workspace (number; follows its button through a reorder, not through a join) another icon. It lists every icon theme's files (`find` over the XDG icon folders and `/usr/share/pixmaps`, read once a session; Qt resolves names only in its own theme, often hicolor alone, so an icon is kept as a file path), narrowed by theme ("Look for icons in") and by name; "Browse..." (zenity) picks a picture, copied on OK into `icons/` in the state folder, a copy nothing uses deleted. Kept in `icons.json` in the state folder.

The notification area (`modules/tray/`, `services/Tray.qml`, `services/tray.js`), after Windows 7's, sits left of the right-end strip: the StatusNotifierItem icons of apps (16px on tool buttons), click activates, right click opens the app's DBus menu drawn as a family menu (`TrayMenu`, ticks, icons and submenus as popups of their menu), middle click and wheel go to the app. Each icon remembered in `tray.json` in the state folder has a behaviour: shown, hidden, or "only notifications" (the default: hidden, on the bar while it needs attention). Hidden icons wait behind the "Show hidden icons" arrow in a flyout (`TrayFlyout`, a grid as square as it can be, "Customize..." under it); icons are dragged between the bar and the flyout and along either, with the drop mark and "Put back" slot of the other drags; a tray icon over the arrow opens the flyout. "Customize..." opens the "Notification Area Icons" page (`TrayCustomize`, a window of its own): every icon ever seen with its behaviour, "Restore default icon behaviors" and "Always show all" (`tray.showAll` in the config file, which the shell can now write: `Config.set`), also reached while nothing is hidden: the arrow then stays, turned to point right at the icons, and opens the page itself; and from the bar's own menu (a right click on its empty glass: "Customize notification icons..."). The tray's StatusNotifierWatcher lives in `tools/trayWatcher.qml`, a process of its own the shell starts when the bus has none. The clock (`modules/clock/`, `services/Clock.qml`, `services/calendar.js`) sits right of the notification area, left of the right-end strip: the time over the short date on a glass tool button, the long date as its tooltip; a click opens a flyout over it (`ClockFlyout`, a grabbing popup of the bar) with the long date, Windows 7's calendar on a white pane (`CalendarPane`: month, months of a year and years of a decade, arrows and wheel) and the drawn analog clock (`design/AnalogClock.qml`) with the time and its seconds. Formats follow the system locale. No date and time settings link yet (the shell has no settings window).

The notification area has Windows 7's system icons (`services/SystemIcons.qml`, pictures in `modules/tray/SystemIconPicture.qml`, flyouts and windows in `modules/system/`), items of the tray like an app's (keys `system:<name>`), so they are dragged, hidden and customised the same way: volume (`services/Volume.qml`, PipeWire: a flyout with the slider and mute, the wheel and a middle click on the icon, a menu choosing the output device, the Volume Mixer window), network (`services/Network.qml`, NetworkManager through Quickshell's Networking: wired / Wi-Fi icon with Windows 7's signs, a flyout listing Wi-Fi networks to connect to (the key typed in place) or disconnect, nm-connection-editor for the rest), power (`services/Power.qml`, UPower and power-profiles-daemon, only with a laptop battery: Windows 7's battery words and the power plans), Safely Remove Hardware (`services/Drives.qml`, lsblk and udisksctl: eject a mounted plugged-in drive, a "Problem Ejecting" window when it is in use) and Bluetooth (`services/BluetoothDevices.qml`, BlueZ: a menu with the paired devices, the adapter and "Add a device" in a window of its own). The decisions are in `services/network.js`, `volume.js`, `power.js`, `drives.js`, `bluetooth.js`. The "Notification Area Icons" page has Windows 7's "Turn system icons on or off" page (the clock and each system icon on or off, `tray.*Icon` and `tray.clock` in the config file) and the switch that leaves out applets the system icons replace (`tray.hideSystemApps`: nm-applet, blueman, pasystray, udiskie, ... by StatusNotifierItem id). No Action Center and no language bar yet (proposed, not built). No settings window and no other modules yet.

Not built yet, roughly in this order (steps 1, 3, 5 and 6 and most of 2 are done):

1. Verify Quickshell is installed and a minimal `shell.qml` runs on Hyprland; write the run command into section 6.
2. `design/Theme.qml` from `.aero/STYLE.md`, both themes, plus the first primitives (glass window, button, icon).
3. Bar with workspaces, clock, tray.
4. Notifications (server and balloon).
5. Launcher (done as the start menu).
6. Volume / system flyouts (done as the tray's system icons; Action Center and the language bar are proposed, not built).
7. Config file (started: the file and its first settings) and settings window.

## 10. Decision log

The log lives in `DECISIONS.md` (project root), one line per decision, newest last: `date - decision - reason`. It is not loaded automatically: before changing a rule, a design choice or anything with history, grep it for the topic (`rg -i '<topic>' DECISIONS.md`) and read the matching entries. Append every new decision there in the same change (`.aero/PRINCIPLES.md` section 7).
