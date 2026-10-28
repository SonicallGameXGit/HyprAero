# Visual style

The look of every Aero family project. **Style** here means colours, shades, gradients, rounding, buttons, borders and their behaviour. How things are placed and how they are used (the layout and UX) is the design of each project and lives in its own `AGENTS.md`.

**Not a default "modern flat / paper" look.** That generic AI-made style is explicitly rejected.

## 1. Three references, each with a fixed role

| Reference | Role | Where it is used |
| --- | --- | --- |
| **Windows Aero** (Vista / 7) | The base style of everything | Window chrome, toolbars, panes, buttons, lists, menus, dialogs, inputs, panels, notifications |
| **Frutiger Aero** (broad: sky, water, bokeh, bubbles, vivid blue-green) | Imagery only | Wallpapers and backdrops behind glass, empty states, onboarding, splash |
| **Longhorn "Slate" / "Plex"** | The dark theme | Same components as Aero, re-toned dark and more serious |

Frutiger Aero imagery must never sit under long text and never be busy enough to compete with content.

### The owner's design file

**Longhorn Mockups** (Figma): https://www.figma.com/design/5WXM0xTlbQpyPGAOIj2LNF/Longhorn-Mockups?node-id=1201-171&p=f

The owner's mockups of the family's buttons, fonts, icons and other components. Before drawing a component or changing how one looks, check it there: it is the picture this file's words and tokens describe. A value taken from it still becomes a token (section 4) before any component uses it, and a difference between the mockups and this file is raised with the owner, not settled silently.

The original belongs to someone else; the owner's own copy, which the owner's account can open and edit, is **Longhorn Mockups (Copy)**: https://www.figma.com/design/nOfW0PdsVhl3x9zBRS3PkA/Longhorn-Mockups--Copy-?node-id=2-14

The file needs a Figma login: its API, page and thumbnails answer "log in" to a client without one. Ways in that work: Figma's MCP server (only on a file the account can edit, a `use_figma` call returns at most 20KB, and the owner's Starter plan allows only a few calls a month, so it suits one look at one node, not an export), or Figma's REST API with a personal access token of the owner's (read-only "file content" scope), passed in the request header and nothing else (`GET /v1/files/<key>?geometry=paths` for every page, component, style and vector; `GET /v1/images/<key>?ids=...&format=svg` to export many nodes in one request). An agent that cannot open it says so and asks the owner for screenshots, an export or a token, instead of guessing. A token is never written into the repository, a config file or a log.

Many of its pieces are Microsoft's own Windows 7 bitmaps (sprite strips cut from Windows' resources) next to the author's vector redraws. Both are for looking at and measuring; none of it is shipped (see "Start orb": drawn from values, never from a picture of the original). **Exception:** the window frames ("Window frames") ship the pieces of Windows 7's own frame atlas (caption buttons, their glyphs and glows, the title's glow, the glass's reflection), cut from it unchanged, as a member ships Windows' own icons; owner's decision (2026-10-25).

## 2. What "Windows Aero" means concretely

- **Glass**: translucent, blurred, lightly tinted surfaces for chrome (title area, bars, toolbars, sidebars, popups). A thin bright inner border and a darker outer border give each glass panel an edge.
- **Content stays solid**: lists, text and anything long-read sit on opaque (or near-opaque) surfaces. Glass is for chrome, never under long text.
- **Gloss**: buttons and selected items have a soft vertical gradient with a lighter upper half; the colour steps at 49% / 50% of the height create the classic "horizon". Hover adds a glow, press darkens and flattens (inset shadow).
- **Depth**: soft drop shadows and glow separate layers; no hard flat blocks, no heavy black shadows.
- **Shape**: small radii (controls 3px, panels 6px, windows 8px), not pills and not sharp squares.
- **Colour**: cool blue-led palette with green / aqua accents; saturated but airy. Slate: charcoal / graphite glass with the same accents, less saturation.
- **Icons**: detailed, glossy, slightly dimensional, drawn from a few glossy materials (`icon-*` tokens). Not thin monochrome line icons, and no icon library with that look. Only small structural glyphs (chevron, close, check) are flat.
- **Pictures before words**: an action or a place is recognised by its icon first. A button keeps its text only when it is the main action of its group; every icon-only control has a tooltip and an accessible name.
- **Buttons say what they are**: accent (the one main action), normal, tool (flat until hovered, for toolbars), danger (red, for what destroys something). On glass a tool button lights up as glass (`glass-button-*`), not with the control face.
- **Dialogs** are laid out like Windows 7 task dialogs: narrow window, a large glossy picture at the top left, one blue line saying what it is about with the explanation under it, buttons on a grey strip along the bottom, the first button focused, Escape gives the safe answer.
- **Type**: a humanist sans in the Segoe UI / Frutiger spirit (`Segoe UI`, `Selawik`, `Noto Sans`, `Open Sans`, then the system), bundled with the project when possible so it looks the same on every system. Sizes: small 12, body 13, heading 16, title 20.
- **Motion**: short, soft fades and glows (fast 120ms, soft 220ms, ease-out). Nothing bouncy.

