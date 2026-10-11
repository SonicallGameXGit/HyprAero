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

## 2. What "Windows Aero" means concretely

- **Glass**: translucent, blurred, lightly tinted surfaces for chrome (title area, bars, toolbars, sidebars, popups). A thin bright inner border and a darker outer border give each glass panel an edge.
- **Content stays solid**: lists, text and anything long-read sit on opaque (or near-opaque) surfaces. Glass is for chrome, never under long text.
- **Gloss**: buttons and selected items have a soft vertical gradient with a lighter upper half; the colour steps at 49% / 50% of the height create the classic "horizon". Hover adds a glow, press darkens and flattens (inset shadow).
- **Depth**: soft drop shadows and glow separate layers; no hard flat blocks, no heavy black shadows.
- **Shape**: small radii (controls 3px, panels 6px, windows 8px), not pills and not sharp squares.
- **Colour**: cool blue-led palette with green / aqua accents; saturated but airy. Slate: charcoal / graphite glass with the same accents, less saturation.
- **Icons**: detailed, glossy, slightly dimensional, drawn from a few glossy materials (`icon-*` tokens). Not thin monochrome line icons, and no icon library with that look. Only small structural glyphs (chevron, close, check) are flat.
- **Pictures before words**: an action or a place is recognised by its icon first. A button keeps its text only when it is the main action of its group; every icon-only control has a tooltip and an accessible name.
- **Buttons say what they are**: accent (the one main action), normal, tool (flat until hovered, for toolbars), danger (red, for what destroys something).
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
| `menu-shadow` | `0 6px 18px rgba(8,35,70,0.35)` | `0 6px 18px rgba(0,0,0,0.7)` |
| `badge-face` | `#5db4f0 -> #1f86d4` | same |
| `badge-border` / `badge-text` | `#134e86` / `#ffffff` | `#06121d` / `#ffffff` |
| `overlay` | `rgba(10,30,60,0.35)` | `rgba(0,0,0,0.55)` |
| `splitter-hover` | `rgba(60,155,230,0.75)` | same |
| `unread-mark` / `flag-mark` | `#1f86d4` / `#e08a00` | `#5fb0ee` / `#f0a030` |

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

| Token | Value |
| --- | --- |
| `orb-edge` | `#04101c` |
| `orb-body` (radial, from the bottom centre outwards) | `#46c2ff` at 0% -> `#16609c` at 45% -> `#0a1d33` at 100% |
| `orb-rim` (inner ring) | `rgba(255,255,255,0.4)` |
| `orb-shine` | vertical gradient white 0.75 -> 0.05 over the upper half |
| `orb-hover-tint` / `orb-pressed-tint` | `rgba(120,215,255,0.28)` / `rgba(0,16,36,0.35)` |
| `orb-glow` (hover, around the orb) | `rgba(90,200,255,0.85)`, 10px |
| `orb-mark` | `#00e5d0` -> `#00a8f4` (top -> bottom; Hyprland's colours, for a Hyprland member) |
| `orb-mark-glow` | `rgba(0,229,208,0.65)` |

### Avatars

`avatar-1..6`: `#2f8fd8 #3fa56a #d9822b #c2507f #7a62c9 #2aa3a8`, chosen by a stable hash of the identity. All sit under one glass overlay: `avatar-shine` (white 0.45 -> 0.08 at 49% -> 0 at 50%), `avatar-glass` (`inset 0 0 0 1px rgba(255,255,255,0.4), inset 0 -4px 6px -2px rgba(0,0,0,0.28)`), `avatar-text` `#ffffff`.

## 5. Where the tokens live in a project

Exactly one place per project defines them (a stylesheet, a QML singleton, ...), named in that project's `AGENTS.md`. Primitives (button, field, glass window, dialog, icon, menu, ...) are built once on top of it and reused; a feature that needs a new look adds a token or a primitive, never a literal.
