# HyprAero

A Windows Aero style desktop shell for Hyprland, built on Quickshell. Work in progress.

## Run

```bash
qs --path=./     # from the project root; qs log to read the log, qs kill to stop
```

Needs Quickshell and Hyprland (tested with Hyprland 0.56 and a Lua config).

## What works

- **Bar**: one per screen, at the bottom edge.
- **Workspaces**: centered in the bar, 1 to 10 always shown (more appear while they have windows or focus). Click one to switch to it; an empty one is created, like with the keyboard shortcut. What a button shows:
    - a small blue dot: no windows;
    - one app icon: windows of a single app;
    - several apps: the icon of the app with the biggest window, and the second biggest app's icon as a small badge at its bottom-right corner (the rest are not shown).
    
    An app without an icon in your icon theme gets a generic window picture. The current workspace has a highlight that glides to the new one.
- **Window previews**: hover a workspace with windows to see a card per window in a popup that sits on top of the bar, like the Windows 7 taskbar thumbnails: icon and title, then a live picture of the window (a generic icon until the picture arrives, or if the compositor cannot provide one). Each card has the window's proportions. A window hanging off the edge of its monitor shows a still picture of its visible part, taken when the popup opens, instead of a live one: the compositor cannot provide the rest, and a live picture of it would jump around during workspace switches. Moving the pointer to another workspace keeps the current previews until the new ones are ready, then fades between them. Biggest window first, up to 4 cards per row. The popup stays open while the pointer is on it and closes shortly after it leaves. Empty workspaces show nothing.

## Theme

The bar follows the system light/dark setting (the desktop portal's `color-scheme`, so GNOME/GTK settings or your portal backend) and changes live. It needs `gdbus` (part of glib2); without it the bar stays light.

## Blur behind the bar (optional)

The bar draws its own glass. For real blur behind it, add a layer rule for the namespace `hypraero-bar` to your Hyprland config, for example in Lua:

```lua
hl.layer_rule({ match = { namespace = "hypraero-bar" }, blur = true, ignore_alpha = 0.2 })
```

The exact rule syntax depends on your Hyprland version; without it the bar still looks fine, just without blur.