## 3. Constraints

- **Tokens only.** All colours, radii, shadows, blurs, gradients, spacing and motion come from the shared tokens (section 4). No hard-coded visual values in feature components.
- The style serves `PRINCIPLES.md` sections 1-2: an affordance must look like what it does. Decoration never costs clarity or speed.
- **Glass is drawn inside the app by default**, over the app's own backdrop, so it looks the same everywhere. Real compositor blur is an optional enhancement that degrades to the drawn version. A project whose host guarantees compositor blur may rely on it only if its own `AGENTS.md` says so and explains the fallback.
- Readable text contrast (WCAG AA) on every surface, including glass. Full keyboard navigation. Respect reduced-motion and reduced-transparency settings.
- Light and dark variants are designed together; a token is never added to one theme only.
- Must stay fast on low-end hardware: effects degrade gracefully.
- A new theme is one more token set; no component may need to know which theme is active.

## 4. Shared tokens

Names are the family-wide contract. Each project exposes them in its own technology (CSS custom properties `--glass-tint`, a QML singleton property `glassTint`, ...): same name, same meaning, same values. **Add or change a token here first**, then in every project that uses it.

Aero (light) is the base; Slate overrides only what differs. Values not listed for Slate are the same as Aero.

### Type, space, shape, motion

| Token | Value |
| --- | --- |
| `font-ui` | Segoe UI, Selawik, Noto Sans, Open Sans, Helvetica Neue, system sans |
| `font-size-small` / `body` / `heading` / `title` | 12 / 13 / 16 / 20 px |
| `space-1` .. `space-6` | 4 / 8 / 12 / 16 / 24 / 32 px |
| `radius-control` / `panel` / `window` | 3 / 6 / 8 px |
| `motion-fast` / `motion-soft` | 120ms / 220ms, ease-out |
| `drag-image-opacity` | 0.75 (a picture carried under the pointer, so what it is over stays visible) |

### Backdrop (Frutiger Aero imagery)

| Token | Aero | Slate |
| --- | --- | --- |
| `backdrop-top` | `#2f8fd8` | `#10161d` |
| `backdrop-middle` | `#7fd0f0` | `#25323f` |
| `backdrop-bottom` | `#3fb68b` | `#16303a` |
| `backdrop-light` | `rgba(255,255,255,0.75)` | `rgba(140,190,230,0.22)` |
| `backdrop-bokeh` | `rgba(255,255,255,0.28)` | `rgba(160,210,240,0.10)` |

### Glass (chrome only)

| Token | Aero | Slate |
| --- | --- | --- |
| `glass-tint` | `rgba(214,233,250,0.58)` | `rgba(38,46,56,0.66)` |
| `glass-blur` | 14px | 14px |
| `glass-border-outer` | `rgba(20,50,90,0.55)` | `rgba(0,0,0,0.8)` |
| `glass-border-inner` | `rgba(255,255,255,0.75)` | `rgba(255,255,255,0.2)` |
| `glass-shine` | vertical gradient white 0.6 at 0% -> 0.12 at 42% -> 0 at 43% | same shape, white 0.16 -> 0.03 -> 0 |
| `glass-shadow` | `0 12px 34px rgba(8,35,70,0.45)` + 1px white 0.12 ring | `0 12px 34px rgba(0,0,0,0.65)` + 1px white 0.05 ring |
| `glass-text` | `#0d2238` | `#e9eef3` |
| `glass-text-shadow` | `0 0 8px rgba(255,255,255,0.9)` | `0 0 8px rgba(0,0,0,0.9)` |

### Window frames

A member that draws the frames around other apps' windows draws Windows 7's, measured on Windows 7 screenshots (1:1) and on Windows 7's own picture atlas of the frame (the owner's design file): a band of window glass `frame-border` wide down the sides and along the bottom, `frame-caption` tall along the top, the window's corners rounded by `frame-radius` on the outside. From the outside in: a `frame-edge-outer` line, a `frame-edge-inner` line, the glass (`frame-glass-tint` over the blurred desktop, with Windows 7's streaks of reflection over it), then around the window itself a `frame-client-edge-light` line and a `frame-client-edge-dark` line. A window that is not active takes the `-inactive` values, paler and more see-through, as Windows 7 tells them apart.

Along the top, from the left: the app's 16px icon `frame-icon-left` in from the outer edge, centred in the caption, then after `frame-title-gap` the title in `font-ui` `font-size-small`, `frame-title-text`, centred in the caption's height, without Windows 7's white glow behind it (the owner's choice), cut off with an ellipsis before the buttons. The caption buttons hang from `frame-buttons-top` below the top edge, `frame-buttons-right` in from the right one: Maximize (Restore while maximized), then Close, joined. Their faces, glyphs and the glow around a button under the pointer (blue, red for Close) are Windows 7's own pictures, drawn as they are in both themes (the exception in "The owner's design file").

