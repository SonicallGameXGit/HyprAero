# Resources

Files the shell loads at run time that are not code: Windows' own icons (and later sounds and cursors), copied here from the reference material in `assets/` (git-ignored, see `AGENTS.md` section 4.3). Code reads them from here, never from `assets/`.

They are Microsoft's: taken from Windows' system files, kept for this personal project at the owner's request (`AGENTS.md` decision log, 2026-10-18).

## Icons (`icons/`)

Each icon is kept as `<name>-<size>.png`, one file for each 32-bit frame its `.ico` has up to 48 px, as it is (Windows draws each size by hand). `icons/frames.js` lists the frames of every icon and is written again whenever one is added; `design/WindowsIcon.qml` picks the frame from it.

Source: `w7` is `assets/windows-ui-assets-main/Icons/Windows 7/ico/` (numbers as in its `Tables/Windows 7 Icons.md`), `sp1` is `assets/windows7-sp1/ico/` (Windows 7 SP1's own files, numbered by resource id; see its `README.md`).

| Name | Source | Frames | Used for |
| --- | --- | --- | --- |
| `network-wifi-0` .. `-5` | sp1 `pnidui.dll` 3021-3026 | 16 20 24 32 | Tray: connected over Wi-Fi, 0 to 5 bars |
| `network-wifi-limited-0` .. `-5` | sp1 `pnidui.dll` 3027-3032 | 16 20 24 32 | Tray: Wi-Fi without full internet access (gold warning sign) |
| `network-wifi-available` | sp1 `pnidui.dll` 3066 | 16 20 24 32 | Tray: not connected, networks to connect to (gold star) |
| `network-wifi-none` | sp1 `pnidui.dll` 3067 | 16 20 24 32 | Tray: not connected, nothing to connect to (red cross) |
| `network-wifi-connecting-1` .. `-9` | sp1 `pnidui.dll` 3071-3079 | 16 20 24 32 | Tray: Windows' connecting animation over Wi-Fi |
| `network-wired` | sp1 `pnidui.dll` 3048 | 16 20 24 32 | Tray: connected by cable |
| `network-wired-limited` | sp1 `pnidui.dll` 3051 | 16 20 24 32 | Tray: cable without full internet access |
| `network-wired-none` | sp1 `pnidui.dll` 3020 | 16 20 24 32 | Tray: no cable plugged in |
| `network-wired-connecting-1` .. `-9` | sp1 `pnidui.dll` 3081-3089 | 16 20 24 32 | Tray: Windows' connecting animation over a cable |
| `network-public` | sp1 `pnidui.dll` 2401 | 16 24 32 48 | Flyout: "Currently connected to:", Windows' public network location (the bench) |
| `flyout-wifi-available` | sp1 `van.dll` 4 | 32 48 | Flyout: not connected, connections are available |
| `flyout-wifi-none` | sp1 `van.dll` 3 | 32 48 | Flyout: not connected, none available |
| `flyout-wired-none` | sp1 `van.dll` 8 | 32 48 | Flyout: not connected, no Wi-Fi and no cable |
| `refresh` | sp1 `van.dll` 6 | 16 20 24 32 | Flyout: the refresh button |
| `shield-warning` | sp1 `van.dll` 5 | 16 24 32 48 | Flyout: over the signal bars of a network anyone can listen to |
| `signal-bars-0` .. `-5` | sp1 `netcenter.dll` 14-19 | 32 48 | Flyout: a network's signal, drawn at 24 px as Windows does |
| `signal-bars-slate-0` .. `-5` | changed copy of `signal-bars-*` | 32 48 | Flyout on Slate: each bar's outline takes the bar's own darkest outline colour and the faint white glow around the bars becomes shadow (`assets/windows7-sp1/tools/slatebars.py`). Windows drew a near-white bevel on each bar's left and top for its white flyout, which reads as a bright outline on a dark pane |
| `volume-none` | sp1 `sndvolsso.dll` 125 | 16 20 24 32 | Tray: no output device (red cross) |
| `volume-muted` | sp1 `sndvolsso.dll` 120 | 16 20 24 32 | Tray: muted (red no-entry sign) |
| `volume-silent` / `-low` / `-medium` / `-high` | sp1 `sndvolsso.dll` 121 / 122 / 123 / 124 | 16 20 24 32 | Tray: the speaker with no, one, two and three sound waves |
| `speakers` | sp1 `sndvolsso.dll` 100 | 16 32 48 | Volume flyout and mixer: the sound device's picture |
| `mute-button` | sp1 `sndvol.exe` 110 | 16 20 24 32 | Volume flyout and mixer: the blue speaker under each trackbar |
| `mute-button-muted` | sp1 `sndvol.exe` 111 | 16 20 24 32 | The same while muted (the no-entry sign) |

Other pictures of the same files not used yet: the other network locations in `pnidui.dll` (2400 home, 2402 work, 2403 domain, 2404-2411 the pictures a user could choose), an ad-hoc network in `van.dll` (2, 7), the Network and Sharing Center's in `netcenter.dll`, the Volume Mixer's own icon (`sndvol.exe` 101) and the same speaker pictures as `speakers` in `mmsys.cpl` (100, 3004). The "System Sounds" picture is in `mmres.dll`, not in SP1.
