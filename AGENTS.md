# AGENTS.md

Single source of truth for any AI agent (or human) working on this project. Read it fully before changing anything. If a decision here turns out to be wrong, change this file in the same change that breaks the rule; never let the code and this file disagree.

## 0. Shared rules (read first)

This project belongs to the Aero family. Before this file, read all of these, fully:

- `design/.aero/PRINCIPLES.md`: philosophy, architecture rules, testing, how to work, documentation duty
- `design/.aero/CODE_STYLE.md`: formatting and typing rules
- `design/.aero/STYLE.md`: visual style and shared tokens
- `design/.aero/FAMILY.md`: how members of the family relate
- `design/AGENTS.md`: HyprAero's design (tokens, primitives) and the rules every HyprAero module shares: how the repository is built (a branch per module, `design/` a submodule), Windows' own assets, the glass exception, identifiers

This file only adds to them or narrows them. A deliberate exception is marked **Exception** and says why. Where this file is silent, they apply. Claude Code loads them through `CLAUDE.md`; any other agent must open the files itself. Where this file says `.aero/...`, it means `design/.aero/...`.

`design/` is a git submodule (the `design` branch), not a folder of this branch: a clone needs `--recurse-submodules` (or `git submodule update --init`), and a change to it is made and pushed on the `design` branch, then taken here by committing the new pointer (`design/AGENTS.md` section 2).

Working name: **HyprAero** (placeholder, final name not chosen); this branch is its `notifications` module. Identifiers (`design/AGENTS.md` section 5): app id `app.hyprAero.notifications`; D-Bus name `org.freedesktop.Notifications` (the standard server name, owned while running); layer namespace `hypraero-notifications`; in the shared config folder `notifications.json`.

## 1. What this is

HyprAero's **notification server**: it receives the notifications apps send (the freedesktop notification standard, what `notify-send`, browsers, chat apps and the system use) and shows them as Windows 7 Aero balloons. It runs on its own, with or without HyprAero's bar.

It is not a notification history app, not a do-not-disturb scheduler and not the bar's tray (tray icons asking for attention are the bar's, not notifications). Anything beyond showing, acting on and closing notifications is proposed to the owner first.

## 2. Place in the family