| Token | Aero | Slate |
| --- | --- | --- |
| `frame-border` / `frame-caption` / `frame-radius` | 8 / 30 / 6 px | same |
| `frame-buttons-top` / `frame-buttons-right` | 1 / 6 px | same |
| `frame-icon-left` / `frame-icon-size` / `frame-title-gap` | 10 / 16 / 5 px | same |
| `frame-glass-tint` / `-inactive` | `rgba(92,139,194,0.70)` / `rgba(164,188,216,0.45)` | `rgba(30,36,44,0.80)` / `rgba(38,44,52,0.60)` |
| `frame-edge-outer` / `-inactive` | `rgba(0,0,0,0.8)` / `rgba(0,0,0,0.6)` | `rgba(0,0,0,0.9)` / `rgba(0,0,0,0.7)` |
| `frame-edge-inner` / `-inactive` | `rgba(255,255,255,0.8)` / `rgba(255,255,255,0.6)` | `rgba(255,255,255,0.3)` / `rgba(255,255,255,0.2)` |
| `frame-client-edge-light` / `frame-client-edge-dark` | `rgba(255,255,255,0.55)` / `rgba(0,0,0,0.5)` | `rgba(255,255,255,0.2)` / `rgba(0,0,0,0.5)` |
| `frame-title-text` | `#000000` | `#e9eef3` |

### Taskbar glass (a desktop shell's own chrome)

Windows 7 and Vista give the taskbar, the start menu and the flyouts over the taskbar a glass of their own: darker than a window's, with plain white words. Its tint is dark enough that white body text keeps WCAG AA contrast even over a white backdrop without compositor blur. A member that draws a desktop shell uses it for that chrome; a window's chrome keeps the glass above. The user's picture stands out of it in a silver frame of its own ("User picture tile" below).

| Token | Aero | Slate |
| --- | --- | --- |
| `taskbar-glass-tint` | `rgba(22,52,86,0.68)` | `rgba(10,13,18,0.72)` |
| `taskbar-glass-border-outer` | `rgba(0,8,20,0.85)` | `rgba(0,0,0,0.9)` |
| `taskbar-glass-border-inner` | `rgba(255,255,255,0.38)` | `rgba(255,255,255,0.14)` |
| `taskbar-glass-shine` | vertical gradient white 0.18 at 0% -> 0.05 at 42% -> 0 at 43% | same shape, white 0.08 -> 0.02 -> 0 |
| `taskbar-glass-text` | `#ffffff` | `#e9eef3` |
| `taskbar-glass-link` | `#cfe8ff` | `#9fd0f7` |

