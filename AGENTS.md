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

Working name: **HyprAero** (placeholder, final name not chosen); this branch is its `notifications` module. Identifiers (`design/AGENTS.md` section 5): app id `app.hyprAero.notifications`; D-Bus name `org.freedesktop.Notifications` (the standard server name, owned while running); layer namespace `hypraero-notifications` (when the balloons come).

## 1. What this is

HyprAero's **notification server**: it receives the notifications apps send (the freedesktop notification standard, what `notify-send`, browsers, chat apps and the system use) and will show them as Windows 7 Aero balloons. It runs on its own, with or without HyprAero's bar.

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
    shell.qml                   entry point: makes the services and (later) the balloon windows exist
    services/                   state and logic, no drawing (singletons): Notifications.qml, notificationLog.js
    modules/                    the balloons, when they come
    resources/                  Windows' own pictures and sounds this module uses, when it uses any (design/AGENTS.md section 4.3)
    tests/                      node tests (*.test.mjs)
```

### 4.2 Rules

- **Services and modules are separate**, as in the bar: `services/` holds state and decisions and draws nothing, `modules/` draws and reads services, and only a service talks to D-Bus or the system.
- **Logic out of QML.** What a notification turns into (its log line now; later its words, its picture, its timeout, its order) is decided in plain `.js` files with node tests.
- **The words of a notification never reach the log**, nor any error or crash line: a summary or body can be a private message or a one-time code (`.aero/PRINCIPLES.md` section 4). The log says what came (app, urgency, lengths, actions, picture), not what it said.
- **The design is not written here.** Tokens and primitives are the `design` branch's; a new token or primitive (the balloon itself) is added there.
- Config (when there is any) is the module's own file in the shared config folder, validated on load; a bad value falls back to its default and says so.

## 5. Project-specific rules

- The glass exception, the rules for the system and the network are `design/AGENTS.md` section 5.
- Never take the keyboard: a notification appearing must not move focus from the app the user is typing in.
- Respect the notification standard: urgency, expire timeout, actions, `resident` and `transient` mean what the specification says; an app that asks to close its notification gets it closed.

## 6. Checks and running

```bash
node --test                    # plain-JS logic, this branch's and design/'s
qmllint <files>                # judge only new warnings: run standalone it cannot see Quickshell's generated qs.* modules
```

- The server is checked by running a copy in the scratchpad on a private session bus, never on the owner's: `dbus-run-session -- <script>` that starts `qs -p <copy>` offscreen (`env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen`), waits with `gdbus wait --session org.freedesktop.Notifications`, sends with `notify-send` or `gdbus call ... Notify`, and reads the log and a `gdbus monitor` of the replies. Report it as "run and observed", never as "tested".
- QML tests (`qmltestrunner`, fakes in `tests/qml/fakes/`, as in the bar) come with the first component worth testing.

Run: `qs --path=./` from the project root. Build: none. Logs: `qs log`; stop: `qs kill`.

## 7. Design

Not designed yet: the look and behaviour of the balloons are planned with the owner as the next task. The direction (`.aero/STYLE.md`, the bar's `AGENTS.md` section 7.2) is Windows 7's notification balloons, in the family's style. The old AGS shell (`/home/sonicall/Downloads/AGSTest`: `widget/Notifications.tsx`, `service/notifications.tsx`, its `README.md` "Notifications Window") is the reference for what worked: a stack shown only while there are notifications, its corner and margins set in the config, newest nearest the screen edge, a click on a card dismisses it, actions as buttons (the first one the main one), markup in the text cleaned, long text cut, an attached picture shown, and careful resolution of the app's icon.

Tokens live in: `design/Theme.qml`. Primitives live in: `design/` (listed in `design/AGENTS.md` section 7).

## 8. Roadmap and current state

Works today: the server. It owns `org.freedesktop.Notifications` on the session bus, answers `GetServerInformation` (as Quickshell), and writes a line about each notification to the log (`services/notificationLog.js`). Nothing is shown and nothing is kept, so Quickshell tells the app its notification was dismissed as soon as it arrives.

Not built yet, roughly in this order (each decided with the owner first):

1. The balloon: its look (a design primitive), where it appears with and without the bar, how many at once, timeouts.
2. Actions, closing, and the app's icon and picture.
3. The module's config file and its settings.
4. Sounds (Windows 7's), if the owner wants them.
5. Any interface with the bar.

## 9. Decision log

The log lives in `DECISIONS.md`, one line per decision, newest last: `date - decision - reason`. Grep it for the topic before changing a rule, and append new decisions there in the same change.
