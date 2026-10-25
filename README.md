# HyprAero frames

Windows 7 window frames for Hyprland, part of HyprAero, a Windows 7 (Aero) style desktop for Hyprland. The goal: every window gets Windows 7's glass frame, its title and icon, and the Maximize and Close buttons, drawn by Hyprland itself so the frame always sits and moves with its window. It works on its own, with or without HyprAero's bar.

## State

**Not ready to use.** This is the start of the module: the plugin builds and can say its version, but draws nothing yet, and it has not yet been tried inside a running Hyprland. There is nothing to install for now. What is planned, in order, is in `AGENTS.md` section 8.

## Why it is careful

The frames are drawn by a Hyprland plugin, a library that runs inside Hyprland itself. A mistake in a plugin can crash Hyprland and close every app you have open. That is why this module grows slowly and puts safety before looks:

- The plugin only loads into the exact Hyprland version it was built for. After every Hyprland update it has to be built again; until then it refuses to load.
- If anything unexpected goes wrong inside it, it turns itself off for the rest of the session instead of taking Hyprland down: your windows simply go back to how they look without it, and a notification tells you. `hyprctl hypraero-frames` says what happened.

## Building it (for development)

You need Hyprland's headers (on Arch they come with the `hyprland` package), CMake, Ninja and GCC.

```bash
git clone -b frames --recurse-submodules https://github.com/SonicallGameXGit/HyprAero.git ~/HyprAero-frames
cd ~/HyprAero-frames
cmake -S plugin -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build
ctest --test-dir build
```

The plugin is `build/hypraero-frames.so`. HyprAero keeps each module on a branch of its own; this is the `frames` branch, and the `main` branch lists all of them. Its look comes from the `design` branch, which git puts into `design/` (that is what `--recurse-submodules` is for).
