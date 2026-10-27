# Resources

Windows 7's own pictures used by the frames (`design/AGENTS.md` section 4.3). They are Microsoft's, kept for this personal project at the owner's request; only what the plugin uses is here. All of them are made by `tools/cut-pictures.py` from the owner's references (git-ignored, in the bar's working folder `assets/`), copied pixel for pixel, never redrawn:

```bash
python3 -I tools/cut-pictures.py <the bar's assets folder>
```

The plugin embeds them at build time (`plugin/src/host/pictures.cpp`); nothing reads this folder at run time.

## frame/

Cut from Windows 7's DWM atlas, `assets/aero/windows-7-ui-elements/images/caption-buttons-and-glass-sprite-sheet-windows-bitmap__1210-231.png`, without the 1px copies of the edges the atlas keeps around its pieces. Rectangles are x, y, width, height in the atlas.

| File | Rectangle | What it is | Used by |
| --- | --- | --- | --- |
| `face-maximize-rest.png` | 84, 89, 29, 20 | Maximize's face when it is the leftmost button (bottom-left corner rounded) | the Maximize / Restore button |
| `face-maximize-hover.png` | 84, 111, 29, 20 | the same, under the pointer | |
| `face-maximize-pressed.png` | 84, 133, 29, 20 | the same, pressed | |
| `face-maximize-inactive.png` | 84, 155, 29, 20 | the same, on an inactive window | |
| `face-close-rest.png` | 84, 569, 49, 20 | Close's face when it is the rightmost button (bottom-right corner rounded) | the Close button |
| `face-close-hover.png` | 84, 591, 49, 20 | the same, under the pointer (red) | |
| `face-close-pressed.png` | 84, 613, 49, 20 | the same, pressed | |
| `face-close-inactive.png` | 135, 1, 49, 20 | the same, on an inactive window | |
| `glyph-close.png` / `-inactive` | 1, 486 / 1, 528, 11 x 10 | the Close cross, drawn for 96 DPI | |
| `glyph-maximize.png` / `-inactive` | 18, 62 / 18, 104, 12 x 10 | the Maximize box | |
| `glyph-restore.png` / `-inactive` | 1, 541 / 1, 583, 12 x 12 | Restore's two boxes, while maximized | |
| `glow-maximize.png` | 83, 440, 49, 38 | the glow around Maximize under the pointer, a hole where the button goes; drawn in nine parts | |
| `glow-close.png` | 261, 0, 66, 40 | the glow around Close | |
| `reflection.png` | 555, 0, 802, 604 | the streaks over the glass | the glass, at 1:1 from the window's corner |

## icons/

| File | Source | Frames | Used by |
| --- | --- | --- | --- |
| `application-16.png`, `application-32.png` | `windows-ui-assets-main/Icons/Windows 7/ico/shell32.dll/ICON3_1.ico` (shell32 #3) | 16, 32 | the frame's icon, for a window whose app's icon is not known (yet) |
