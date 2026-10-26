# HyprAero frames

Windows 7 window frames for Hyprland, part of HyprAero, a Windows 7 (Aero) style desktop for Hyprland. Every window gets Windows 7's glass frame, its icon and title, and the Maximize and Close buttons, drawn by Hyprland itself so the frame always sits and moves with its window. It works on its own, with or without HyprAero's bar.

## State

**Early.** What works:

- Windows 7's frame around every window: see-through glossy glass with Windows 7's streaks, lighter for the active window and paler for the others.
- The app's icon and the window's title in the top band. Long titles are cut short with "…".
- Maximize (Restore while the window is maximized) and Close, Windows 7's own buttons: they glow under the pointer, and Close turns red. A click acts when you let go over the same button.
- The Aero (light) and Slate (dark) themes, following your system's colour scheme while the companion runs.

Not yet:

- Tooltips on the buttons.
- Moving a window by its title, double-clicking the title, and the window menu.
- A Minimize button: Hyprland has no minimized windows.

What is planned is in `AGENTS.md` section 8.

**Apps that draw their own title bar** get a second one, the frame's, above their own. These are GTK apps with header bars (GNOME apps, for example) and some Electron apps. Until there is a better answer, turn the frame off for such an app with Hyprland's `decorate` window rule (see "Setting it up" below).

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

The frame takes the place of Hyprland's own border and rounded corners, and its glass looks right only with Hyprland's blur. In your Hyprland config:

```ini
general {
    border_size = 0
    resize_on_border = true     # resize a window by dragging its frame's edge
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
        resize_on_border = true,
    },
    decoration = {
        rounding = 0,
        blur = {
            enabled = true,
        },
    },
})
```

Without blur the glass is still drawn, just not blurred. A window rule that rounds windows (`rounding`, `rounding_power`) shows the glass through the window's corners; leave it out.

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

**No frame for an app:** Hyprland's `decorate` window rule turns the frame off for the windows it matches:

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
