# HyprAero design

The look of HyprAero, a Windows 7 (Aero) style desktop for Hyprland built on [Quickshell](https://quickshell.org): the colours and other design values of both themes (Aero light and Slate dark, following the system's colour scheme), and the pieces every HyprAero module draws with (glass panels, buttons, menus, flyout frames, sliders, check boxes, glyphs, ...).

This branch is not something to install or run by itself. Every HyprAero module includes it, and installing a module brings it along. See the `main` branch for the list of modules and how to install each.

## How a module uses it

Each module branch has this branch as a git submodule in its `design/` folder, so the module's code imports it as `qs.design`:

```qml
import qs.design

ControlButton {
    kind: 'accent'
    text: 'OK'
}
```

Cloning a module with `--recurse-submodules` fills `design/` in. In a clone made without it, run `git submodule update --init`.

## Changing it

| I want to... | Commands |
| --- | --- |
| Change the design from inside a module | `cd design && git switch design && git pull`, edit, `git commit`, `git push`; then in the module: `git add design && git commit -m 'Take design changes' && git push` |
| Bring the newest design into a module | `git submodule update --remote design && git add design && git commit -m 'Take design changes'` |
| Work on this branch alone | `git worktree add ../HyprAero-design design` from any clone |

A module only sees a design change once its `design` pointer is moved and committed, so a change here never breaks a module behind its back. Setting `git config submodule.recurse true` and `git config push.recurseSubmodules on-demand` in a clone makes `git pull` update `design/` too and makes `git push` push a design commit before the module commit that points at it.

## Checks

```bash
node --test
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml -import tests/qml/fakes
```

The rules for working on it are in `AGENTS.md`, and the family's shared rules and design values are in `.aero/`.
