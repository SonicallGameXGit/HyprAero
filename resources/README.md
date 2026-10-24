# Resources

Files the module loads at run time that are not code: Windows' own icons, copied here from the reference material the owner keeps outside the repository (`design/AGENTS.md` section 4.3). Code reads them from here only.

They are Microsoft's: taken from Windows' system files, kept for this personal project at the owner's request (`design/AGENTS.md` section 4.3).

## Icons (`icons/`)

Each icon is kept as `<name>-<size>.png`, one file for each 32-bit frame its `.ico` has up to 48 px, as it is (Windows draws each size by hand). `icons/frames.js` lists the frames of every icon and is written again whenever one is added; `design/WindowsIcon.qml` picks the frame from it, and `tests/resources.test.mjs` checks every listed frame is here.

Source: `w7` is the `windows-ui-assets` collection's `Icons/Windows 7/ico/` (numbers as in its `Tables/Windows 7 Icons.md`).

| Name | Source | Frames | Used for |
| --- | --- | --- | --- |
| `information` | w7 `imageres.dll` 81 | 16 32 48 | Balloon: the `dialog-information` icon |
| `warning` | w7 `imageres.dll` 84 | 16 32 48 | Balloon: the `dialog-warning` icon |
| `error` | w7 `imageres.dll` 98 | 16 24 32 48 | Balloon: the `dialog-error` icon |
| `question` | w7 `imageres.dll` 99 | 16 32 48 | Balloon: the `dialog-question` icon |
