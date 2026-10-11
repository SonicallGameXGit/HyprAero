# HyprAero

A Windows Aero style desktop shell for Hyprland, built on Quickshell. Work in progress.

## Run

```bash
qs --path=./     # from the project root; qs log to read the log, qs kill to stop
```

Needs Quickshell and Hyprland (tested with Hyprland 0.56 and a Lua config).

## What works

- **Bar**: one per screen, at the bottom edge, running edge to edge without side borders.
- **Workspaces**: centered in the bar, 1 to 10 always shown (more appear while they have windows or focus). Click one to switch to it; an empty one is created, like with the keyboard shortcut. What a button shows:
    - a small blue dot: no windows;
    - one app icon: windows of a single app;
    - several apps: the icon of the app with the biggest window, and the second biggest app's icon as a small badge at its bottom-right corner (the rest are not shown).
    
    An app without an icon in your icon theme gets a generic window picture. The current workspace has a highlight that glides to the new one.
- **Window previews**: hover a workspace with windows to see a card per window in a popup that sits on top of the bar, like the Windows 7 taskbar thumbnails: icon and title, then a live picture of the window (a generic icon until the picture arrives, or if the compositor cannot provide one). Each card has the window's proportions. A window hanging off the edge of its monitor shows a still picture of its visible part, taken when the popup opens, instead of a live one: the compositor cannot provide the rest, and a live picture of it would jump around during workspace switches. Moving the pointer to another workspace keeps the current previews until the new ones are ready, then fades between them. Biggest window first, up to 4 cards per row. The popup stays open while the pointer is on it and closes shortly after it leaves. Empty workspaces show nothing.
    - **Hover a card** to light it up and show its red close button.
    - **Click a card** to go to that window: its workspace is shown and the window gets focus. The pointer stays where it is.
    - **Click the close button** to ask the window to close, exactly like its own close button: an app with unsaved work can ask what to do, or refuse.
    - **Drag a card** to move its window to another workspace. The card comes off the popup and stays under the pointer exactly where you took it, see-through so you can see what is under it. The workspace button where the window would land lights up, so you always know before letting go. You stay on the workspace you are on. Where you drop it:
        - **on a workspace button**: that workspace (empty ones too, so a window can go to a new one). The bar does not have to be hit exactly: up to 48px above it still counts, and between two buttons the closer one is taken;
        - **left of the workspace buttons**, on the bar or up to 240px above it: the leftmost workspace without windows;
        - **right of the workspace buttons**, on the bar or up to 240px above it: the rightmost workspace without windows;
        - **anywhere higher up the screen**: the lowest workspace without windows.

        When there is no workspace without windows, dropping on the sides or higher up does nothing (no button lights up). Dropping it on its own workspace's button leaves it where it is.

        **Changed your mind?** Where you took the card from, a glass "Put back" slot stays. Bring the card back over it (its edge glows blue) and let go: nothing happens, as if you had never picked it up.
- **Drag a workspace button** (one with windows) to move the whole workspace: all its windows go together. It works exactly like dragging a card: the button stays under the pointer where you took it, the target button lights up, the same places count (a button, left or right of the buttons, or higher up), and a glass slot (just the "put back" arrow, as the button is small) stays in its place to drop it back on. You stay on the workspace number you are on.
    - **To a workspace without windows**: the workspace simply takes the new number, so everything stays exactly as it was: layout, positions, sizes, order, fullscreen and floating windows.
    - **To a workspace that already has windows**: the windows are moved in one by one (biggest first) and Hyprland fits them in among the ones there, so their layout is not kept (there is no way to keep two layouts in one place).
- **Empty workspace button**: the narrow strip at the right end of the bar, where Windows 7 has "Show desktop". Click it to go to the first workspace without windows (the lowest-numbered one; when all have windows, the next new one).

