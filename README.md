# HyprAero frames

Windows 7 window frames for Hyprland, part of HyprAero, a Windows 7 (Aero) style desktop for Hyprland. Every window gets Windows 7's glass frame, its icon and title, and the Maximize and Close buttons, drawn by Hyprland itself so the frame always sits and moves with its window. It works on its own, with or without HyprAero's bar.

## State

**Early.** What works:

- Windows 7's frame around every window: see-through glossy glass with Windows 7's streaks, lighter for the active window and paler for the others. Rounded corners on floating windows, square ones on windows in the layout.
- The app's icon and the window's title in the middle of the top band. Long titles are cut short with "…".
- Maximize and Close, Windows 7's own buttons: they glow under the pointer, and Close turns red. A click acts when you let go over the same button. A window in Hyprland's layout counts as maximized: Maximize puts a floating window into the layout, and on a window in the layout it shows Restore, which takes it out. The button always shows the window's real state, however it changed (a keybind too). On a window that cannot change its size, Maximize is pale and does nothing.
- Moving a window by its title: press and drag. A window in the layout only comes out once you drag it 32 pixels away (a floating one after 4), so a slip of the hand does nothing; it then floats under the pointer.
- Putting a moved window back into the layout. A glass outline fades in where it would go, and letting go puts it there; it is the pointer that counts, not the window:
    - the pointer at the top of a screen: into the layout;
    - the pointer near a side of a window in the layout (Hyprland's dwindle layout): beside that window, on that side, taking half of its room. In the middle of a window, or anywhere else, the window stays floating where you let go.
- The same with Hyprland's own move (`bindm = SUPER, mouse:272, movewindow`). A window you take out of the layout that way is put back by Hyprland where you let go, as always; near a window's side, it goes to that side.
- Double-clicking the title does what Maximize / Restore does.
- Resizing by the frame's edges, as on Windows: a side changes only the width or the height, a corner both. A window in the layout resizes only by the sides it shares with another window: the only window on a workspace cannot be resized at all, and the edges that touch the screen's edge show no resize cursor.
- The line between two windows in the layout: grab it in the gap between them, or at either window's edge, and it follows the pointer, both windows with it. Where lines meet, both move at once. This needs dwindle with `smart_resizing` on, which is Hyprland's default; otherwise the shared edges resize their window.
- No frame for apps that draw their own title bar: Chromium and Electron apps that do (VS Code, Vivaldi, Discord, Obsidian), GTK apps, Firefox. They say so to the compositor, and the frame listens.
- The frame follows the app: if an app draws itself smaller than the room Hyprland gives it, the frame goes around the app, not around the empty room.
- The frames grow with `QT_SCALE_FACTOR`, as your Qt apps do.
- The Aero (light) and Slate (dark) themes, following your system's colour scheme while the companion runs.

Not yet:

- Tooltips on the buttons.
- The window menu.
- A way to force the frame on an app that draws its own title bar.
- A Minimize button: Hyprland has no minimized windows.

What is planned is in `AGENTS.md` section 8.

## Why it is careful

The frames are drawn by a Hyprland plugin, a library that runs inside Hyprland itself. A mistake in a plugin can crash Hyprland and close every app you have open. That is why this module grows slowly and puts safety before looks:

- The plugin only loads into the exact Hyprland version it was built for. After every Hyprland update it has to be built again; until then it refuses to load.
- If anything unexpected goes wrong inside it, it turns itself off for the rest of the session instead of taking Hyprland down. Your windows simply go back to how they look without it, and a notification tells you. `hyprctl hypraero-frames` says what happened.
- After `hyprctl plugin unload`, a newly built plugin loaded under the same path keeps running the old code until Hyprland restarts. That is the price of unloading safely. Restart Hyprland to try a new build.

## Building it

You need Hyprland's headers (on Arch they come with the `hyprland` package), CMake, Ninja, GCC and cairo.

```bash
git clone -b frames --recurse-submodules https://github.com/SonicallGameXGit/HyprAero.git ~/HyprAero-frames
cd ~/HyprAero-frames
cmake -S plugin -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_CXX_COMPILER=g++
cmake --build build
ctest --test-dir build
```

The plugin is `build/hypraero-frames.so`. HyprAero keeps each module on a branch of its own; this is the `frames` branch, and the `main` branch lists all of them. Its look comes from the `design` branch, which git puts into `design/` (that is what `--recurse-submodules` is for).

## Setting it up

The frame takes the place of Hyprland's own border and rounded corners, and its glass looks right only with Hyprland's blur. The frame resizes windows by its edges itself, so Hyprland's `resize_on_border` is not needed; leave it off, or its cursors fight the frame's. In your Hyprland config:

```ini
general {
    border_size = 0
    resize_on_border = false
}

decoration {
    rounding = 0
    blur {
        enabled = true
    }
}
```

Or, in a `hyprland.lua`:

```lua
hl.config({
    general = {
        border_size = 0,
        resize_on_border = false,
    },
    decoration = {
        rounding = 0,
        blur = {
            enabled = true,
        },
    },
})
```

Without blur the glass is still drawn, just not blurred.

**Size:** the frames take `QT_SCALE_FACTOR` from Hyprland's environment, so set it in Hyprland's config (`env = QT_SCALE_FACTOR,1.25`), not only in a shell. They read it when the plugin loads and whenever the config is reloaded. A value that is not a number from 0.5 to 4 is ignored (Hyprland's log says so). A window rule that rounds windows (`rounding`, `rounding_power`) shows the glass through the window's corners; leave it out.

Load the plugin (Hyprland must be the version it was built against):

```bash
hyprctl plugin load ~/HyprAero-frames/build/hypraero-frames.so
```

The path must be a full one: Hyprland opens the file from its own working folder, not from yours, so `./build/hypraero-frames.so` fails with "cannot open shared object file". From the repository's folder, `hyprctl plugin load "$PWD/build/hypraero-frames.so"` works.

To load it at every start, add `exec-once = hyprctl plugin load <full path>/build/hypraero-frames.so` to your config (in Lua, `hl.exec_cmd("hyprctl plugin load <full path>/build/hypraero-frames.so")` inside `hl.on("hyprland.start", ...)`).

**The companion** gives the frames your apps' icons and switches them between Aero and Slate with your system's colour scheme. It needs Quickshell. Without it the frames are Aero, with Windows 7's generic application icon.

```bash
qs -p ~/HyprAero-frames
```

To start it with Hyprland: `exec-once = qs -p <full path>/HyprAero-frames`. It can be started before or after the plugin is loaded.

**No frame for an app:** apps that draw their own title bar get none by themselves. For any other app, Hyprland's `decorate` window rule turns the frame off for the windows it matches:

```ini
windowrule = decorate off, match:class ^org\.gnome\.Nautilus$
```

```lua
hl.window_rule({
    name     = "no-frame-nautilus",
    match    = { class = "^org\\.gnome\\.Nautilus$" },
    decorate = false,
})
```

`hyprctl hypraero-frames` tells whether the plugin is on, and if it turned itself off, why.
