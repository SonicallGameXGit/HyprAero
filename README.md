# HyprAero

A Windows Aero style desktop shell for Hyprland, built on Quickshell. Work in progress.

## Run

```bash
qs --path=./     # from the project root; qs log to read the log, qs kill to stop
```

Needs Quickshell and Hyprland (tested with Hyprland 0.56 and a Lua config).

## What works

- **Bar**: one per screen, at the bottom edge.
- **Workspaces**: click a button to switch to that workspace. The blue one is the current workspace, a raised button has windows on it, a flat one is empty. Workspaces 1 to 10 are always shown, empty ones too; clicking an empty one creates it, like the keyboard shortcut. Others appear while they have windows or focus.

## Theme

The bar follows the system light/dark setting (the desktop portal's `color-scheme`, so GNOME/GTK settings or your portal backend) and changes live. It needs `gdbus` (part of glib2); without it the bar stays light.

## Blur behind the bar (optional)

The bar draws its own glass. For real blur behind it, add a layer rule for the namespace `hypraero-bar` to your Hyprland config, for example in Lua:

```lua
hl.layer_rule({ match = { namespace = "hypraero-bar" }, blur = true, ignore_alpha = 0.2 })
```

The exact rule syntax depends on your Hyprland version; without it the bar still looks fine, just without blur.
