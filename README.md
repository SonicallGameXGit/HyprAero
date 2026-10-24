# HyprAero notifications

The notification server of HyprAero, a Windows 7 (Aero) style desktop for Hyprland built on Quickshell. It receives the notifications your apps send (browsers, chat apps, `notify-send`, the system) and will show them as Aero balloons. It runs on its own, with or without HyprAero's bar.

**Work in progress:** for now it only receives notifications and writes a line about each one to its log. Nothing appears on the screen yet, and each notification is dropped as soon as it arrives (apps are told it was dismissed). Keep your current notification program until the balloons are here.

## Setting it up

### What you need

- **Hyprland** and **Quickshell** 0.3.2 or newer (on Arch: `pacman -S quickshell`).
- **No other notification server running** (mako, dunst, swaync, a desktop's own). Only one program can receive notifications at a time. While another one has that role, this module waits, writes so in its log, and takes over by itself as soon as the other one stops.

### Get it and run it

```bash
git clone -b notifications --recurse-submodules https://github.com/SonicallGameXGit/HyprAero.git ~/HyprAero-notifications
qs --path ~/HyprAero-notifications     # qs log --path ~/HyprAero-notifications reads its log, qs kill --path ~/HyprAero-notifications stops it
```

HyprAero keeps each module on a branch of its own; this is the `notifications` branch. The `main` branch lists all of them. Its look comes from the `design` branch, which git puts into `design/`. That is what `--recurse-submodules` is for; in a clone made without it, run `git submodule update --init` in the module's folder.

To update: `git -C ~/HyprAero-notifications pull --recurse-submodules`.

To start it with Hyprland (`~/.config/hypr/hyprland.lua`):

```lua
hl.on("hyprland.start", function()
    hl.exec_cmd("qs --path ~/HyprAero-notifications")
end)
```

To see that it works, send yourself a notification (`notify-send 'Hello'`) and read its log (`qs log --path ~/HyprAero-notifications`). It shows a line like `Notifications: #1 from "notify-send", normal, summary of 5 characters`. The log never contains what a notification says, only what kind it was, because notifications can hold private messages or codes.
