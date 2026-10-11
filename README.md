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

        - **on the pinned apps** (between the two dotted grips right of the start button): the window's app is pinned there, see below. The window itself stays where it is. A glowing blue mark shows where the pin will go.

        **Changed your mind?** Where you took the card from, a glass "Put back" slot stays. Bring the card back over it (its edge glows blue) and let go: nothing happens, as if you had never picked it up.
    - **Right-click a card** for its menu (Up / Down and Enter work too, Escape or a click elsewhere closes it):
        - **Focus**: the same as clicking the card.
        - **Fit into layout**: puts a floating window back into the tiled layout (greyed out when it already is tiled).
        - **Float freely**: takes the window out of the layout, so it can be moved and sized freely (greyed out when it already floats).
        - **Pin to bar** / **Unpin from bar**: adds the window's app to the pinned apps, or takes it off. Greyed out for a window whose app has no desktop entry (the shell would not know how to start it).
        - **Close**: the same as the red close button.
- **Drag a workspace button** (one with windows) to move the whole workspace: all its windows go together. It works exactly like dragging a card: the button stays under the pointer where you took it, the target button lights up, the same places count (a button, left or right of the buttons, or higher up), and a glass slot (just the "put back" arrow, as the button is small) stays in its place to drop it back on. You stay on the workspace number you are on.
    - **To a workspace without windows**: the workspace simply takes the new number, so everything stays exactly as it was: layout, positions, sizes, order, fullscreen and floating windows.
    - **To a workspace that already has windows**: the windows are moved in one by one (biggest first) and Hyprland fits them in among the ones there, so their layout is not kept (there is no way to keep two layouts in one place).
- **Pinned apps**: right of the start button, between two dotted grips, like Windows Vista's Quick Launch. Each pin is an app's icon that starts it, a new copy each time, like a shortcut. Pointing at a pin shows the app's name.
    - **Pin an app**: drag it from the start menu, or drag a window's preview card, onto the grips' area. A glowing blue mark shows where the pin will go; let go there. With nothing pinned yet the grips keep one icon's room between them to drop on. You can also right-click a preview card and choose **Pin to bar**.
    - **Click a pin** to start the app. **Right-click it** for its menu: the app (bold, starts it), its own actions (such as "New Window") hanging under it on a thin line, and **Unpin from bar**.
    - **Drag a pin** to move it among the pins (the blue mark shows where), or drag it out to a workspace to start the app there, exactly like dragging an app out of the start menu. Its "Put back" slot stays where it was taken from.
    - An app that is uninstalled disappears from the pins and comes back in its place if it is installed again. Pins are kept in `~/.local/state/hypraero/pins.json` (or under `$XDG_STATE_HOME`).
- **Empty workspace button**: the narrow strip at the right end of the bar, where Windows 7 has "Show desktop". Click it to go to the first workspace without windows (the lowest-numbered one; when all have windows, the next new one).