- Role: **addition** (a module of HyprAero; the base is the `bar`).
- Works without: the bar and every other module. Placement must never depend on the bar being there.
- Optional integrations: the bar, through documented interfaces only (`design/AGENTS.md` section 2). None is defined yet; the first one (if any, for example a balloon pointing at the bar's notification area) is designed with the owner and written here, versioned, with a fake.
- Target host: **Hyprland** on Wayland, Linux, any distribution. Only one program can own `org.freedesktop.Notifications`: while another server (mako, dunst, swaync, a desktop's own) has it, this module logs so and takes the name as soon as it is free (Quickshell's own behaviour, run and observed).

## 3. Tech stack

| Layer | Choice | Why |
| --- | --- | --- |
| Shell framework | **Quickshell** (QML) | The same as every HyprAero module; owner's decision. |
| Notification server | Quickshell's `NotificationServer` (`Quickshell.Services.Notifications`) | Reuse before writing: it owns the D-Bus name and speaks the standard. |
| Language | **QML** with typed properties, plain JS library scripts for logic; no TypeScript | As in the bar. |
| Design | The `design` branch as a git submodule at `design/` | Shared with every HyprAero module without copies. |

## 4. Architecture

### 4.1 Layout (created when first needed; do not add empty folders)

```
HyprAero/                       (the notifications branch)
    AGENTS.md  CLAUDE.md  README.md  DECISIONS.md  .gitignore
    .gitmodules                 design/ -> the design branch
    design/                     submodule: tokens, primitives, the kit (design/.aero/), rules shared by every module
    shell.qml                   entry point: makes the services and the balloon window exist
    services/                   state and logic, no drawing: Notifications.qml and Config.qml (singletons); settings.js,
                                balloons.js, notificationText.js, notificationIcon.js, notificationLog.js
    modules/                    BalloonWindow.qml (the layer surface), NotificationBalloon.qml (one balloon)
    resources/                  Windows' own pictures this module uses (design/AGENTS.md section 4.3): icons/, README.md
    tests/                      node tests (*.test.mjs)
```

### 4.2 Rules

- **Services and modules are separate**, as in the bar: `services/` holds state and decisions and draws nothing, `modules/` draws and reads services, and only a service talks to D-Bus or the system.
- **Logic out of QML.** What a notification turns into (its log line, its words, its icon and picture, its timeout, its place in the queue, where the balloons go) is decided in plain `.js` files with node tests.
- **The words of a notification never reach the log**, nor any error or crash line: a summary or body can be a private message or a one-time code (`.aero/PRINCIPLES.md` section 4). The log says what came (app, urgency, lengths, actions, picture), not what it said.
- **The design is not written here.** Tokens and primitives are the `design` branch's; a new token or primitive (the balloon itself) is added there.
- Config is the module's own file in the shared config folder (`notifications.json`, `services/Config.qml`, `services/settings.js`), read again when it changes and validated on load; a bad value falls back to its default and says so in the log.

## 5. Project-specific rules

- The glass exception, the rules for the system and the network are `design/AGENTS.md` section 5.
- Never take the keyboard: a notification appearing must not move focus from the app the user is typing in.
- Respect the notification standard: urgency, expire timeout, actions, `resident` and `transient` mean what the specification says; an app that asks to close its notification gets it closed.

## 6. Checks and running

```bash
node --test                    # plain-JS logic, this branch's and design/'s
qmllint <files>                # judge only new warnings: run standalone it cannot see Quickshell's generated qs.* modules
```

- The server is checked by running a copy in the scratchpad on a private session bus, never on the owner's: `env -u WAYLAND_DISPLAY dbus-run-session -- <script>` that starts `qs -p <copy>` offscreen (`QT_QPA_PLATFORM=offscreen`), waits with `gdbus wait --session org.freedesktop.Notifications`, sends with `notify-send` or `gdbus call ... Notify`, and reads the log and a `gdbus monitor` of the replies. Report it as "run and observed", never as "tested".
- `WAYLAND_DISPLAY` is taken away from the whole private bus, not only from `qs`: the theme follower asks the desktop portal, the private bus starts one, and the portal's Hyprland part otherwise connects to the owner's running Hyprland.
- `PanelWindow` needs Wayland, so the copy swaps `BalloonWindow`'s for a `FloatingWindow` (and drops its layer-shell lines); `grabToImage` of the column of balloons shows them. Offscreen, the fake pointer rests on the window, so every balloon counts as hovered and never expires; a copy that checks timeouts leaves the hover out of the timer's condition. Shader effects (the shadow) draw only with `QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl` and in a grab of the item's parent.
- QML tests (`qmltestrunner`, fakes in `tests/qml/fakes/`, as in the bar) come with the first component worth testing.

Run: `qs --path=./` from the project root. Build: none. Logs: `qs log`; stop: `qs kill`.

## 7. Design

Each notification is Windows 7's notification balloon (`design/Balloon.qml`, `.aero/STYLE.md` "Notification balloons"): the tooltip's white to grey-blue face, a stem, a bold title of at most 63 characters with its 16px icon, the words under it (at most 255 characters), a flat close button at the top right. Placed and timed as Windows 7 places and times them, with the position a setting:

- **Where** (`balloons.position`, default `bottom-right`): a corner, the middle of an edge or the centre of the screen, `balloons.margin` pixels from its edges. The window is a layer surface that keeps out of the room other bars reserve, so with a taskbar at the bottom the balloons sit above it, as on Windows 7, without depending on the bar. The screen is the one named in `balloons.monitor`, else the focused one (Hyprland).
- **The stem** points at the corner the balloon sits in, on its upright "wall" side (down at the right in the default bottom right, where the notification area is); centred in the middle of the top or bottom edge; none in the middle row, which has nothing to point at, or with `balloons.stem` off. In a stack only the balloon nearest the edge has it.
- **How many** (`balloons.maxVisible`, default 1): Windows 7 shows one balloon and queues the rest, the next appearing when it closes. More than 1 gives a stack: the oldest that many, the newest of them nearest the edge.
- **How long**: what the app asks for; when it leaves it to the server, `balloons.timeout` (default 5000 ms, Windows 7's default); never for a critical notification the app left to the server, as the standard asks. The pointer resting on a balloon holds it and the time starts again when it leaves. It fades in and out (`motion-soft`); the pointer coming back while it fades out brings it back. Expired, the app is told so (reason 1).
- **Clicks and actions**: every action the app gives is a button along the bottom, in its order, wrapping onto more rows; the first is the main one (accent), as in the old AGS shell. The "default" action is a button too ("Open" when the app gave it no words), and a click on the balloon also does it (else dismisses it); the close button dismisses it (reason 2). Invoking an action closes the balloon unless the app made it resident. All of these close at once, without fading.
- **Words**: plain text. The server tells apps it takes no markup, and markup sent anyway is cleaned (tags out, entities turned back into characters, `services/notificationText.js`).
- **Icon and picture** (`services/notificationIcon.js`): the app's icon (16px, before the title): the standard message icons (`dialog-information`, `-warning`, `-error`, `-question`) are Windows 7's own (`resources/icons/`); any other is the app's from its path or the icon theme, else its desktop entry's, else the design's generic app icon. A picture sent with the notification (a chat avatar, an album cover) shows as well, 48px left of the title and the words, where Windows put its large icon; an image that is only an icon's name (`notify-send -i`) counts as the icon.
- **Errors never carry words**: Quickshell's JavaScript engine lacks some of node's methods (`tests/engine.test.mjs` lists them and checks no script uses them), and its error messages quote the string a call was made on, which can be a notification's words. Preparing the words is wrapped: a failure logs the notification's number and the error's kind only.

The old AGS shell (`/home/sonicall/Downloads/AGSTest`) was the reference for what a notification needs (actions, cleaned markup, cut text, pictures, icon resolution); its look and its stack are replaced by Windows 7's.

Tokens live in: `design/Theme.qml`. Primitives live in: `design/` (listed in `design/AGENTS.md` section 7).

## 8. Roadmap and current state

Works today: the server and its balloons as in section 7, the config file. The server owns `org.freedesktop.Notifications`, keeps each notification until it expires, is closed or its app closes it, and writes a line about each one to the log (`services/notificationLog.js`).

Not built yet, roughly in this order (each decided with the owner first):

1. Holding balloons while the user is away (Windows 7 does not count the time while nobody uses the computer), and a do-not-disturb switch, if wanted.
2. Inline replies (the standard's `inline-reply`), if wanted.
3. Settings window.
4. Sounds (Windows 7's "Windows Balloon" sound), if the owner wants them.
5. Any interface with the bar (for example a balloon pointing at the bar's notification area icon of the app).

## 9. Decision log

The log lives in `DECISIONS.md`, one line per decision, newest last: `date - decision - reason`. Grep it for the topic before changing a rule, and append new decisions there in the same change.
