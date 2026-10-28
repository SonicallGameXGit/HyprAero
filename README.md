# HyprAero notifications

The notification server of HyprAero, a Windows 7 (Aero) style desktop for Hyprland built on Quickshell. It receives the notifications your apps send (browsers, chat apps, `notify-send`, the system) and shows them as Windows 7 notification balloons. It runs on its own, with or without HyprAero's bar.

## What it does

Each notification appears as a Windows 7 balloon: a white to light grey-blue bubble with a pointed tail, the title in bold with the app's icon, the message under it and a small close button. By default it appears in the bottom-right corner, above your taskbar if you have one, one at a time: while a balloon is shown, the next ones wait their turn, as on Windows 7.

- **Click the balloon** to open what it is about (the app's main action, for example the chat a message came from). It closes.
- **Click the ×** to close it.
- **Buttons** along the bottom are every choice the app gives (Open, Reply, Mark as read, ...), the first one highlighted as the main one; many buttons wrap onto more rows.
- **Rest the pointer on it** to keep it open; it closes a few seconds after you move away.
- A balloon closes by itself after 5 seconds, or after the time the app asked for. Critical notifications (a nearly empty battery, for example) stay until you close them.
- The app's icon sits before the title (Windows 7's own icons for information, warnings, errors and questions; a plain window icon for an app without one), and a picture sent with the notification (a chat avatar, a photo) shows at the left.
- Messages are shown as plain text, cut after 255 characters (the title after 63), as Windows 7 did.
- It never takes the keyboard: typing in another app goes on undisturbed.
- **Hide an app's notifications** (needs HyprAero's bar): on the bar's **Notification Area Icons** page (the tray's "Customize..."), choose **Hide icon and notifications** or **Only show icon** for an app's tray icon, or **Hide notifications** for an app without one (those that sent you notifications are listed after the icons). **Hide all notifications** on the same page hides every one. A hidden notification is never shown. Without the bar every notification shows.

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

To see that it works, send yourself a notification: `notify-send 'Hello' 'This is a balloon'`, or with Windows 7's warning icon, `notify-send -i dialog-warning 'Low disk space' 'You are running out of disk space.'`. Its log (`qs log --path ~/HyprAero-notifications`) has a line about each one, like `Notifications: #1 from "notify-send", normal, summary of 5 characters`. The log never contains what a notification says, only what kind it was, because notifications can hold private messages or codes.

## Settings

Settings are in `~/.config/hypraero/notifications.json` (the folder is shared with HyprAero's other modules; this file is only this module's). The file is optional and only needs what you want different; changes apply as soon as you save it. A wrong value is ignored (the default is used) and the log says what was wrong.

```json
{
    "balloons": {
        "position": "top-right",
        "maxVisible": 3
    }
}
```

| Setting | Default | What it does |
| --- | --- | --- |
| `balloons.position` | `"bottom-right"` | Where balloons appear: `"top-left"`, `"top"`, `"top-right"`, `"left"`, `"center"`, `"right"`, `"bottom-left"`, `"bottom"` or `"bottom-right"`. They always stay clear of bars that keep room for themselves (a taskbar, a panel). |
| `balloons.margin` | `8` | Space between the balloons and the edge of the screen (or the bar there), in pixels, 0 to 500. |
| `balloons.maxVisible` | `1` | How many balloons show at once, 1 to 10. With 1, as on Windows 7, the next waits until the shown one closes; with more they stack, the newest nearest the edge. |
| `balloons.timeout` | `5000` | How long a balloon stays when the app does not say, in milliseconds (1000 to 600000). |
| `balloons.stem` | `true` | The pointed tail, aimed at the corner the balloons are in (centred on the middle of the top or bottom edge; there is none in the middle of the left or right side or in the centre). |
| `balloons.monitor` | `""` | The screen to use, by its name as `hyprctl monitors` lists it (`"DP-1"`). Empty: the screen you are working on. |