- **Start button and menu**: the round glass orb at the left end of the bar. Like Windows Vista's, it is a bit bigger than the bar, centred on it: it rises a little above the bar's top edge and its bottom runs off the screen. The bar's corner under it counts too, so you can throw the pointer into the corner and click. Click it to open the start menu, which sits on top of the orb; click it again, click anywhere outside, or press Escape to close it. Only one start menu is open at a time.
    - **Left side, the apps**, read from the top: the **Featured** label (★) and your featured apps, sorted by how much you use them; a dark line; the **Most used** label and the other apps you have used lately, the most used first; another dark line; then every app left, from A to Z. A part with nothing in it is left out, with its line (Featured instead says how to fill it). The menu opens at the top; scroll down for the rest with the wheel, or with the scrollbar at the pane's right edge, which widens when you point at it: drag it, or press beside it to jump there. Once pressed, the scrollbar has the pointer until you let go: the thumb stays under it at the same size, wherever the pointer goes, and nothing in the list is picked up or started. Dragging the list itself scrolls it only with touch controls on (see Settings). Every app shows what it is under its name: its description, or the program it runs when it has none.
    - **Click an app** to start it. **Click the star** at the end of a row (it shows when you point at the row) to feature an app, or to stop featuring it. **Right-click an app** for more: Open, the app's own actions (such as "New Window"), Add to / Remove from Featured, and **Forget usage** (puts the app back in its A to Z place).
    - **An app's own actions** (such as "New Window" or "New Private Window"): an app that has some shows a small arrow at the right end of its row. Click it and the actions open under the app, hanging from its icon on a thin line and lined up with its name, so they read as part of the app; click one to start it. Click the arrow again to close them. They stay open while the menu is open and are closed the next time it opens.
    - **Drag an app** out of the menu to start it on another workspace (with touch controls on, hold it for a moment first, until it pops out). The app's row comes along under the pointer, and the menu stays open with a glass "Put back" slot where the row was. Where you drop it works exactly like dragging a window card: on a workspace button, left or right of the buttons, or higher up the screen (the lowest workspace without windows). The target button lights up before you let go. Dropped on the pinned apps instead, it is pinned there (nothing starts, the menu stays open). The app opens there and you stay on the workspace you are on; then the menu closes. **Changed your mind?** Drop it anywhere on the menu (the "Put back" slot lights up while you are over it): nothing starts and the menu stays as it was. Dropping where no button lights up starts nothing either.

        Hyprland is asked to open the app on that workspace, which works when the app's window comes from the program that was started. Many apps start through a launcher (VS Code's `code`, Electron apps, Flatpaks), and a browser that is already running opens the new window in its running copy; for those, the shell moves any new window of that app to the chosen workspace as it appears, so you may see it on your current workspace for a moment. This lasts up to 30 seconds after the drop and 5 seconds after the app's first window, so a splash screen and the main window both go there, while a window you open yourself later stays where you open it.
    - **Search**: just start typing when the menu is open. Apps whose name starts with what you typed come first, then a word in the name, then the middle of a name, then what the app is about (its kind and keywords), its description, and its program name. Among equally good matches, the more used app comes first. The results sit under an "Apps (number)" label; the best match is at the top and already selected: press Enter to start it.
    - **Keyboard**: Up and Down move through the apps (and through the actions of an app that has them open), Enter starts the selected app or action, the Menu key opens the app's right-click menu. Tab opens or closes the selected app's actions; Right and Left do it too while nothing is typed in the search. Escape clears the search, or closes the menu when the search is empty.
    - **How "most used" is worked out**: each time you use an app it gets a point, and points fade by half every two weeks without use. Apps you use now rank above ones you used a lot long ago, and an app you stop using slides back to its A to Z place over a couple of months. Using an app means starting it from the menu, or keeping one of its windows focused for 10 seconds (so apps started by a key binding or a terminal count too; this can be turned off, see Settings). It counts at most once every 10 minutes per app, and not while you are away from the computer (5 minutes without input). Featured apps and usage are kept in `~/.local/state/hypraero/start-menu.json` (or under `$XDG_STATE_HOME`).
    - **Right side, your places**: your picture (`~/.face`, or a coloured square with your initial when there is none) and name (opens your home folder), Documents, Pictures, Music, Videos and Downloads (your XDG folders; one you set to your home folder is left out), Computer (the file system root) and Terminal. Pointing at a place shows its icon in the picture frame. Folders open in your default file manager. The terminal is `xdg-terminal-exec` when installed, else `$TERMINAL`, else the first of kitty, foot, alacritty, wezterm, konsole and xterm that is installed. Apps that ask to run in a terminal use the same one.
    - **Shut down** turns the computer off; the arrow next to it has Restart, Sleep, Lock and Log out. Shut down, Restart and Log out close all your apps, so they ask first (Escape or a click outside says no). Lock runs `hyprlock` when it is installed, otherwise asks the session to lock (`loginctl lock-session`), which needs a locker listening for it, such as `hypridle` with a lock command; without one, Lock does nothing.
    - **Open it with a key**: bind a key to `qs ipc --path /path/to/HyprAero call startMenu toggle` (also `open` and `close`). It opens on the focused monitor. For example, in a Lua config:

        ```lua
        hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("qs ipc --path /path/to/HyprAero call startMenu toggle"))
        ```

## Settings

Settings live in `~/.config/hypraero/config.json` (or under `$XDG_CONFIG_HOME`; the shell creates the folder). The file is optional: create it only to change something, and write only what you change. Changes apply as soon as you save. A mistake (a wrong value, a misspelt name, broken JSON) never breaks the shell: that setting keeps its default and the shell log (`qs log`) says what was wrong.

```json
{
    "startMenu": {
        "touchControls": true
    }
}
```

| Setting | Default | What it does |
| --- | --- | --- |
| `startMenu.touchControls` | `false` | Phone-style controls for the start menu's app list: drag the list to scroll it, and hold an app for a moment to pick it up and drag it to a workspace. Off: dragging an app picks it up at once, and the list scrolls with the wheel or the scrollbar. |
| `startMenu.countFocus` | `true` | Keeping a window of an app focused for 10 seconds counts as using the app, for "Most used". Off: only starting an app from the menu counts. Nothing leaves your computer either way. |

## Theme

The bar follows the system light/dark setting (the desktop portal's `color-scheme`, so GNOME/GTK settings or your portal backend) and changes live. It needs `gdbus` (part of glib2); without it the bar stays light.

## Blur behind the bar (optional)

The bar draws its own glass. For real blur behind it, add a layer rule for the namespace `hypraero-bar` to your Hyprland config, for example in Lua:

```lua
hl.layer_rule({ match = { namespace = "hypraero-bar" }, blur = true, ignore_alpha = 0.2 })
```

The exact rule syntax depends on your Hyprland version; without it the bar still looks fine, just without blur.

The start menu, the window previews and the right-click menus are popups of the bar, so they are blurred only when the bar's rule also covers its popups (`blur_popups = true` in the rule above, `blurpopups` in a classic `.conf`). Without it the glass of the menu shows what is behind it unblurred.

While a window or workspace is dragged out of the bar, a transparent layer named `hypraero-drop` covers the screen (it draws what you carry and the "Put back" slot, and takes the drop). With blur on it, the slot is frosted glass over what is behind it (only the slot and the carried picture are blurred, the rest of the layer is fully transparent); `no_anim` makes it appear at once if your config animates layers:

```lua
hl.layer_rule({ match = { namespace = "hypraero-drop" }, blur = true, ignore_alpha = 0.2, no_anim = true })
```