A solid pane set into the taskbar glass (the start menu's list) is edged like Windows 7's: a `taskbar-glass-border-outer` line around it and a `taskbar-glass-border-inner` line outside that one.

The taskbar strip itself (the bar along the screen's edge, not the menus and flyouts over it) is Windows 7's taskbar, measured on the screenshots of the owner's mockups: a lighter glass than the menus over it, close to Windows 7's own light grey-blue, with the wallpaper showing through only faintly, a dark line along its top with a `taskbar-glass-border-inner` line under it, a faint sheen fading out by the middle, no horizon, and no line along the bottom or the ends. White words on it fall below WCAG AA (about 1.7:1 over a white wallpaper, 3:1 over a dark one, without compositor blur), as on Windows 7, whose taskbar is as light. This is the one exception to the taskbar glass's contrast rule above, kept for the look.

| Token | Aero | Slate |
| --- | --- | --- |
| `taskbar-bar-tint` | `rgba(150,175,205,0.75)` | `rgba(22,27,34,0.78)` |
| `taskbar-bar-edge` (1px, along the top edge) | `rgba(12,30,52,0.8)` | `rgba(0,0,0,0.85)` |
| `taskbar-bar-shine` | vertical gradient white 0.03 at 0% -> 0 at 50% | same shape, white 0.02 -> 0 |

### Glass buttons (controls standing on glass)

A tool button standing on glass (a tray icon, the clock, a place in the start menu) does not take the opaque control face: it lights up as glass, a see-through white gloss with the horizon at 49% / 50%, a dark edge and a bright inner line. Flat until hovered; one that must always look like a button (the start menu's Shut down) shows the rest face. `current` is the one that is selected (a button whose menu or flyout is open); `active` is pressed, as for controls. An app's button on the taskbar is drawn differently ("Taskbar items" below).

| Token | Aero | Slate |
| --- | --- | --- |
| `glass-button-face` (top -> 49% -> 50% -> bottom) | white 0.16 / 0.06 / 0 / 0.08 | white 0.10 / 0.04 / 0 / 0.05 |
| `glass-button-face-hover` | white 0.34 / 0.16 / 0.06 / 0.18 | white 0.20 / 0.10 / 0.03 / 0.10 |
| `glass-button-face-current` | white 0.48 / 0.26 / 0.14 / 0.30 | white 0.28 / 0.15 / 0.07 / 0.16 |
| `glass-button-face-active` | `rgba(0,10,25,a)`, a = 0.34 / 0.24 / 0.20 / 0.10 | black 0.40 / 0.30 / 0.26 / 0.14 |
| `glass-button-border` | `rgba(0,8,20,0.70)` | `rgba(0,0,0,0.85)` |
| `glass-button-inner` | `rgba(255,255,255,0.5)` | `rgba(255,255,255,0.2)` |

### Taskbar items (the apps on a desktop shell's taskbar)

An app's button on the taskbar strip is Windows 7's, measured on Windows 7 screenshots, not a glass button. At rest it is only its icon. The buttons fill the strip's height and stand `taskbar-item-gap` apart. Under the pointer two side lines fade in, dark at their middle and fading out to the top and bottom, each with a faint light line on its right, and a small see-through light spot sits at the bottom centre. An open app instead lights up in its own colour: a light (the main colour of its icon, `taskbar-item-glow-neutral` for an icon without one) follows the pointer along the bottom, glowing: near white at its middle, the colour further out. Pressed, its face darkens through the middle, still fading out to the top and bottom, and its icon moves a pixel down and right. An app that is open is a rounded button of its own (a dark border, drawn over the light, a light inner line, a face bright at the top easing out by 70% of its height, no horizon, and the glass's gloss: a see-through sheet over its top-left, lighter toward the corner, its lower edge a sharp curve from 65% down the left side up to the top-right corner); the selected one (the workspace on screen) is the same, brighter, fading in and out (`motion-soft`) as the selection changes, not sliding. Dragged along the strip a button follows the pointer sideways only, the others gliding aside to make room; it stops dead against whatever stands beside the strip, and let go it glides into its slot (`motion-soft`, nearly linear, so the farther it is the faster it goes). Covering a third of another button for a moment (the moving goes on unchanged meanwhile) it joins it instead: that one looks hovered, the held one turns see-through (`drag-image-opacity`) over it, and let go it fades into it. An app that asks for attention flashes its button as Windows 7's does: the open face turns orange (`taskbar-item-face-attention`, same shape and gloss) and back every `taskbar-item-flash-interval`, fading over `motion-fast`, a number of times (Windows 7's default is 7), then stays orange until the app has the user's attention. Under the pointer its light still follows on the orange; pressed, it takes the pressed face.

| Token | Aero | Slate |
| --- | --- | --- |
| `taskbar-item-face-hover` (top -> middle -> bottom) | white 0 / 0.12 / 0 | white 0 / 0.06 / 0 |
| `taskbar-item-face-pressed` (top -> middle -> bottom) | white 0.06 / `rgba(0,10,25,0.32)` / white 0.06 | white 0.03 / black 0.45 / white 0.03 |
| `taskbar-item-face-open` (top -> 70% -> bottom, eased out between the first two) | white 0.43 / 0.09 / 0.09 | white 0.18 / 0.05 / 0.05 |
| `taskbar-item-face-open-hover` | white 0.55 / 0.14 / 0.14 | white 0.24 / 0.08 / 0.08 |
| `taskbar-item-face-current` | white 0.80 / 0.34 / 0.38 | white 0.40 / 0.18 / 0.20 |
| `taskbar-item-face-attention` (gold at the top into orange, measured on Windows 7's "Flash Button" picture) | `rgba(255,222,90,0.9)` / `rgba(242,140,48,0.9)` / `rgba(236,130,44,0.9)` | `rgba(230,188,80,0.8)` / `rgba(200,112,36,0.8)` / `rgba(190,104,34,0.8)` |
| `taskbar-item-flash-interval` (orange, then plain, each this long: Windows' default caret blink rate, which its flashing follows) | 530ms | same |
| `taskbar-item-shine` (the gloss: at the top-left corner -> along its edge) | white 0.23 -> 0.04 | white 0.09 -> 0.015 |
| `taskbar-item-border` / `taskbar-item-inner` (drawn over the light) | `rgba(0,10,25,0.55)` / `rgba(255,255,255,0.45)` | `rgba(0,0,0,0.8)` / `rgba(255,255,255,0.16)` |
| `taskbar-item-edge` / `taskbar-item-edge-light` (the side lines, at their middle) | `rgba(0,10,25,0.5)` / `rgba(255,255,255,0.22)` | `rgba(0,0,0,0.7)` / `rgba(255,255,255,0.08)` |
| `taskbar-item-spot` | `rgba(255,255,255,0.4)` | `rgba(255,255,255,0.25)` |
| `taskbar-item-glow-strength` (the app's light at its brightest) | 0.9 | 0.7 |
| `taskbar-item-glow-neutral` | `#ffffff` | same |
| `taskbar-item-glow-core` (how far toward white the light's middle goes, on a soft bell into the colour; the light's alpha falls off by smoothstep) | 0.65 | 0.5 |
| `taskbar-item-gap` (between two buttons) | 3px | same |

### Show desktop (the block at the end of a desktop shell's taskbar)

Windows 7's "Show desktop" block, measured on Windows 7 screenshots: set off from the taskbar by a `taskbar-item-edge` line with a `taskbar-item-edge-light` line after it, a darker glass than the strip with a light inner line (`taskbar-glass-border-inner`) all round, eased between its stops, the taskbar items' gloss over its top (its edge from 35% on the left to 12% on the right), lighter under the pointer, darker pressed.

| Token | Aero | Slate |
| --- | --- | --- |
| `show-desktop-face` (top -> 25% -> bottom) | white 0.22 / `rgba(0,10,25,0.32)` / `rgba(0,10,25,0.04)` | white 0.10 / black 0.40 / black 0.08 |
| `show-desktop-face-hover` | white 0.40 / 0.08 / 0.14 | white 0.20 / 0.04 / 0.08 |
| `show-desktop-face-active` | white 0.10 / `rgba(0,10,25,0.45)` / `rgba(0,10,25,0.20)` | white 0.05 / black 0.50 / black 0.30 |
| `show-desktop-shine` (the gloss at its top-left corner; a quarter of it along the edge) | white 0.15 | white 0.06 |

### User picture tile

The frame of the user's picture (the start menu's tile) is Windows 7's: a silver glossy band 6px wide, white at the top, see-through down its sides and aqua along the bottom, its outer sides bowed out a little at their middle (`picture-frame-bulge`) so the band is widest there; a `glass-border-outer` line around it, a `glass-border-outer` line along the picture and a `glass-border-inner` line outside that one.

| Token | Aero | Slate |
| --- | --- | --- |
| `picture-frame-face` (top -> 50% -> 85% -> bottom) | `#f2f5f8`, `rgba(200,210,220,0.7)`, `rgba(160,180,196,0.65)`, `#5cc8e6` | `#8d969f`, `rgba(80,90,100,0.75)`, `rgba(60,70,80,0.7)`, `#2f8fa8` |
| `picture-frame-shine` (vertical, over the upper half) | white 0.7 -> 0 | white 0.25 -> 0 |
| `picture-frame-bulge` | 1.5px | same |

### Solid surfaces (content)

| Token | Aero | Slate |
| --- | --- | --- |
| `surface` | `#ffffff` | `#23282e` |
| `surface-sunken` | `#f2f6fb` | `#1b2025` |
| `surface-border` | `#a9b9cc` | `#0d1013` |
| `text` | `#1b1f24` | `#e6eaee` |
| `text-muted` | `#55616f` | `#a3adb8` |
| `text-link` | `#0b5cad` | `#7cc0f5` |
| `heading-text` (the blue line of a dialog) | `#1a4a9c` | `#8cc4f0` |

### Controls (every gradient: top -> 49% -> 50% -> bottom)

| Token | Aero | Slate |
| --- | --- | --- |
| `control-face` | `#fdfdfd #eeeeee #dcdcdc #d0d0d0` | `#5a626b #474e56 #363c43 #2f343a` |
| `control-face-hover` | `#f2faff #dcf1fd #b9e3fb #a5d9f7` | `#6b7885 #55626f #3f4c59 #384552` |
| `control-face-active` | `#e2f3fc #c2e4f6 #94cdee #6fb8e3` | `#2c3238 #2a2f35 #22262b #262b30` |
| `control-border` / `-hover` | `#7c8794` / `#3c7fb1` | `#0b0d10` / `#5aa3d8` |
| `control-inner` (top highlight) | `rgba(255,255,255,0.85)` | `rgba(255,255,255,0.16)` |
| `control-text` | `#1b1f24` | `#eef1f4` |
| `control-pressed-shadow` | `inset 0 1px 3px rgba(0,0,0,0.3)` | same |
| `accent-face` | `#8fd0f7 #4fa9e6 #1f86d4 #2d9be0` | `#5f9fcf #3a7fb5 #1f629b #2a73ad` |
| `accent-face-hover` | `#aee0ff #6cbcf2 #2f97e4 #49b0f0` | `#7cb7e2 #4f95c9 #2b76b3 #3b89c6` |
| `accent-face-active` | `#5aa6d8 #2f84c4 #1568ad #1c78bf` | `#2f6893 #25587f #17456b #1d517a` |
| `accent-border` / `accent-text` | `#134e86` / `#ffffff` | `#06121d` / `#ffffff` |
| `accent-text-shadow` | `0 1px 1px rgba(0,40,90,0.7)` | same |
| `danger-face` | `#f7a79c #e5604f #cf3524 #dc4a38` | same |
| `danger-face-hover` | `#ffc0b7 #f07a6a #dd4534 #ea5e4c` | same |
| `danger-face-active` | `#d0685b #b84032 #9c2417 #aa3123` | same |
| `danger-control-border` | `#7a1810` | `#2a0704` |
| `focus-glow` | `0 0 0 1px #3c9be6, 0 0 6px 1px rgba(60,155,230,0.75)` | same |
| `control-face-disabled` (flat) / `control-border-disabled` / `control-text-disabled` | `#f4f4f4` / `#adb2b5` / `#838383` | `#2a2f35` / `#1b1f23` / `#6b737c` |

### Fields, rows, toolbars, menus, badges

| Token | Aero | Slate |
| --- | --- | --- |
| `field-background` | `#ffffff` | `#171b1f` |
| `field-border` / `field-border-top` | `#8e9aa8` / `#6f7b89` | `#07090b` / `#000000` |
| `field-inner-shadow` | `inset 0 1px 2px rgba(0,0,0,0.12)` | `inset 0 1px 3px rgba(0,0,0,0.6)` |
| `row-hover-face` | `#fafcff -> #ebf3fd` | `#2c333b -> #272e35` |
| `row-hover-border` | `#b8d6fb` | `#3d4954` |
| `row-selected-face` | `#dcebfc -> #c1dbfc` | `#34526e -> #2a4560` |
| `row-selected-border` | `#7da2ce` | `#4d86b8` |
| `row-separator` | `#e6ecf3` | `#2c3239` |
| `toolbar-face` / `toolbar-border` | `#fbfdff -> #e4edf8` / `#c3d0de` | `#343b43 -> #2a3037` / `#14181c` |
| `menu-background` / `menu-border` | `#ffffff` / `#7c8794` | `#2a3037` / `#07090b` |
| `menu-shadow` (Windows 7's: small, down and to the right; tooltips too) | `2px 2px 5px rgba(8,35,70,0.35)` | `2px 2px 5px rgba(0,0,0,0.7)` |
| `menu-gutter-line` / `menu-gutter-light` (the etched line right of a menu's icon margin, and its separators, which start after the margin) | `#e2e3e3` / `#ffffff` | `#1d2228` / `#363d45` |
| `tooltip-face` | `#ffffff -> #e4e5f0` | `#3a424b -> #2a3037` |
| `tooltip-border` / `tooltip-text` | `#767676` / `#575757` | `#07090b` / `#d5dbe1` |
| `badge-face` | `#5db4f0 -> #1f86d4` | same |
| `badge-border` / `badge-text` | `#134e86` / `#ffffff` | `#06121d` / `#ffffff` |
| `overlay` | `rgba(10,30,60,0.35)` | `rgba(0,0,0,0.55)` |
| `splitter-hover` | `rgba(60,155,230,0.75)` | same |
| `unread-mark` / `flag-mark` | `#1f86d4` / `#e08a00` | `#5fb0ee` / `#f0a030` |

### Check boxes and scrollbars

A check box is a box (`check-box-border`), a 1px light gap (`check-box-gap`) and a sunken square inside: a 1px edge (`check-box-ring`) around a face shaded from the top-left corner (dark) to the bottom-right (light). Pressed takes the hover border and gap. A scrollbar's thumb is the button's gloss turned on its side: its gradient runs from left to right, the horizon at 49% / 50%, with a 1px inner highlight (`scroll-thumb-inner`).

| Token | Aero | Slate |
| --- | --- | --- |
| `check-box-border` / `-hover` | `#8e8f8f` / `#5586a3` | `#0b0d10` / `#5aa3d8` |
| `check-box-gap` / `-hover` | `#f4f4f4` / `#def9fa` | `#3a4148` / `#3d5a72` |
| `check-box-ring` / `-hover` / `-active` | `rgba(0,0,0,0.08)` / `#89d1f9` / `#56a6d6` | `rgba(0,0,0,0.3)` / `#4f8fbf` / `#4d86b8` |
| `check-box-face` (top-left -> middle -> bottom-right) | `#cdcdcd #e8e8e8 #f5f5f5` | `#1b2025 #2a3037 #363c43` |
| `check-box-face-hover` | `#aecede #c4eafd #e9f5fb` | `#24435c #2f5878 #3b6a8c` |
| `check-box-face-active` | `#7ebce3 #96cbeb #9ed0ec` | `#173a55 #22506f #2a5d80` |
| `scroll-thumb-face` (left -> 49% -> 50% -> right) | `#f5f5f5 #e9e9eb #d9dadc #c0c0c4` | `#5a626b #474e56 #363c43 #2f343a` |
| `scroll-thumb-face-hover` | `#f5f5f5 #d6eefb #a9dbf6 #a9dbf6` | `#6b7885 #55626f #3f4c59 #384552` |
| `scroll-thumb-face-active` | `#b5e4f7 #b5e4f7 #6fcaf0 #6fcaf0` | `#3b6a8c #3b6a8c #2a5d80 #2a5d80` |
| `scroll-thumb-border` / `-hover` / `-active` | `#979797` / `#356f9b` / `#18598a` | `#0b0d10` / `#5aa3d8` / `#4d86b8` |
| `scroll-thumb-inner` | `rgba(255,255,255,0.6)` | `rgba(255,255,255,0.16)` |

### Status

| Token | Aero | Slate |
| --- | --- | --- |
| `info-background` / `-border` | `#e4f2fd` / `#7db6e6` | `#1d3345` / `#3f7fb0` |
| `success-background` / `-border` | `#e3f6e1` / `#6fbf6a` | `#1e3a23` / `#4a9a4f` |
| `warning-background` / `-border` | `#fff6d6` / `#d9b23c` | `#40361a` / `#b08f2c` |
| `danger-background` / `-border` | `#fde6e4` / `#d9716a` | `#45211f` / `#b3524b` |
| `danger-text` | `#a3231b` | `#ff9d95` |

### Icon materials (the same in both themes)

Each material is `light` -> `dark` gradient plus an `edge` outline: `icon-blue` (`#9ad6ff` `#1f7fd6` `#0f4f94`), `icon-green` (`#baf083` `#3fa52e` `#23701a`), `icon-gold` (`#ffee9a` `#f0a81c` `#a86a00`), `icon-red` (`#ffa695` `#d83a2a` `#8f1a10`), `icon-paper` (`#ffffff` `#d3e0ee` `#5f7590`), `icon-steel` (`#d5dde6` `#7d8b9e` `#3f4c5e`). Shared: `icon-shine` white 0.5, `icon-ink` `#ffffff`, `icon-ink-dark` `#2b2100`, `icon-gloss-top` white 0.9, `icon-gloss-bottom` white 0.08, `icon-shadow` black 0.35.

### Start orb (the same in both themes)

The round glass button that opens a start menu, after the Windows 7 orb: a dark glass sphere lit from below, a glossy shine on its upper half, the member's mark glowing in the middle. Drawn from these values, never from a picture of the original.

The mark can instead wear Windows 7's flag: split into four panes at its middle, each in one of the flag's colours with a gloss of its own (`orb-flag-*`, light at the pane's top to dark at its bottom: red top left, green top right, blue bottom left, yellow bottom right). Either way the panes can be parted by gaps as wide as the mark's own opening, as the flag's are. A member may show Windows 7's flag itself in place of its mark: a vector picture the member ships (never a bitmap, so it stays sharp), drawn as it is, with the same glow and the same light under the pointer.

| Token | Value |
| --- | --- |
| `orb-edge` | `#04101c` |
| `orb-body` (radial, from the bottom centre outwards) | `#2a8fd0` at 0% -> `#16609c` at 45% -> `#0a1d33` at 100% |
| `orb-rim` (inner ring) | `rgba(255,255,255,0.4)` |
| `orb-shine` | vertical gradient white 0.75 -> 0.05 over the upper half |
| `orb-hover-tint` / `orb-pressed-tint` | `rgba(120,215,255,0.28)` / `rgba(0,16,36,0.35)` |
| `orb-glow` (hover, around the orb) | `rgba(90,200,255,0.85)`, 10px |
| `orb-mark` | `#00e5d0` -> `#00a8f4` (top -> bottom; Hyprland's colours, for a Hyprland member) |
| `orb-flag-red` / `-green` | `#ff9a5a` -> `#e0381a` / `#b8ec5c` -> `#58a812` |
| `orb-flag-blue` / `-yellow` | `#6ccbff` -> `#1a7ce0` / `#ffe46a` -> `#f2a400` |
| `orb-mark-weight` (how much bolder than the member's own mark: its outline stroked in its own colours, in the units of its path) | 12 (Hyprland's mark is 312.92 tall; its opening narrows from 27.2 to 15.2, and the gaps with it) |
| `orb-mark-glow` | 0.65: a blurred copy of the mark in its own colours, under it (one colour of its own would ring the mark's blue bottom in teal, a blurred double) |

### Notification area glyphs (the same in both themes)

Windows 7's own icons in the notification area (volume, network, power, ...) are not glossy pictures but 16 x 16 pixel drawings: white shapes, grey shading where two shapes meet, a dark see-through edge around them, dark glass where something is empty; a small sign from the icon materials sits on the lower right corner (a red disc with a cross, a gold triangle, ...). They are drawn pixel by pixel, never smoothed. Measured on Windows 7 screenshots.

| Token | Value |
| --- | --- |
| `tray-glyph-ink` | `#ffffff` |
| `tray-glyph-shade` / `-shade-light` | `#808080` / `#c0c0c0` |
| `tray-glyph-edge` | `rgba(0,0,0,0.5)` |
| `tray-glyph-screen` | `rgba(0,0,0,0.3)` |

On a solid pane (the volume flyout's mute button) the same shapes are blue, without the edge:

| Token | Aero | Slate |
| --- | --- | --- |
| `pane-glyph` / `pane-glyph-shade` | `#0067d0` / `#003d8d` | `#5fb0ee` / `#2a73ad` |

### Flyouts over the notification area

The flyouts of the clock, the volume, the network, the power and the hidden icons are Windows 7's: a frame of window glass (from outside: `glass-border-outer`, `glass-border-inner`, 4px of `glass-tint`, `glass-border-inner`, `glass-border-outer`), a `surface` body, and their links centred in a band along the bottom (`surface-sunken`, its top fading from `toolbar-border` over 5px). Words on the body are `text`, links `text-link`, group headings `text-muted` with a line over them.

### Notification balloons

A notification is Windows 7's balloon, which Windows draws as a tooltip: the `tooltip-face` gradient edged in `tooltip-border`, the `menu-shadow`, `radius-panel` corners, and a stem (its pointed tail) on the edge nearest the corner it points at, standing against a "wall" (one side upright, flush with the point, the other slanting back). Its words are `font-size-small`, the title bold, both in `text`; a 16px icon sits before the title, and a picture sent with the notification 48px left of the title and the words; a small flat close button at the top right; the action buttons along the bottom, wrapping onto more rows. It fades in and out (`motion-soft`).

| Token | Value |
| --- | --- |
| `balloon-stem-width` / `balloon-stem-height` | 16 / 16 px |
| `balloon-stem-inset` (from the balloon's side to the stem's upright side) | 16px |

### Sliders

A slider (the volume) is Windows 7's trackbar: a narrow sunken channel, a pale ramp beside it widening towards the top, small tick marks, and an aqua thumb pointing at the ramp. Where several sliders stand side by side (the Volume Mixer), only the one with the keyboard has the aqua thumb; the others have a plain grey one.

| Token | Aero | Slate |
| --- | --- | --- |
| `trackbar-channel` / `-edge` / `-light` | `#e7eaea` / `#b0b0b0` / `#fdfdfd` | `#1b2025` / `#0b0d10` / `#363c43` |
| `trackbar-ramp` / `trackbar-tick` | `#d5dfe5` / `#cfcfcf` | `#2a3037` / `#4a525b` |
| `trackbar-thumb-border` | `#3c7fb1` | same |
| `trackbar-thumb-rim` (top -> bottom) | `#41f7fd` -> `#30dafb` | same |
| `trackbar-thumb-face` (top -> bottom) | `#e7f5fd` -> `#aedef8` | same |
| `trackbar-thumb-quiet-border` | `#b0b0b0` | `#0b0d10` |
| `trackbar-thumb-quiet-face` (top -> bottom) | `#f7f7f7` -> `#d5d5d5` | `#5a626b` -> `#363c43` |

### Group boxes

A group inside a window (the Volume Mixer's "Device" and "Applications") is Windows 7's: a rounded frame 2px wide in `group-border`, the group's name on the `surface` breaking the frame along its top left, the first letter of the name underlined when it is a keyboard accelerator. Dividers inside a group are the same 2px line.

| Token | Aero | Slate |
| --- | --- | --- |
| `group-border` | `#eaeff2` | `#2c3239` |

### Analog clock (the same in both themes)

The round clock of a time flyout, after Windows 7's: a dark blue glass disc with light tick marks and hands, a thin red second hand, a glossy shine on its upper half. Drawn from these values, like the orb.

| Token | Value |
| --- | --- |
| `clock-edge` | `#04101c` |
| `clock-face` (vertical) | `#2e6fae` at 0% -> `#0b2542` at 100% |
| `clock-rim` (inner ring) | `rgba(255,255,255,0.4)` |
| `clock-shine` | vertical gradient white 0.55 -> 0.05 over the upper half |
| `clock-tick` / `clock-hand` | `rgba(255,255,255,0.85)` / `#ffffff` |
| `clock-second-hand` | `#ff6a55` |

### Avatars

`avatar-1..6`: `#2f8fd8 #3fa56a #d9822b #c2507f #7a62c9 #2aa3a8`, chosen by a stable hash of the identity. All sit under one glass overlay: `avatar-shine` (white 0.45 -> 0.08 at 49% -> 0 at 50%), `avatar-glass` (`inset 0 0 0 1px rgba(255,255,255,0.4), inset 0 -4px 6px -2px rgba(0,0,0,0.28)`), `avatar-text` `#ffffff`.

## 5. Where the tokens live in a project

Exactly one place per project defines them (a stylesheet, a QML singleton, ...), named in that project's `AGENTS.md`. Primitives (button, field, glass window, dialog, icon, menu, ...) are built once on top of it and reused; a feature that needs a new look adds a token or a primitive, never a literal.
