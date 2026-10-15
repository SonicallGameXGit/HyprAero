import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

// A long-running program, not a part of the shell: holds the tray's StatusNotifierWatcher (the D-Bus name
// apps register their tray icons with) in a process of its own, so restarting the shell does not lose
// icons. Electron apps (Discord, VS Code, Slack) register their icon once, with the watcher there when they
// start, and never again: when the watcher lived in the shell, a shell restart, or a shell started after
// them, left their icon missing until the app itself was restarted.
//
// The shell starts it when no watcher is on the bus (`services/Tray.qml`); it runs on the Wayland platform
// with no window, only so it ends with the session. `qs -n` keeps it to one copy.
ShellRoot {
    // Reading the tray is what makes Quickshell take the watcher's name (and register as a host, so apps
    // that ask whether anything shows icons hear yes while the shell restarts).
    readonly property int itemCount: SystemTray.items.values.length
}
