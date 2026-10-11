.pragma library

// Which workspace a new window goes to after an app was dropped on one. Plain JS, no Quickshell imports, so
// node can test it.
//
// Hyprland is asked to open the app there, but it can only recognise a window of the process it started.
// Many apps hand the start to another process (a launcher script that exits, Electron, Flatpak) or to a
// copy already running (most browsers), so their window opens on the workspace in view. Each drop is
// therefore remembered as a launch `{ app, workspaceId, startedAt, firstAt }` (`app` is the desktop entry
// id, times in ms, `firstAt` 0 until a window came), and a new window of that app goes to its workspace.

// How long a launch waits for its first window (slow apps take seconds to start), and how long after its
// first window more windows still follow it (a splash screen or an updater, then the main window).
const launchWait = 30000
const followWait = 5000

function addLaunch(launches, app, workspaceId, now) {
    return launches.concat([{ app: app, workspaceId: workspaceId, startedAt: now, firstAt: 0 }])
}

// The launches still waiting or still taking windows.
function liveLaunches(launches, now) {
    return launches.filter(launch => {
        if (launch.firstAt === 0) {
            return now - launch.startedAt < launchWait
        }

        return now - launch.firstAt < followWait
    })
}

// Where a new window of `app` goes: `{ workspaceId, launches }`, workspaceId 0 when no launch of the app is
// live (the window was not asked for, it stays where it opened). Each launch takes the first window that
// comes for it, oldest launch first, so two quick drops of one app to two workspaces each get one; once
// all have one, more windows follow the newest launch.
function placeWindow(launches, app, now) {
    const live = liveLaunches(launches, now)
    let chosen = -1
    for (let index = 0; index < live.length; index++) {
        if (live[index].app !== app) {
            continue
        }

        if (live[index].firstAt === 0) {
            chosen = index
            break
        }

        chosen = index
    }

    if (chosen === -1) {
        return { workspaceId: 0, launches: live }
    }

    const updated = live.slice()
    if (updated[chosen].firstAt === 0) {
        updated[chosen] = Object.assign({}, updated[chosen], { firstAt: now })
    }

    return { workspaceId: updated[chosen].workspaceId, launches: updated }
}
