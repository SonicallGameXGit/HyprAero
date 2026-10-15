# HyprAero

A Windows Aero style desktop shell for Hyprland, built on Quickshell. Work in progress.

## Setting it up

The Lua examples go into your Hyprland config (`~/.config/hypr/hyprland.lua`). Only the first two steps are needed to run the shell; the rest makes it look and feel the way it is meant to.

### 1. What you need

- **Hyprland** 0.56 or newer, with a **Lua config** (`hyprland.lua`). The shell talks to Hyprland in Lua (switching workspaces, moving windows), which a classic `hyprland.conf` setup does not understand.
- **Quickshell** 0.3.2 or newer (on Arch: `pacman -S quickshell`).
- **gdbus** (part of glib2) and **xdg-desktop-portal** with a backend that knows the light / dark setting (`xdg-desktop-portal-gtk`, `-gnome` or `-kde`), so the shell follows your theme. Without them it stays light.
- A UI font: Segoe UI, Selawik, Noto Sans or Open Sans, the first one installed is used (`noto-fonts` is the easy choice).
- **xdg-utils** (`xdg-open`), so the start menu's folders open in your file manager.
- Optional: **xdg-terminal-exec** or a `$TERMINAL` variable (the start menu's Terminal and terminal apps; otherwise the first of kitty, foot, alacritty, wezterm, konsole and xterm found), **hyprlock** (Lock in the start menu), **zenity** (choosing your picture from the start menu).

### 2. Get it and run it

```bash
git clone https://github.com/SonicallGameXGit/HyprAero.git ~/HyprAero
qs --path ~/HyprAero     # qs log --path ~/HyprAero reads its log, qs kill --path ~/HyprAero stops it
```

To start it with Hyprland, add it to the autostart. Start the tray's watcher with it, and let **the apps that put an icon in the tray** (Discord, Telegram, Steam, ...) wait for that watcher: autostart commands all start at once, and an Electron app (Discord) that starts before the watcher never shows its tray icon (see the tray in "What works"). `gdbus wait` returns as soon as the watcher is there, at most 10 seconds later. If you used another bar (Waybar, an AGS shell, ...), take that one out, or both will show:

```lua
local hyprAero = "~/HyprAero"   -- where you cloned it; the examples below use this too
local afterTray = "gdbus wait --session --timeout 10 org.kde.StatusNotifierWatcher; "

hl.on("hyprland.start", function()
    hl.exec_cmd("qs -n -p " .. hyprAero .. "/tools/trayWatcher.qml")
    hl.exec_cmd("qs --path " .. hyprAero)
    hl.exec_cmd(afterTray .. "discord")
    hl.exec_cmd(afterTray .. "Telegram -startintray")
end)
```

### 3. Blur behind the glass

The shell draws its own glass, so it looks right without blur, but real Aero glass is frosted: what is behind it is blurred. Only Hyprland can do that, and only for what your config asks it to. Turn blur on and add these two layer rules:

```lua
hl.config({
    decoration = {
        blur = {
            enabled  = true,
            size     = 5,
            passes   = 2,
            popups   = true,     -- apps' own right-click menus get frosted too
            vibrancy = 0.1696,
        },
    },
})

-- The bar and everything that opens from it: the start button, the start menu, the window previews, the
-- tray's flyout, right-click menus and tooltips.
hl.layer_rule({ match = { namespace = "hypraero-bar" }, blur = true, blur_popups = true, ignore_alpha = 0.5 })
-- What you carry while dragging a window, a workspace or an app, and its "Put back" slot.
hl.layer_rule({ match = { namespace = "hypraero-drop" }, blur = true, ignore_alpha = 0.2, no_anim = true })
```

Why each part is there:

- **`blur_popups = true`**: the start menu, the window previews and the menus are popups of the bar. Hyprland blurs a layer's popups only when its rule says so; without it only the bar itself is frosted, and the menu's glass shows what is behind it sharp.
- **`ignore_alpha = 0.5`**: blur only where the shell draws glass. The window previews' popup is much bigger than the panel you see (so it never has to move), and menus and the start button have soft shadows; without this, Hyprland blurs those see-through parts too, and you get a frosted rectangle around them. The glass itself is more opaque than 0.5 in both themes, the shadows are lighter, so only the glass is kept.
- **`hypraero-drop`**: while something is dragged out of the bar, a transparent layer covers the screen to draw it and take the drop. With blur, the "Put back" slot is frosted glass; the rest of the layer is fully transparent and stays clear. `no_anim` makes it appear at once if your config animates layers.

### 4. Windows: floating and rounded, as on Windows

Windows 7 opens every window floating, with rounded corners and a soft shadow. These rules do the same: every window opens floating, a floating window gets the family's 8px window corners, and a tiled one (after **Fit into layout**, see the window previews) stays square, as tiled windows touch each other.

```lua
hl.config({
    general = {
        gaps_in     = 0,
        gaps_out    = 0,
        border_size = 0,   -- the shell's look comes from the glass and shadows, not from a coloured border
    },

    decoration = {
        rounding = 0,      -- tiled windows: square

        shadow = {
            enabled      = true,
            range        = 16,
            render_power = 2,
            color        = "rgba(00000033)",   -- soft, never a heavy black block
        },
    },
})

hl.window_rule({
    name  = "float-all",
    match = { class = ".*" },
    float = true,
})

hl.window_rule({
    name  = "round-windows-on-float",
    match = { float = true },
    rounding       = 8,
    rounding_power = 8,
})
```

The rounding rule follows the window: tile a floating window and its corners turn square, float it again and they are rounded.

### 5. Key bindings

Windows' own shortcuts, where Hyprland has no reason to differ:

```lua
-- The start menu (on the focused monitor; `open` and `close` work too).
hl.bind("ALT + SPACE", hl.dsp.exec_cmd("qs ipc --path " .. hyprAero .. " call startMenu toggle"))
-- A terminal (any terminal you use).
hl.bind("SUPER + C", hl.dsp.exec_cmd("kitty"))
-- The file manager, as Win + E on Windows (any file manager you use).
hl.bind("SUPER + E", hl.dsp.exec_cmd("thunar"))
-- Close the focused window, as on Windows; the app can still ask to save.
hl.bind("ALT + F4", hl.dsp.window.close())
```

## What works

- **Bar**: one per screen, at the bottom edge, running edge to edge without side borders. Like the Windows 7 taskbar, the bar and everything that opens from it (start menu, window previews, the tray's flyout) are a darker glass than windows, with white words; what you can click on it lights up as glass under the pointer, and the current workspace and anything whose menu is open stay lit a little brighter.
- **Workspaces**: centered in the bar, 1 to 10 always shown (more appear while they have windows or focus). Click one to switch to it; an empty one is created, like with the keyboard shortcut. What a button shows:
    - a small blue dot: no windows;
    - one app icon: windows of a single app;
    - several apps: the icon of the app with the biggest window, and the second biggest app's icon as a small badge at its bottom-right corner (the rest are not shown).
    
    An app without an icon in your icon theme gets a generic window picture. The current workspace has a highlight that glides to the new one.
- **Window previews**: hover a workspace with windows to see a card per window in a popup that sits on top of the bar, like the Windows 7 taskbar thumbnails: icon and title, then a live picture of the window (a generic icon until the picture arrives, or if the compositor cannot provide one). Each card has the window's proportions. A window hanging off the edge of its monitor shows a still picture of its visible part, taken when the popup opens, instead of a live one: the compositor cannot provide the rest, and a live picture of it would jump around during workspace switches. Moving the pointer to another workspace keeps the current previews until the new ones are ready, then fades between them. Biggest window first, up to 4 cards per row. The popup stays open while the pointer is on it and closes shortly after it leaves. Empty workspaces show nothing.
    - **Hover a card** to light it up and show its two buttons, as on a Windows title bar: maximize / restore and the red close button.
    - **Click a card** to go to that window: its workspace is shown and the window gets focus. The pointer stays where it is.
    - **Click the maximize / restore button** to switch the window between the tiled layout and floating, like maximizing and restoring on Windows. A tiled window fills its place, so it shows the "restore" picture (two boxes) and floats the window; a floating window shows the "maximize" picture (one box) and fits it back into the layout. The same as **Float freely** / **Fit into layout** in the card's menu.
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
- **Pinned apps**: right of the start button, between two dotted grips, like Windows Vista's Quick Launch. Each pin is an app's icon that starts it, a new copy each time, like a shortcut. Resting the pointer on a pin shows the app's name just above the bar.
    - **Pin an app**: drag it from the start menu, or drag a window's preview card, onto the grips' area. A glowing blue mark shows where the pin will go; let go there. With nothing pinned yet the grips keep one icon's room between them to drop on. You can also right-click a preview card and choose **Pin to bar**.
    - **Click a pin** to start the app. **Right-click it** for its menu: the app (bold, starts it), its own actions (such as "New Window") hanging under it on a thin line, and **Unpin from bar**.
    - **Drag a pin** to move it among the pins (the blue mark shows where), or drag it out to a workspace to start the app there, exactly like dragging an app out of the start menu. Its "Put back" slot stays where it was taken from.
    - An app that is uninstalled disappears from the pins and comes back in its place if it is installed again. Pins are kept in `~/.local/state/hypraero/pins.json` (or under `$XDG_STATE_HOME`).
- **Notification area (tray)**: the apps' icons at the right end of the bar, left of the empty workspace button, as on Windows 7 (Steam, Discord, Telegram, the network applet, ...). Any app that puts an icon in a Linux tray (a StatusNotifierItem, what KDE and most bars use) shows here; old X11-only tray icons need `xembed-sni-proxy` (part of KDE Plasma's workspace package) to appear.
    - **What the icons do is the app's own**: click one (most apps open their window), right-click it for the app's menu, middle-click it or use the wheel on it if the app does something with those. An app that only has a menu opens it on a click too. Resting the pointer on an icon shows its name (and what the app says about it, such as a status) just above the bar.
    - **The app's menu** looks like every other menu of the shell: ticks for options that are on, the app's small pictures, and submenus that open beside their entry (point at it, click it, or press Right; Left closes it). Up / Down, Enter and Escape work too.
    - **Hidden icons**: like Windows 7, the tray keeps the bar tidy. A new icon goes behind the **arrow** ("Show hidden icons") left of the tray; click the arrow to open a small glass flyout with those icons, ready to use the same way. Escape, a click outside or the arrow again closes it, and so does using one of its icons.
    - **Choose which icons show**: drag an icon out of the flyout onto the bar's icons to keep it always shown, at the place a glowing blue mark shows. Drag an icon from the bar onto the arrow (the flyout opens) and drop it in the flyout to hide it again. Icons can also be dragged along the bar or inside the flyout to change their order. A "Put back" slot stays where you took an icon from; dropping it there, or anywhere else, changes nothing.
    - **Customize...** at the bottom of the flyout opens the **Notification Area Icons** page, as on Windows 7 (a window of its own; the list's rows light up under the pointer, and its scrollbar can be dragged or clicked): every icon the tray has ever seen (apps that are not running too, greyed), each with what it should do:
        - **Show icon and notifications**: always on the bar;
        - **Hide icon and notifications**: always in the flyout;
        - **Only show notifications** (the default for a new icon): in the flyout, but on the bar while the app asks for your attention (for example a new message), so you do not miss it.

        The names are Windows 7's, where "notifications" meant the speech bubbles a tray icon could pop up. Linux tray icons have no bubbles; what they have instead is "asking for attention", and that is what these choices are about. Your ordinary desktop notifications (the ones apps send to a notification server) are not touched by them.

        **Restore default icon behaviors** puts every icon back to "Only show notifications". **Always show all icons and notifications on the bar** shows every icon on the bar (the same as the `tray.showAll` setting, see Settings; ticking it writes that setting into your `config.json`). Changes apply at once; **Close** (or Escape) closes the page. With no icon hidden (every icon set to show, or "Always show all" on) the arrow stays, turned to point right at the icons instead of up, and a click on it opens this page. You can also **right-click an empty part of the bar** and choose **Customize notification icons...** at any time. (Before any app has put an icon in the tray, there is no arrow.)
    - The tray remembers every icon, its choice and the order in `~/.local/state/hypraero/tray.json` (or under `$XDG_STATE_HOME`). Icons are told apart by the id their app gives them.
    - **An app's icon is missing although the app is running?** Apps hand their tray icon to a "tray watcher" on D-Bus. Many apps (Telegram and the network applet, for example) hand it over again whenever a watcher appears, but Electron apps (Discord, VS Code, Slack, ...) try once, when they start, and never again: started before the shell, they never show an icon. The shell cannot bring such an icon back: the app has given up on it. Restart the app once the shell runs, and let it wait for the watcher at login (`gdbus wait`, see the autostart above). The shell keeps the watcher in a small process of its own (`qs -n -p <shell folder>/tools/trayWatcher.qml`, started by the shell when there is no watcher yet, or by your autostart), so restarting the shell does not lose those icons.
- **Clock and calendar**: the time over the short date, left of the empty workspace button and right of the tray, as on Windows 7 (in your system's language and clock style, 12 or 24 hours, the year in full). Resting the pointer on it shows the long date. **Click it** to open the calendar flyout; Escape, a click outside or the clock again closes it. It opens on today's month.
    - **The flyout**: the long date over a calendar on a white pane, today as a blue tile, and the analog clock with the time and its seconds beside it. The week starts on your system's first day of the week.
    - **The calendar**: the arrows (or the mouse wheel over the pane) go a month back or forward; a day of the neighbouring month goes to that month. Click the **month's name** to zoom out to the months of the year, and its title again to the years of the decade; click a month or a year to zoom back in. Today is always marked.
    - Every screen's bar has its own clock; only one calendar is open at a time.
- **Empty workspace button**: the narrow strip at the right end of the bar, where Windows 7 has "Show desktop". Click it to go to the first workspace without windows (the lowest-numbered one; when all have windows, the next new one).

- **Start button and menu**: the round glass orb at the left end of the bar. Like Windows Vista's, it is a bit bigger than the bar, centred on it: it rises a little above the bar's top edge and its bottom runs off the screen. The bar's corner under it counts too, so you can throw the pointer into the corner and click. Click it to open the start menu, which sits on top of the orb; click it again, click anywhere outside, or press Escape to close it. The orb stays lit while its menu is open, also when a key binding opened it. Only one start menu is open at a time.
    - **Left side, the apps**, read from the top: the **Featured** label (★) and your featured apps, sorted by how much you use them; a dark line; the **Most used** label and the other apps you have used lately, the most used first; another dark line; then every app left, from A to Z. A part with nothing in it is left out, with its line (Featured instead says how to fill it). The menu opens at the top; scroll down for the rest with the wheel, or with the scrollbar at the pane's right edge, which widens when you point at it: drag it, or press beside it to jump there. Once pressed, the scrollbar has the pointer until you let go: the thumb stays under it at the same size, wherever the pointer goes, and nothing in the list is picked up or started. Dragging the list itself scrolls it only with touch controls on (see Settings). Every app shows what it is under its name: its description, or the program it runs when it has none.
    - **Click an app** to start it. **Click the star** at the end of a row (it shows when you point at the row) to feature an app, or to stop featuring it. **Right-click an app** for more: Open, the app's own actions (such as "New Window"), Add to / Remove from Featured, and **Forget usage** (puts the app back in its A to Z place).
    - **An app's own actions** (such as "New Window" or "New Private Window"): an app that has some shows a small arrow at the right end of its row. Click it and the actions open under the app, hanging from its icon on a thin line and lined up with its name, so they read as part of the app; click one to start it. Click the arrow again to close them. They stay open while the menu is open and are closed the next time it opens.
    - **Drag an app** out of the menu to start it on another workspace (with touch controls on, hold it for a moment first, until it pops out). The app's row comes along under the pointer, and the menu stays open with a glass "Put back" slot where the row was. Where you drop it works exactly like dragging a window card: on a workspace button, left or right of the buttons, or higher up the screen (the lowest workspace without windows). The target button lights up before you let go. Dropped on the pinned apps instead, it is pinned there (nothing starts, the menu stays open). The app opens there and you stay on the workspace you are on; then the menu closes. **Changed your mind?** Drop it anywhere on the menu (the "Put back" slot lights up while you are over it): nothing starts and the menu stays as it was. Dropping where no button lights up starts nothing either.

        Hyprland is asked to open the app on that workspace, which works when the app's window comes from the program that was started. Many apps start through a launcher (VS Code's `code`, Electron apps, Flatpaks), and a browser that is already running opens the new window in its running copy; for those, the shell moves any new window of that app to the chosen workspace as it appears, so you may see it on your current workspace for a moment. This lasts up to 30 seconds after the drop and 5 seconds after the app's first window, so a splash screen and the main window both go there, while a window you open yourself later stays where you open it.
    - **Search**: just start typing when the menu is open. Apps whose name starts with what you typed come first, then a word in the name, then the middle of a name, then what the app is about (its kind and keywords), its description, and its program name. Among equally good matches, the more used app comes first. The results sit under an "Apps (number)" label; the best match is at the top and already selected: press Enter to start it.
    - **Keyboard**: Up and Down move through the apps (and through the actions of an app that has them open), Enter starts the selected app or action, the Menu key opens the app's right-click menu. Tab opens or closes the selected app's actions; Right and Left do it too while nothing is typed in the search. Escape clears the search, or closes the menu when the search is empty.
    - **How "most used" is worked out**: each time you use an app it gets a point, and points fade by half every two weeks without use. Apps you use now rank above ones you used a lot long ago, and an app you stop using slides back to its A to Z place over a couple of months. Using an app means starting it from the menu, or keeping one of its windows focused for 10 seconds (so apps started by a key binding or a terminal count too; this can be turned off, see Settings). It counts at most once every 10 minutes per app, and not while you are away from the computer (5 minutes without input). Featured apps and usage are kept in `~/.local/state/hypraero/start-menu.json` (or under `$XDG_STATE_HOME`).
    - **Right side, your places**: your picture (`~/.face`, or a coloured square with your initial when there is none; click it to choose another, see below) and name (opens your home folder), Documents, Pictures, Music, Videos and Downloads (your XDG folders; one you set to your home folder is left out), Computer (the file system root) and Terminal. Your picture sits in a frosted glass frame like Windows 7's, following the theme, rising above the menu's top edge; pointing at a place shows that place's icon in its stead. Folders open in your default file manager. The terminal is `xdg-terminal-exec` when installed, else `$TERMINAL`, else the first of kitty, foot, alacritty, wezterm, konsole and xterm that is installed. Apps that ask to run in a terminal use the same one.
    - **Change your picture**: click it. A file chooser opens in your Pictures folder, showing only pictures (PNG, JPEG, GIF, BMP, WebP); pick one and its middle, cut to a square and shrunk to 256 pixels (never stretched), is saved as `~/.face`, replacing the one there, and shows from then on (other programs that read `~/.face`, such as some lock screens and login screens, show it too). Cancel changes nothing. The chooser is zenity's; without zenity installed, pointing at the picture says so, and you can still save a picture as `~/.face` yourself: the start menu shows it the next time it opens.
    - **Shut down** turns the computer off; the arrow next to it has Restart, Sleep, Lock and Log out. Shut down, Restart and Log out close all your apps, so they ask first (Escape or a click outside says no). Lock runs `hyprlock` when it is installed, otherwise asks the session to lock (`loginctl lock-session`), which needs a locker listening for it, such as `hypridle` with a lock command; without one, Lock does nothing.
    - **Open it with a key**: Alt + Space with the binding from "Key bindings" above. It opens on the focused monitor.

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
| `tray.showAll` | `false` | Every tray icon is on the bar (the "Show hidden icons" arrow then points right, at them), whatever each icon's own choice says. The tray's **Customize...** page has the same switch; using it there rewrites `config.json` (keeping everything else you wrote in it, but not its layout or spacing). When the file is not valid JSON the page leaves it alone, and the switch lasts until the shell restarts. |

## Theme

The bar follows the system light/dark setting (the desktop portal's `color-scheme`, so GNOME/GTK settings or your portal backend) and changes live. It needs `gdbus` (part of glib2); without it the bar stays light.