- **Start button and menu**: the round glass orb at the left end of the bar. Like Windows Vista's, it is a bit bigger than the bar and rises above its top edge. The bar's corner under it counts too, so you can throw the pointer into the corner and click. Click it to open the start menu, which sits on top of the orb; click it again, click anywhere outside, or press Escape to close it. Only one start menu is open at a time.
    - **Left side, the apps**, read from the search field upwards. Right above the search field is the **Featured** label (★), a dark line, and your featured apps above it, sorted by how much you use them. Then the **Most used** label, another dark line, and every other app above it: the ones you use most first (at the top of that list), then the rest from A to Z. The menu opens scrolled to the bottom; scroll up for the rest. Every app shows what it is under its name: its description, or the program it runs when it has none.
    - **Click an app** to start it. **Click the star** at the end of a row (it shows when you point at the row) to feature an app, or to stop featuring it. **Right-click an app** for more: Open, the app's own actions (such as "New Window"), Add to / Remove from Featured, and **Forget usage** (puts the app back in its A to Z place).
    - **Search**: just start typing when the menu is open. Apps whose name starts with what you typed come first, then a word in the name, then the middle of a name, then what the app is about (its kind and keywords), its description, and its program name. Among equally good matches, the more used app comes first. The results sit above a dark line and an "Apps (number)" label; the best match is at the top and already selected: press Enter to start it.
    - **Keyboard**: Up and Down move through the apps, Enter starts the selected one, the Menu key opens its right-click menu. Escape clears the search, or closes the menu when the search is empty.
    - **How "most used" is worked out**: each time you use an app it gets a point, and points fade by half every two weeks without use. Apps you use now rank above ones you used a lot long ago, and an app you stop using slides back to its A to Z place over a couple of months. Using an app means starting it from the menu, or keeping one of its windows focused for 10 seconds (so apps started by a key binding or a terminal count too). It counts at most once every 10 minutes per app, and not while you are away from the computer (5 minutes without input). Featured apps and usage are kept in `~/.local/state/hypraero/start-menu.json` (or under `$XDG_STATE_HOME`).
    - **Right side, your places**: your picture (`~/.face`, or a coloured square with your initial when there is none) and name (opens your home folder), Documents, Pictures, Music, Videos and Downloads (your XDG folders; one you set to your home folder is left out), Computer (the file system root) and Terminal. Pointing at a place shows its icon in the picture frame. Folders open in your default file manager. The terminal is `xdg-terminal-exec` when installed, else `$TERMINAL`, else the first of kitty, foot, alacritty, wezterm, konsole and xterm that is installed. Apps that ask to run in a terminal use the same one.
    - **Shut down** turns the computer off; the arrow next to it has Restart, Sleep, Lock and Log out. Shut down, Restart and Log out close all your apps, so they ask first (Escape or a click outside says no). Lock runs `hyprlock` when it is installed, otherwise asks the session to lock (`loginctl lock-session`), which needs a locker listening for it, such as `hypridle` with a lock command; without one, Lock does nothing.
    - **Open it with a key**: bind a key to `qs ipc --path /path/to/HyprAero call startMenu toggle` (also `open` and `close`). It opens on the focused monitor. For example, in a Lua config:

        ```lua
        hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("qs ipc --path /path/to/HyprAero call startMenu toggle"))
        ```

## Theme

The bar follows the system light/dark setting (the desktop portal's `color-scheme`, so GNOME/GTK settings or your portal backend) and changes live. It needs `gdbus` (part of glib2); without it the bar stays light.

## Blur behind the bar (optional)

The bar draws its own glass. For real blur behind it, add a layer rule for the namespace `hypraero-bar` to your Hyprland config, for example in Lua:

```lua
hl.layer_rule({ match = { namespace = "hypraero-bar" }, blur = true, ignore_alpha = 0.2 })
```

The exact rule syntax depends on your Hyprland version; without it the bar still looks fine, just without blur.

The start menu and the window previews are popups of the bar, so they are blurred only when the bar's rule also covers its popups (`blur_popups = true` in the rule above, `blurpopups` in a classic `.conf`). Without it the glass of the menu shows what is behind it unblurred.

While a window or workspace is dragged out of the bar, a transparent layer named `hypraero-drop` covers the screen (it draws what you carry and the "Put back" slot, and takes the drop). With blur on it, the slot is frosted glass over what is behind it (only the slot and the carried picture are blurred, the rest of the layer is fully transparent); `no_anim` makes it appear at once if your config animates layers:

```lua
hl.layer_rule({ match = { namespace = "hypraero-drop" }, blur = true, ignore_alpha = 0.2, no_anim = true })
```
